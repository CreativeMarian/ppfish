"""
蜜蜂直充 - 充值页服务（backend-web 公开层）

功能：
1. 校验充值页订单：按订单主键(orderId) + 订单号(orderNo) 双重校验
   （不存在 / 不匹配 均返回明确中文提示）
2. 买家输入手机号提交：Redis 锁串行 + 幂等 → 调 websocket 内部接口触发蜜蜂放单
3. 状态查询：读取订单 metadata.mf 的放单/充值状态，供充值页轮询展示

说明：
- 本层为无认证公开接口的业务实现，仅读取展示所需的最小订单信息，不下发敏感字段。
- 实际的蜜蜂放单/查单/闲鱼消息通知在 websocket 服务完成（需在线账号实例）。
- 跨进程并发（买家重复点击、与消息回复兜底放单争抢）由 Redis 发货锁 + 蜜蜂按
  third_id（=闲鱼订单号）去重（错误码 10010）共同保证。
"""
from __future__ import annotations

import json
import re
from typing import Any, Dict, Optional, Tuple

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.services.websocket_client import websocket_client
from common.db.redis_client import release_delivery_lock, try_acquire_delivery_lock
from common.models.xy_order import XYOrder
from common.services.order_service import OrderService
from common.utils.xianyu_utils import canonical_goofish_item_url

# 充值账号：手机号 11 位（1 开头）或 QQ号/平台账号 5~12 位数字
PHONE_RE = re.compile(r"^1\d{10}$")
ACCOUNT_RE = re.compile(r"^\d{5,12}$")


class RechargeService:
    """蜜蜂直充充值页服务"""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def _load_and_validate(
        self, order_no: str, order_id: str
    ) -> Tuple[bool, str, Optional[XYOrder]]:
        """按订单主键查订单并校验订单号匹配。返回 (ok, message, order)。"""
        order_no = (order_no or "").strip()
        try:
            order_pk = int(str(order_id).strip())
        except (TypeError, ValueError):
            order_pk = 0
        if not order_no or order_pk <= 0:
            return False, "链接无效，缺少订单参数", None
        result = await self.session.execute(select(XYOrder).where(XYOrder.id == order_pk))
        order = result.scalars().first()
        if not order:
            return False, "订单不存在", None
        if (order.order_no or "").strip() != order_no:
            return False, "订单号与订单id不匹配", None
        return True, "", order

    @staticmethod
    def _mf_from_order(order: XYOrder) -> Dict[str, Any]:
        """读取订单 metadata.mf（蜜蜂直充状态）"""
        meta = order.metadata_json or {}
        if isinstance(meta, str):
            try:
                meta = json.loads(meta)
            except Exception:
                meta = {}
        mf = meta.get("mf") or {} if isinstance(meta, dict) else {}
        return mf if isinstance(mf, dict) else {}

    @staticmethod
    def _mask_phone(phone: str) -> str:
        """账号脱敏：手机号 138****8000；QQ号/平台账号保留首尾
        （长度>=6 时中间打码，否则原样返回）
        """
        phone = (phone or "").strip()
        n = len(phone)
        if n == 11 and phone.startswith("1"):
            return f"{phone[:3]}****{phone[-4:]}"
        if 6 <= n <= 12:
            head = phone[:2]
            tail = phone[-2:]
            return f"{head}****{tail}"
        return phone

    @staticmethod
    def _order_view(order: XYOrder, item_title: str = "") -> Dict[str, Any]:
        """充值页可展示的订单信息（最小必要字段）"""
        mf = RechargeService._mf_from_order(order)
        status = mf.get("status") or ""
        return {
            "order_no": order.order_no,
            "amount": str(order.amount) if order.amount is not None else None,
            "quantity": order.quantity,
            "spec_name": order.spec_name,
            "spec_value": order.spec_value,
            "item_id": order.item_id,
            "item_title": item_title or None,
            "item_url": canonical_goofish_item_url(order.item_id) if order.item_id else None,
            # 充值状态："" 未提交 / pending processing 充值中 / success 成功 / failed 失败 / unknown 待核实
            "mf_status": status,
            # 已提交时回显脱敏手机号，未提交时为空
            "mf_account_masked": RechargeService._mask_phone(mf.get("account") or "") if status else "",
        }

    async def query_order(
        self, order_no: str, order_id: str
    ) -> Tuple[bool, str, Optional[dict]]:
        """充值页加载：校验订单并返回展示信息 + 当前充值状态。"""
        ok, message, order = await self._load_and_validate(order_no, order_id)
        if not ok:
            return False, message, None
        item_title = await OrderService(self.session).resolve_item_title(
            order.owner_id, order.item_id or ""
        )
        return True, "查询成功", self._order_view(order, item_title)

    async def submit(
        self, order_no: str, order_id: str, phone: str
    ) -> Tuple[bool, str, Optional[dict]]:
        """买家输入手机号提交充值：Redis 锁 + 幂等 → 调 websocket 触发蜜蜂放单。"""
        ok, message, order = await self._load_and_validate(order_no, order_id)
        if not ok:
            return False, message, None

        phone = (phone or "").strip()
        # 手机号 11 位，或 QQ号/平台账号 5~12 位（QQ会员等商品直充到QQ号）
        if not (PHONE_RE.match(phone) or ACCOUNT_RE.match(phone)):
            return False, "请输入正确的充值账号（11位手机号或QQ号）", None

        real_order_no = order.order_no

        # 幂等快速路径：已充值成功直接提示
        mf = self._mf_from_order(order)
        if mf.get("status") == "success":
            return True, "该订单已充值成功，请勿重复提交", {
                "order_no": real_order_no,
                "status": "success",
            }

        # Redis 发货锁：与重复点击、消息回复兜底放单互斥
        lock_result = await try_acquire_delivery_lock(
            real_order_no, expire=120, holder_info="recharge", wait_timeout=5
        )
        if lock_result.is_locked_by_other:
            return False, "订单正在处理中，请稍后再试", None
        if lock_result.has_error:
            return False, "系统繁忙，请稍后再试", None
        if not lock_result.success:
            return False, "订单正在处理中，请稍后再试", None

        try:
            resp = await websocket_client.recharge_submit(real_order_no, phone)
            if not isinstance(resp, dict):
                return False, "充值提交失败，请稍后重试或联系卖家", None
            success = bool(resp.get("success"))
            msg = resp.get("message") or ("充值已提交" if success else "充值提交失败，请稍后重试或联系卖家")
            return success, msg, resp.get("data")
        finally:
            await release_delivery_lock(lock_result)

    async def status(
        self, order_no: str, order_id: str
    ) -> Tuple[bool, str, Optional[dict]]:
        """充值页状态轮询：返回当前充值状态与脱敏手机号。"""
        ok, message, order = await self._load_and_validate(order_no, order_id)
        if not ok:
            return False, message, None
        mf = self._mf_from_order(order)
        return True, "查询成功", {
            "order_no": order.order_no,
            "status": mf.get("status") or "",
            "platform_order_no": mf.get("order_no") or "",
            "mf_error": mf.get("error") or "",
            "mf_account_masked": self._mask_phone(mf.get("account") or "") if mf.get("status") else "",
        }
