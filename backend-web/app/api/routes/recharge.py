"""
蜜蜂直充 - 充值页公开接口（无需登录）

功能：
1. GET  /recharge/order    ：校验订单并返回充值页展示信息（含当前充值状态）
2. POST /recharge/submit   ：买家输入手机号提交，触发蜜蜂放单
3. GET  /recharge/status   ：状态轮询（充值中/成功/失败）

安全：
- 公开接口，须同时校验订单号(orderNo)与订单主键(orderId)匹配，二者皆对才放行；
  订单不存在 / 订单号与订单id不匹配 均返回明确中文提示。
- 提交全程 Redis 发货锁 + 幂等，防止并发重复放单（见 RechargeService）。
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.services.recharge_service import RechargeService
from common.schemas.common import ApiResponse

router = APIRouter(tags=["蜜蜂直充充值页"])


class RechargeSubmitRequest(BaseModel):
    """买家输入手机号提交充值请求"""

    order_no: str
    order_id: str
    phone: str


@router.get("/order", response_model=ApiResponse)
async def query_recharge_order(
    orderNo: str = Query(default="", description="闲鱼订单号"),
    orderId: str = Query(default="", description="订单表主键ID"),
    session: AsyncSession = Depends(deps.get_db_session),
) -> ApiResponse:
    """充值页加载：校验订单并返回展示信息（含是否已提交/充值状态）。"""
    success, message, data = await RechargeService(session).query_order(orderNo, orderId)
    return ApiResponse(success=success, message=message, data=data)


@router.post("/submit", response_model=ApiResponse)
async def recharge_submit(
    request: RechargeSubmitRequest,
    session: AsyncSession = Depends(deps.get_db_session),
) -> ApiResponse:
    """买家输入手机号提交：触发蜜蜂放单并返回处理结果。"""
    success, message, data = await RechargeService(session).submit(
        request.order_no, request.order_id, request.phone
    )
    return ApiResponse(success=success, message=message, data=data)


@router.get("/status", response_model=ApiResponse)
async def recharge_status(
    orderNo: str = Query(default="", description="闲鱼订单号"),
    orderId: str = Query(default="", description="订单表主键ID"),
    session: AsyncSession = Depends(deps.get_db_session),
) -> ApiResponse:
    """充值页状态轮询：返回当前充值状态。"""
    success, message, data = await RechargeService(session).status(orderNo, orderId)
    return ApiResponse(success=success, message=message, data=data)
