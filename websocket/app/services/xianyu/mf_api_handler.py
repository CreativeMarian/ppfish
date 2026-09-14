"""
蜜蜂汇云（mf178）直充卡券处理器

用途：
    在 ppfish 自动发货流程中新增 mf_api 卡券类型，实现"闲鱼订单 → 蜜蜂放单 → 查单 → 结果通知买家"的
    完整直充闭环，替代原闲管家对蜜蜂汇云的对接。

流程：
    1. 发货触发（_auto_delivery 中 card_type == 'mf_api'）
    2. 需要手机号（require_account=True）→ 先向买家询问手机号（等待状态，不阻塞主流程）
    3. 买家回复手机号 → 调蜜蜂 upload_order 放单（third_id=闲鱼订单号）
    4. 返回"已提交"消息给买家，并在后台启动查单轮询任务
    5. 查单：放单 60s 后开始，间隔 60s，最多 max_poll 次；终态后把结果（成功/失败）发给买家

配置：
    卡券 type='mf_api'，api_config 为 JSON，示例：
    {
      "miniunit_id": "1001794",       // 蜜蜂商品编码（商品列表接口获取，必填）
      "goods_sku": "",                // 放单 SKU（部分业务必填，可空）
      "require_account": true,        // 是否需要买家提供手机号（会员直充类均为 true）
      "poll_delay": 60,               // 放单后首次查单等待秒数（默认 60，接口文档要求 ≥60s）
      "poll_interval": 60,            // 两次查单间隔秒数（默认 60）
      "max_poll": 8,                  // 最大查单次数（默认 8，约 8~10 分钟内出结果）
      "ask_message": "请发送需要充值的手机号...",   // 询问手机号文案（可选，有默认值）
      "datas": {"target": "{account}"}           // 数据包模板，{account} 会被替换为手机号
    }

密钥来源：
    优先读环境变量 MF_APP_KEY / MF_APP_SECRET / MF_BASE_URL（.env 已配置正式环境密钥）；
    环境变量缺失时回退解析项目根 .env 文件。
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import time
from pathlib import Path
from typing import Any, Dict, Optional

logger = logging.getLogger("mf_api_handler")

# 等待状态标记（与 yifan 约定一致）：表示已发询问、等待买家回复手机号
WAITING_ACCOUNT = "__WAITING_ACCOUNT__"

# 默认文案
DEFAULT_ASK_MESSAGE = (
    "请发送需要充值的手机号（11位数字），我会自动为您充值。"
    "请注意核对手机号，因手机号输错导致的充值错误无法退款。"
)
DEFAULT_SUBMITTED_MESSAGE = (
    "✅ 已提交充值\n"
    "📦 商品：{goods_name}\n"
    "📱 充值账号：{account}\n"
    "⏳ 正在处理中，预计几分钟内到账，到账后我会第一时间通知您。"
)
DEFAULT_SUCCESS_MESSAGE = (
    "🎉 充值成功！\n"
    "📦 商品：{goods_name}\n"
    "📱 充值账号：{account}\n"
    "请查收，感谢惠顾～"
)
DEFAULT_FAIL_MESSAGE = (
    "❌ 充值失败\n"
    "📦 商品：{goods_name}\n"
    "📱 充值账号：{account}\n"
    "💡 原因：{error}\n"
    "请联系客服处理退款。"
)
DEFAULT_UNKNOWN_MESSAGE = (
    "⚠️ 充值结果待核实\n"
    "📦 商品：{goods_name}\n"
    "📱 充值账号：{account}\n"
    "平台正在人工核实该订单，请稍候，有结果我会第一时间通知您。"
)


def _load_mf_credentials() -> Dict[str, str]:
    """读取蜜蜂正式环境密钥（环境变量优先，回退解析项目根 .env）"""
    key = os.getenv("MF_APP_KEY", "").strip()
    secret = os.getenv("MF_APP_SECRET", "").strip()
    base = os.getenv("MF_BASE_URL", "").strip()
    if key and secret:
        return {"app_key": key, "app_secret": secret, "base_url": base or None}

    # 回退：从项目根 .env 解析
    candidates = [
        Path.cwd() / ".env",
        Path(__file__).resolve().parents[3] / ".env",   # common/services -> ppfish/.env
        Path(__file__).resolve().parents[4] / ".env",
    ]
    for env_path in candidates:
        if not env_path.exists():
            continue
        try:
            text = env_path.read_text(encoding="utf-8-sig")
        except Exception:
            continue
        values = {}
        for line in text.splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            values[k.strip()] = v.strip()
        key = values.get("MF_APP_KEY", "")
        secret = values.get("MF_APP_SECRET", "")
        base = values.get("MF_BASE_URL", "")
        if key and secret:
            return {"app_key": key, "app_secret": secret, "base_url": base or None}
    return {}


def _load_recharge_base_url() -> str:
    """读取充值页公网地址（买家可访问的前端地址）

    配置：.env 的 MF_RECHARGE_BASE_URL，例如 https://your.domain.com。
    本地默认 127.0.0.1:9000（仅本机测试用，买家无法访问，部署/内网穿透后修改）。
    """
    url = os.getenv("MF_RECHARGE_BASE_URL", "").strip()
    if url:
        return url.rstrip("/")
    candidates = [
        Path.cwd() / ".env",
        Path(__file__).resolve().parents[3] / ".env",
        Path(__file__).resolve().parents[4] / ".env",
    ]
    for env_path in candidates:
        if not env_path.exists():
            continue
        try:
            text = env_path.read_text(encoding="utf-8-sig")
        except Exception:
            continue
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("MF_RECHARGE_BASE_URL="):
                v = line.partition("=")[2].strip().strip('"').strip("'")
                if v:
                    return v.rstrip("/")
    return "http://127.0.0.1:9000"


class MfApiHandler:
    """蜜蜂汇云直充发货处理器（挂载到 AutoDeliveryHandler）"""

    def __init__(self, parent):
        self.parent = parent
        self._client = None
        self._credentials = None

    # ==================== 属性代理 ====================

    @property
    def cookie_id(self):
        return self.parent.cookie_id

    @property
    def session(self):
        return self.parent.session

    @property
    def ws(self):
        return self.parent.ws

    @property
    def mf_account_waiting(self) -> Dict[str, dict]:
        return self.parent.mf_account_waiting

    @property
    def _safe_str(self):
        return self.parent._safe_str

    # ==================== 客户端 ====================

    def _get_client(self):
        """懒加载 MfClient（正式环境）"""
        if self._client is not None:
            return self._client
        creds = self._credentials or _load_mf_credentials()
        if not creds.get("app_key") or not creds.get("app_secret"):
            logger.error("蜜蜂汇云密钥未配置（MF_APP_KEY/MF_APP_SECRET），请在 .env 中配置")
            return None
        self._credentials = creds
        from common.services.mf_client import MfClient
        self._client = MfClient(
            app_key=creds["app_key"],
            app_secret=creds["app_secret"],
            base_url=creds.get("base_url") or None,
        )
        return self._client

    # ==================== 主入口 ====================

    async def get_mf_api_card_content(
        self,
        rule: dict,
        order_id: str = None,
        item_id: str = None,
        buyer_id: str = None,
        chat_id: str = None,
        send_user_name: str = None,
    ) -> Optional[str]:
        """蜜蜂直充发货主入口

        两种模式（由卡券 api_config.recharge_page 决定）：
        - recharge_page=true（默认）：发送充值链接给买家，买家在网页输入手机号提交；
          同时设置等待状态，买家直接回复手机号也能触发（兜底）。返回 None 中断当前流程。
        - recharge_page=false：下单后自动询问手机号（原「消息询问」模式）。

        Returns:
            - 提交成功文案：直接作为发货内容返回
            - WAITING_ACCOUNT：已询问手机号/已发链接，等待买家操作（返回 None 以中断当前流程）
            - None：失败（错误信息已通过通知发送）
        """
        try:
            api_config = rule.get("api_config") or rule.get("card_api_config")
            if not api_config:
                logger.error(f"蜜蜂卡券API配置为空: card={rule.get('card_id')}")
                return None
            if isinstance(api_config, str):
                api_config = json.loads(api_config)

            miniunit_id = api_config.get("miniunit_id")
            if not miniunit_id:
                logger.error(f"蜜蜂卡券缺少 miniunit_id: card={rule.get('card_id')}")
                return None

            recharge_page = bool(api_config.get("recharge_page", True))

            # 网页充值模式：发充值链接（买家点链接输手机号充值），消息回复手机号作兜底
            if recharge_page:
                return await self._send_recharge_link(
                    rule, order_id, item_id, buyer_id, chat_id
                )

            # 原「消息询问」模式
            require_account = bool(api_config.get("require_account", True))
            account = self._get_existing_account(order_id, item_id)
            if require_account and not account:
                logger.info(
                    f"【{self.cookie_id}】蜜蜂直充需要手机号，开始询问: order_id={order_id}, chat_id={chat_id}"
                )
                await self.ask_for_recharge_account(
                    chat_id, buyer_id, rule, order_id, item_id
                )
                return None

            if require_account and account:
                logger.info(
                    f"【{self.cookie_id}】使用订单已有手机号发货: order_id={order_id}, account={account}"
                )

            return await self.call_mf_api_with_account(
                rule, account or "", order_id, item_id, buyer_id, chat_id, send_user_name
            )
        except Exception as e:
            logger.error(f"【{self.cookie_id}】蜜蜂直充发货异常: {self._safe_str(e)}")
            return None

    # ==================== 网页充值模式 ====================

    def build_recharge_url(self, order_no: str) -> str:
        """构建买家充值页链接（含订单号 + 订单主键双重校验参数）"""
        base = _load_recharge_base_url()
        order_pk = ""
        try:
            from common.db.compat import db_manager
            order = db_manager.get_order_by_id(order_no)
            if order and order.get("id"):
                order_pk = str(order.get("id"))
        except Exception as e:
            logger.warning(f"构建充值链接时读取订单主键失败: {self._safe_str(e)}")
        url = f"{base}/recharge?orderNo={order_no}"
        if order_pk:
            url += f"&orderId={order_pk}"
        return url

    async def _send_recharge_link(
        self, rule: dict, order_id: str = None, item_id: str = None,
        buyer_id: str = None, chat_id: str = None,
    ) -> None:
        """发充值链接给买家，并设置兜底等待状态（买家回复手机号也可放单）"""
        try:
            api_config = rule.get("api_config") or rule.get("card_api_config")
            if isinstance(api_config, str):
                try:
                    api_config = json.loads(api_config)
                except Exception:
                    api_config = {}
            if not isinstance(api_config, dict):
                api_config = {}

            url = self.build_recharge_url(order_id) if order_id else ""
            link_message = api_config.get("link_message") or (
                "请点击下方链接，输入手机号完成充值：\n{url}\n"
                "（如无法打开链接，也可以直接回复手机号，我帮您充值）"
            )
            try:
                msg = link_message.format(url=url)
            except Exception:
                msg = link_message

            if chat_id and buyer_id:
                await self.parent.send_msg(self.ws, chat_id, buyer_id, msg)
            logger.info(
                f"【{self.cookie_id}】已发送蜜蜂充值链接: chat_id={chat_id}, order_id={order_id}, url={url}"
            )

            # 设置兜底等待状态：买家直接回复手机号时，由消息处理器触发放单
            if chat_id:
                self.mf_account_waiting[chat_id] = {
                    "buyer_id": buyer_id,
                    "rule": rule,
                    "order_id": order_id,
                    "item_id": item_id,
                    "create_time": time.time(),
                }
        except Exception as e:
            logger.error(f"【{self.cookie_id}】发送充值链接异常: {self._safe_str(e)}")
        return None

    async def handle_recharge_submit(self, order_no: str, phone: str) -> dict:
        """网页充值提交：买家在充值页输入充值账号后调用（websocket 内部接口入口）

        充值账号 = 手机号（11位）或 QQ号/平台账号（5-12位数字），
        由蜜蜂平台按商品校验号码格式（如 QQ会员类商品需要 QQ号）。
        流程：校验订单 → 校验账号 → 匹配 mf_api 卡券 → 幂等检查 → 蜜蜂放单 → 后台查单通知
        Returns:
            {"success": bool, "message": str, "data": {...}}
        """
        order_no = (order_no or "").strip()
        digits = "".join(ch for ch in str(phone or "") if ch.isdigit())
        # 手机号 11 位；QQ号/平台账号 5~12 位数字
        is_phone = len(digits) == 11 and digits.startswith("1")
        is_account = 5 <= len(digits) <= 12
        if not (is_phone or is_account):
            return {"success": False, "message": "请输入正确的充值账号（11位手机号或QQ号）", "data": None}

        from common.db.compat import db_manager
        order = db_manager.get_order_by_id(order_no)
        if not order:
            return {"success": False, "message": "订单不存在", "data": None}

        item_id = order.get("item_id")
        if not item_id:
            return {"success": False, "message": "订单缺少商品信息，请联系卖家", "data": None}

        # 匹配该订单规格对应的 mf_api 卡券
        cards = db_manager.get_cards_by_item_id(
            item_id, order.get("spec_name"), order.get("spec_value")
        )
        rule = None
        for c in cards:
            if c.get("type") == "mf_api":
                rule = c
                break
        if not rule:
            return {"success": False, "message": "该订单不是蜜蜂直充商品，请联系卖家", "data": None}

        # 幂等：已有蜜蜂订单记录时按状态返回（已提交/已成功/已失败）
        meta = order.get("metadata") or {}
        if isinstance(meta, str):
            try:
                meta = json.loads(meta)
            except Exception:
                meta = {}
        mf = meta.get("mf") or {} if isinstance(meta, dict) else {}
        if not isinstance(mf, dict):
            mf = {}
        cur_status = mf.get("status") or ""
        if cur_status in ("processing", "pending"):
            return {
                "success": True, "message": "充值已提交，正在处理中，请耐心等待到账通知",
                "data": {"status": cur_status, "platform_order_no": mf.get("order_no") or ""},
            }
        if cur_status == "success":
            return {"success": True, "message": "该订单已充值成功，请勿重复提交", "data": {"status": "success"}}
        if cur_status in ("failed", "failed_refunded", "unknown"):
            # 失败/未知可重试：允许重新放单
            pass

        buyer_id = order.get("buyer_id") or ""
        chat_id = order.get("chat_id") or ""

        result = await self.call_mf_api_with_account(
            rule, digits, order_no, item_id, buyer_id, chat_id
        )
        if result is None:
            # call_mf_api_with_account 已发送错误通知；这里从订单 metadata 取最终状态兜底
            meta_now = {}
            try:
                order_now = db_manager.get_order_by_id(order_no)
                meta_now = (order_now or {}).get("metadata") or {}
                if isinstance(meta_now, str):
                    meta_now = json.loads(meta_now)
            except Exception:
                pass
            mf_now = (meta_now or {}).get("mf") or {} if isinstance(meta_now, dict) else {}
            return {
                "success": False,
                "message": "充值提交失败，请稍后重试或联系卖家",
                "data": {"status": (mf_now or {}).get("status") or "failed"},
            }

        return {
            "success": True,
            "message": "充值已提交，正在处理中，到账后我会通过闲鱼消息通知您",
            "data": {"status": "processing"},
        }

    def _get_existing_account(self, order_id: str = None, item_id: str = None) -> Optional[str]:
        """从订单记录中读取已有手机号（receiver_phone 或 metadata）"""
        if not order_id:
            return None
        try:
            from common.db.compat import db_manager
            order = db_manager.get_order_by_id(order_id)
            if not order:
                return None
            phone = (order.get("receiver_phone") or "").strip()
            if phone and phone.isdigit() and len(phone) >= 7:
                return phone
            meta = order.get("metadata") or {}
            if isinstance(meta, str):
                try:
                    meta = json.loads(meta)
                except Exception:
                    meta = {}
            mf = meta.get("mf") or {}
            phone = (mf.get("account") or "").strip()
            if phone and phone.isdigit() and len(phone) >= 7:
                return phone
        except Exception as e:
            logger.warning(f"读取订单已有手机号失败: {self._safe_str(e)}")
        return None

    # ==================== 询问手机号 ====================

    async def ask_for_recharge_account(
        self, chat_id: str, buyer_id: str, rule: dict, order_id: str = None, item_id: str = None
    ) -> str:
        """询问买家手机号并设置等待状态（不阻塞主流程）

        Returns:
            WAITING_ACCOUNT
        """
        try:
            api_config = rule.get("api_config") or rule.get("card_api_config")
            ask_message = DEFAULT_ASK_MESSAGE
            if api_config:
                if isinstance(api_config, str):
                    try:
                        api_config = json.loads(api_config)
                    except Exception:
                        api_config = {}
                ask_message = api_config.get("ask_message") or DEFAULT_ASK_MESSAGE

            # 记录等待状态：后续买家在本会话的回复文本将作为手机号
            self.mf_account_waiting[chat_id] = {
                "buyer_id": buyer_id,
                "rule": rule,
                "order_id": order_id,
                "item_id": item_id,
                "create_time": time.time(),
            }
            await self.parent.send_msg(self.ws, chat_id, buyer_id, ask_message)
            logger.info(
                f"【{self.cookie_id}】已向买家询问充值手机号: chat_id={chat_id}, order_id={order_id}"
            )
            return WAITING_ACCOUNT
        except Exception as e:
            logger.error(f"【{self.cookie_id}】询问充值手机号异常: {self._safe_str(e)}")
            return None

    # ==================== 放单 ====================

    async def call_mf_api_with_account(
        self,
        rule: dict,
        account: str,
        order_id: str = None,
        item_id: str = None,
        buyer_id: str = None,
        chat_id: str = None,
        send_user_name: str = None,
    ) -> Optional[str]:
        """使用买家手机号调蜜蜂放单，并启动查单轮询

        Returns:
            提交成功文案（作为发货内容返回），失败返回 None
        """
        client = self._get_client()
        if client is None:
            return None

        api_config = rule.get("api_config") or rule.get("card_api_config")
        if isinstance(api_config, str):
            try:
                api_config = json.loads(api_config)
            except Exception:
                api_config = {}
        if not isinstance(api_config, dict):
            api_config = {}

        miniunit_id = api_config.get("miniunit_id")
        goods_sku = (api_config.get("goods_sku") or "").strip() or None
        goods_name = (rule.get("card_name") or rule.get("goods_name") or "直充商品").strip()

        # 数据包模板：{"target": "{account}"} → {"target": "138xxxx"}
        datas_template = api_config.get("datas") or {"target": "{account}"}
        if isinstance(datas_template, str):
            try:
                datas_template = json.loads(datas_template)
            except Exception:
                datas_template = {"target": "{account}"}
        datas = {}
        if isinstance(datas_template, dict):
            for k, v in datas_template.items():
                datas[k] = str(v).replace("{account}", account) if isinstance(v, str) else v
        else:
            datas = {"target": account}

        if not order_id:
            logger.error("蜜蜂放单缺少闲鱼订单号（third_id）")
            return None

        logger.info(
            f"【{self.cookie_id}】蜜蜂放单: third_id={order_id}, miniunit_id={miniunit_id}, "
            f"goods_sku={goods_sku}, account={account}"
        )

        try:
            resp = await client.upload_order(
                third_id=order_id,
                miniunit_id=miniunit_id,
                datas=datas,
                goods_sku=goods_sku,
            )
        except Exception as e:
            logger.error(f"【{self.cookie_id}】蜜蜂放单网络异常: {self._safe_str(e)}")
            if chat_id and buyer_id:
                await self.parent.send_notification(
                    "系统", buyer_id,
                    "❌ 自动发货失败：连接蜜蜂平台超时，请稍后重试或联系客服",
                    item_id or "unknown", chat_id,
                )
            return None

        code = resp.get("code")
        message = resp.get("message", "")
        data = resp.get("data") or {}

        from common.services.mf_client import ERR_OK, ERR_ORDER_EXISTS

        if code == ERR_OK or code == ERR_ORDER_EXISTS:
            platform_order_no = str(data.get("order_id") or "")
            logger.info(
                f"【{self.cookie_id}】蜜蜂放单成功: third_id={order_id}, "
                f"platform_order_no={platform_order_no}, state={data.get('state')}"
            )
            # 记录蜜蜂订单号到订单 metadata（不依赖额外表字段）
            try:
                from common.db.compat import db_manager
                db_manager.update_order_mf_status(
                    order_id=order_id,
                    mf_order_no=platform_order_no,
                    mf_status="processing",
                    mf_account=account,
                )
            except Exception as e:
                logger.warning(f"记录蜜蜂订单信息失败: {self._safe_str(e)}")

            # 组装"已提交"消息
            submitted_template = api_config.get("submitted_message") or DEFAULT_SUBMITTED_MESSAGE
            try:
                submitted_msg = submitted_template.format(
                    goods_name=goods_name, account=account,
                    platform_order_no=platform_order_no,
                )
            except Exception:
                submitted_msg = submitted_template

            # 启动后台查单轮询
            poll_delay = int(api_config.get("poll_delay", 60) or 60)
            poll_interval = int(api_config.get("poll_interval", 60) or 60)
            max_poll = int(api_config.get("max_poll", 8) or 8)
            try:
                asyncio.get_running_loop().create_task(
                    self.poll_and_notify(
                        rule=rule,
                        account=account,
                        order_id=order_id,
                        item_id=item_id,
                        buyer_id=buyer_id,
                        chat_id=chat_id,
                        platform_order_no=platform_order_no,
                        poll_delay=poll_delay,
                        poll_interval=poll_interval,
                        max_poll=max_poll,
                    )
                )
                logger.info(
                    f"【{self.cookie_id}】已启动蜜蜂查单任务: order_id={order_id}, "
                    f"platform_order_no={platform_order_no}, poll_delay={poll_delay}s"
                )
            except Exception as e:
                logger.error(f"启动蜜蜂查单任务失败: {self._safe_str(e)}")

            return submitted_msg
        else:
            # 放单失败
            err_text = self._friendly_error(code, message)
            logger.error(
                f"【{self.cookie_id}】蜜蜂放单失败: code={code}, message={message}, third_id={order_id}"
            )
            if chat_id and buyer_id:
                await self.parent.send_notification(
                    "系统", buyer_id,
                    f"❌ 自动发货失败：{err_text}\n请联系客服处理退款",
                    item_id or "unknown", chat_id,
                )
            return None

    # ==================== 查单轮询 ====================

    async def poll_and_notify(
        self,
        rule: dict,
        account: str,
        order_id: str,
        item_id: str,
        buyer_id: str,
        chat_id: str,
        platform_order_no: str,
        poll_delay: int = 60,
        poll_interval: int = 60,
        max_poll: int = 8,
    ) -> None:
        """放单成功后后台查单：到终态后把结果发给买家（成功/失败/待核实）"""
        try:
            # 放单后先等 poll_delay 再开始查（接口文档：放单 1 分钟后查询，间隔 ≥60s）
            await asyncio.sleep(poll_delay)

            client = self._get_client()
            if client is None:
                return
            api_config = rule.get("api_config") or rule.get("card_api_config")
            if isinstance(api_config, str):
                try:
                    api_config = json.loads(api_config)
                except Exception:
                    api_config = {}
            if not isinstance(api_config, dict):
                api_config = {}
            goods_name = (rule.get("card_name") or rule.get("goods_name") or "直充商品").strip()

            from common.services.mf_client import (
                ORDER_STATE_SUCCESS,
                ORDER_STATE_FAILED,
                ORDER_STATE_FAILED_REFUNDED,
                ORDER_STATE_UNKNOWN,
            )

            final_state = None
            final_error = ""

            for i in range(1, max_poll + 1):
                try:
                    resp = await client.order_info(order_id=platform_order_no)
                except Exception as e:
                    logger.warning(
                        f"【{self.cookie_id}】蜜蜂查单网络异常（第{i}次）: {self._safe_str(e)}"
                    )
                    await asyncio.sleep(poll_interval)
                    continue

                code = resp.get("code")
                if code != 0:
                    # 10015 订单不存在：可能尚未落库，继续轮询
                    logger.warning(
                        f"【{self.cookie_id}】蜜蜂查单返回非0: code={code}, message={resp.get('message')}"
                    )
                    if code == 10015 and i < max_poll:
                        await asyncio.sleep(poll_interval)
                        continue
                    final_state = ORDER_STATE_FAILED
                    final_error = f"平台查单失败({code}:{resp.get('message')})"
                    break

                data = resp.get("data") or {}
                state = data.get("state")
                error_code = data.get("error_code")
                logger.info(
                    f"【{self.cookie_id}】蜜蜂查单第{i}次: order_id={order_id}, "
                    f"state={state}, platform_order_no={platform_order_no}"
                )

                if state == ORDER_STATE_SUCCESS:
                    final_state = state
                    break
                if state in (ORDER_STATE_FAILED, ORDER_STATE_FAILED_REFUNDED):
                    final_state = state
                    final_error = self._state_error_text(error_code, data.get("remark") or "")
                    break
                if state == ORDER_STATE_UNKNOWN:
                    final_state = state
                    break
                # 1/2/11/12 等处理中状态，继续轮询
                if i < max_poll:
                    await asyncio.sleep(poll_interval)

            # 更新订单记录
            status_text = {
                ORDER_STATE_SUCCESS: "success",
                ORDER_STATE_FAILED: "failed",
                ORDER_STATE_FAILED_REFUNDED: "failed_refunded",
                ORDER_STATE_UNKNOWN: "unknown",
            }.get(final_state, "pending")
            try:
                from common.db.compat import db_manager
                db_manager.update_order_mf_status(
                    order_id=order_id,
                    mf_status=status_text,
                    mf_error=final_error or None,
                )
            except Exception as e:
                logger.warning(f"更新蜜蜂订单状态失败: {self._safe_str(e)}")

            if not chat_id or not buyer_id:
                logger.warning(f"【{self.cookie_id}】蜜蜂查单完成但缺少 chat_id/buyer_id，无法通知买家")
                return

            # 组装并发送结果消息
            if final_state == ORDER_STATE_SUCCESS:
                # 提取兑换链接/卡密（餐饮代下单等返券业务：ys_cards[0].card_pwd 或 voucher）
                voucher = ""
                try:
                    ys_cards = data.get("ys_cards") or []
                    if isinstance(ys_cards, list) and ys_cards:
                        voucher = (ys_cards[0].get("card_pwd") or "").strip()
                    if not voucher:
                        voucher = (data.get("voucher") or "").strip()
                except Exception:
                    voucher = ""
                success_template = api_config.get("success_message") or DEFAULT_SUCCESS_MESSAGE
                try:
                    msg = success_template.format(goods_name=goods_name, account=account, voucher=voucher)
                except Exception:
                    try:
                        msg = success_template.format(goods_name=goods_name, account=account)
                    except Exception:
                        msg = success_template
                # 有兑换链接且模板未含 {voucher} 时，兜底追加链接，确保买家一定能收到
                if voucher and "{voucher}" not in (success_template or ""):
                    msg += f"\n🔗 兑换链接（7天内有效）：\n{voucher}\n请点击链接选择门店兑换取餐～"
                await self.parent.send_msg(self.ws, chat_id, buyer_id, msg)
                logger.info(f"【{self.cookie_id}】蜜蜂充值成功已通知买家: order_id={order_id}, voucher={'有' if voucher else '无'}")
                # 同步本地订单发货内容（记录兑换链接，供后台/补发查看）
                if voucher:
                    try:
                        from common.services.order_service import OrderService
                        from common.db.session import async_session_maker
                        async with async_session_maker() as db_session:
                            await OrderService(db_session).update_order_delivery_info(
                                order_no=order_id,
                                status="shipped",
                                delivery_method="auto",
                                delivery_content=f"兑换链接：{voucher}",
                            )
                    except Exception as e:
                        logger.warning(f"【{self.cookie_id}】蜜蜂成功后更新订单发货内容失败: {self._safe_str(e)}")
            elif final_state == ORDER_STATE_UNKNOWN:
                unknown_template = api_config.get("unknown_message") or DEFAULT_UNKNOWN_MESSAGE
                try:
                    msg = unknown_template.format(goods_name=goods_name, account=account)
                except Exception:
                    msg = unknown_template
                await self.parent.send_msg(self.ws, chat_id, buyer_id, msg)
            else:
                fail_template = api_config.get("fail_message") or DEFAULT_FAIL_MESSAGE
                try:
                    msg = fail_template.format(
                        goods_name=goods_name, account=account, error=final_error or "未知原因"
                    )
                except Exception:
                    msg = fail_template
                await self.parent.send_msg(self.ws, chat_id, buyer_id, msg)
                logger.warning(f"【{self.cookie_id}】蜜蜂充值失败已通知买家: order_id={order_id}, error={final_error}")

        except asyncio.CancelledError:
            logger.info(f"【{self.cookie_id}】蜜蜂查单任务被取消: order_id={order_id}")
            raise
        except Exception as e:
            logger.error(f"【{self.cookie_id}】蜜蜂查单任务异常: {self._safe_str(e)}")

    # ==================== 错误文案 ====================

    def _friendly_error(self, code: Any, message: str) -> str:
        """放单错误码转可读文案"""
        err_map = {
            10001: "参数错误",
            10002: "签名错误",
            10003: "时间戳超期",
            10004: "商户不存在",
            10005: "商户被禁用",
            10006: "请求IP受限",
            10011: "账户余额不足，请先充值",
            10012: "该商品渠道不可用或未开通",
            10013: "充值通道故障，请稍后再试",
            10014: "手机号格式错误或无法充值",
            10016: "请求太频繁，请稍后再试",
        }
        text = err_map.get(int(code), str(message or "未知错误"))
        return text

    def _state_error_text(self, error_code: Any, remark: str) -> str:
        """查单失败 error_code 转可读文案"""
        err_map = {
            1: "手机号错误或空号",
            2: "卡密错误",
            3: "未充值成功",
            4: "其他原因",
        }
        base = err_map.get(int(error_code), "")
        if base and remark:
            return f"{base}（{remark}）"
        if base:
            return base
        return remark or "未知原因"
