"""
蜜蜂汇云商户 API 客户端（公共版）

功能:
1. 接口签名（MD5，参数按 key 正序排序，排除 sign/datas，末尾追加 app_secret）
2. 放单 upload_order（推送充值订单给蜜蜂平台）
3. 查单 order_info（订单结果查询，回调不可用时兜底）
4. 余额查询 account
5. 退款请求 order_refund

说明:
    供 backend-web（回调/配置）、websocket（自动发货放单）共用。
    接口文档：蜜蜂汇云商户采购 API（Apifox: 5a8eeb28-57a5-4054-aee4-583a4804fe98）
    沙箱测试环境：http://test.merchant.center.mf178.cn
    正式环境：https://merchant.task.mf178.cn
"""
from __future__ import annotations

import hashlib
import time
from typing import Any, Dict, Optional

import httpx
from loguru import logger

# 环境地址
MF_TEST_BASE_URL = "http://test.merchant.center.mf178.cn"
MF_PROD_BASE_URL = "https://merchant.task.mf178.cn"

# 订单状态
ORDER_STATE_WAITING = 1          # 待处理
ORDER_STATE_VERIFY_WAIT = 11     # 待账号验证
ORDER_STATE_VERIFYING = 12       # 账号验证中
ORDER_STATE_PROCESSING = 2       # 处理中
ORDER_STATE_SUCCESS = 3          # 充值成功
ORDER_STATE_FAILED = 4           # 充值失败
ORDER_STATE_UNKNOWN = 41         # 充值结果未知（需人工核实）
ORDER_STATE_FAILED_REFUNDED = 6  # 失败已退款

# 放单返回错误码
ERR_OK = 0
ERR_PARAM = 10001            # 参数错误
ERR_SIGN = 10002             # 签名错误
ERR_TIMESTAMP = 10003        # 时间戳超期
ERR_MERCHANT_NOT_FOUND = 10004  # 商户不存在
ERR_MERCHANT_DISABLED = 10005   # 商户被禁用
ERR_IP_FORBIDDEN = 10006     # 商户请求IP错误
ERR_ORDER_EXISTS = 10010     # 第三方订单号已存在（重复放单，查单取结果即可）
ERR_BALANCE_NOT_ENOUGH = 10011  # 账户余额不足
ERR_CHANNEL_UNAVAILABLE = 10012 # 渠道不可用或无资源/业务配置异常
ERR_RECHARGE_FAILED = 10013  # 充值故障，请稍后再试
ERR_TARGET_INVALID = 10014   # 充值号码有问题（格式错误、空号或已拉黑）
ERR_ORDER_NOT_FOUND = 10015  # 订单不存在
ERR_TOO_FREQUENT = 10016     # 请求太频繁，请稍后重试


class MfClient:
    """蜜蜂汇云商户 API 客户端"""

    def __init__(
        self,
        app_key: str,
        app_secret: str,
        base_url: Optional[str] = None,
        timeout: float = 20.0,
        debug: bool = False,
    ) -> None:
        """
        Args:
            app_key: 商户 AppKey（开放平台-API配置获取）
            app_secret: 商户 AppSecret
            base_url: 接口域名，默认正式环境；测试请传 MF_TEST_BASE_URL
            timeout: 请求超时（秒）
            debug: 是否携带测试调试 header（仅沙箱环境需要）
        """
        self.app_key = str(app_key)
        self.app_secret = str(app_secret)
        self.base_url = (base_url or MF_PROD_BASE_URL).rstrip("/")
        self.timeout = timeout
        self.debug = debug

    # ---------- 内部方法 ----------

    def _sign(self, params: Dict[str, Any]) -> str:
        """接口签名：参数按 key 正序排序（排除 sign/datas），
        拼接 key+value，末尾追加 app_secret，MD5 小写。"""
        buff = ""
        for key in sorted(params.keys()):
            if key in ("sign", "datas"):
                continue
            buff += f"{key}{params[key]}"
        buff += self.app_secret
        return hashlib.md5(buff.encode("utf-8")).hexdigest()

    def _build_request(self, path: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """组装请求体：业务参数 + 公共参数 + 签名"""
        req = dict(params or {})
        req["app_key"] = self.app_key
        req["timestamp"] = int(time.time())
        req["sign"] = self._sign(req)
        return req

    def _headers(self) -> Dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if self.debug:
            # 沙箱调试头（正式环境不要携带）
            headers["appSecret"] = self.app_secret
            headers["USER-AGENT"] = "testtest"
            headers["token"] = "test111111"
        return headers

    async def _post(self, path: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        body = self._build_request(path, params)
        url = f"{self.base_url}{path}"
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            resp = await client.post(url, json=body, headers=self._headers())
            resp.raise_for_status()
            data = resp.json()
        if data.get("code") != ERR_OK:
            logger.warning(
                f"蜜蜂API失败 {path}: code={data.get('code')} message={data.get('message')}"
            )
        return data

    # ---------- 业务接口 ----------

    async def upload_order(
        self,
        third_id: str,
        miniunit_id: Any,
        datas: Dict[str, Any],
        goods_sku: Optional[str] = None,
        call_back_url: Optional[str] = None,
        source_pack_id: Optional[Any] = None,
    ) -> Dict[str, Any]:
        """放单：推送需要充值的订单给平台

        Args:
            third_id: 商家侧订单ID（必传，唯一，如闲鱼订单号）
            miniunit_id: 商品编码（必传，商品列表接口获取）
            datas: 商品规格数据包（一维数组，不同商品字段不同，如 target/amount 等）
            goods_sku: 放单 SKU（如 SK000875），部分业务必传
            call_back_url: 回调地址（外网可访问；不传则用商户后台配置）
            source_pack_id: 资源编码（不传使用默认资源）
        Returns:
            {"code":0,"message":"ok","data":{order_id, third_id, state, ...}}
        """
        params: Dict[str, Any] = {
            "third_id": third_id,
            "miniunit_id": miniunit_id,
            "datas": datas,
        }
        if goods_sku:
            params["goods_sku"] = goods_sku
        if call_back_url:
            params["call_back_url"] = call_back_url
        if source_pack_id:
            params["source_pack_id"] = source_pack_id
        return await self._post("/api/merchant/upload_order", params)

    async def order_info(
        self,
        order_id: Optional[str] = None,
        third_id: Optional[str] = None,
        push_time: Optional[int] = None,
    ) -> Dict[str, Any]:
        """查单：查询订单当前结果状态（与回调二选一）

        Args:
            order_id: 平台充值订单号（优先使用，放单返回）
            third_id: 商家侧订单ID（与 order_id 二选一）
            push_time: 放单时间戳（秒），按 third_id 查询时必填
        Returns:
            {"code":0,"message":"ok","data":{state, order_id, third_id, cost, voucher, ...}}
        """
        params: Dict[str, Any] = {}
        if order_id:
            params["order_id"] = order_id
        if third_id:
            params["third_id"] = third_id
            params["time"] = push_time or int(time.time())
        return await self._post("/api/merchant/order_info", params)

    async def account(self) -> Dict[str, Any]:
        """余额查询"""
        return await self._post("/api/merchant/account")

    async def order_refund(
        self,
        order_id: Optional[str] = None,
        third_id: Optional[str] = None,
        reason: Optional[str] = None,
    ) -> Dict[str, Any]:
        """退款请求（可选对接）

        Args:
            order_id: 平台充值订单号
            third_id: 商家侧订单ID
            reason: 退款原因
        """
        params: Dict[str, Any] = {}
        if order_id:
            params["order_id"] = order_id
        if third_id:
            params["third_id"] = third_id
        if reason:
            params["reason"] = reason
        return await self._post("/api/merchant/order_refund", params)


def is_order_finished(state: Any) -> bool:
    """订单是否已终态（成功/失败/失败已退款）"""
    return state in (ORDER_STATE_SUCCESS, ORDER_STATE_FAILED, ORDER_STATE_FAILED_REFUNDED, ORDER_STATE_UNKNOWN)


def is_order_success(state: Any) -> bool:
    """订单是否充值成功"""
    return state == ORDER_STATE_SUCCESS
