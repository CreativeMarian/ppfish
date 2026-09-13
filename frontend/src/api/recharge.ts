/**
 * 蜜蜂直充 - 充值页公开接口（无需登录）
 *
 * 说明：
 * - 充值页无需认证，使用原生 fetch 绕过 axios 的 token / 401 拦截。
 * - 后端统一返回 { success, message, data }，一律 HTTP 200，业务错误通过 success 传递。
 */
import type { ApiResponse } from '@/types'

const PREFIX = '/api/v1/recharge'

export interface RechargeOrderView {
  order_no: string
  amount: string | null
  quantity: number | null
  spec_name: string | null
  spec_value: string | null
  item_id: string | null
  item_title: string | null
  item_url: string | null
  /** 充值状态：'' 未提交 / pending|processing 充值中 / success 成功 / failed 失败 / unknown 待核实 */
  mf_status: string
  /** 已提交时回显脱敏手机号（如 138****8000） */
  mf_account_masked: string
}

export interface RechargeStatusView {
  order_no: string
  status: string
  platform_order_no: string
  mf_error: string
  mf_account_masked: string
}

/**
 * 充值页加载：按订单号 + 订单id 校验并返回展示信息
 */
export async function queryRechargeOrder(
  orderNo: string,
  orderId: string,
): Promise<ApiResponse<RechargeOrderView>> {
  const params = new URLSearchParams({ orderNo, orderId })
  const response = await fetch(`${PREFIX}/order?${params.toString()}`, {
    method: 'GET',
    headers: { 'Content-Type': 'application/json' },
  })
  return response.json()
}

/**
 * 买家输入手机号提交充值：触发蜜蜂放单
 */
export async function submitRecharge(
  orderNo: string,
  orderId: string,
  phone: string,
): Promise<ApiResponse<{ order_no: string; status: string }>> {
  const response = await fetch(`${PREFIX}/submit`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ order_no: orderNo, order_id: orderId, phone }),
  })
  return response.json()
}

/**
 * 充值状态轮询：返回当前充值状态（充值中/成功/失败）
 */
export async function queryRechargeStatus(
  orderNo: string,
  orderId: string,
): Promise<ApiResponse<RechargeStatusView>> {
  const params = new URLSearchParams({ orderNo, orderId })
  const response = await fetch(`${PREFIX}/status?${params.toString()}`, {
    method: 'GET',
    headers: { 'Content-Type': 'application/json' },
  })
  return response.json()
}
