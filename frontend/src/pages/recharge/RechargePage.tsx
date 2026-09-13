/**
 * 蜜蜂直充 - 买家充值页（无需登录的公开页面）
 *
 * 功能：
 * 1. 无需登录，通过 URL 参数 orderNo(订单号) + orderId(订单主键) 访问
 * 2. 加载时校验订单：不存在 / 订单号与订单id不匹配 均在界面明确提示
 * 3. 校验通过展示订单信息 + 手机号输入框，点击「立即充值」后调蜜蜂放单
 * 4. 提交后进入「充值中」状态并轮询后端，到账成功/失败后展示结果
 * 5. 已提交（页面刷新/重复打开）时直接展示当前充值状态，不重复放单
 * 6. 手机号仅回显脱敏（138****8000）
 */
import { useEffect, useRef, useState } from 'react'
import {
  AlertCircle,
  CheckCircle,
  ExternalLink,
  Loader2,
  PhoneCall,
  ShieldCheck,
  Smartphone,
  XCircle,
  Zap,
} from 'lucide-react'
import { queryRechargeOrder, queryRechargeStatus, submitRecharge, type RechargeOrderView } from '@/api/recharge'

type PageStatus = 'loading' | 'ready' | 'submitting' | 'processing' | 'success' | 'failed' | 'unknown' | 'invalid'

// 充值中轮询间隔（秒）与上限
const POLL_INTERVAL_MS = 5000
const POLL_MAX_TIMES = 60 // 最多轮询 5 分钟，之后停在"处理中"由闲鱼消息通知兜底

export function RechargePage() {
  const [status, setStatus] = useState<PageStatus>('loading')
  const [errorMessage, setErrorMessage] = useState('')
  const [order, setOrder] = useState<RechargeOrderView | null>(null)
  const [phone, setPhone] = useState('')
  const [tip, setTip] = useState('')
  const [pollCount, setPollCount] = useState(0)

  const [orderNo, setOrderNo] = useState('')
  const [orderId, setOrderId] = useState('')
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  // 清理轮询定时器
  useEffect(() => {
    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [])

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const no = params.get('orderNo') || ''
    const id = params.get('orderId') || ''
    if (!no || !id) {
      setStatus('invalid')
      setErrorMessage('链接无效，缺少订单参数')
      return
    }
    setOrderNo(no)
    setOrderId(id)
    loadOrder(no, id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // 加载并校验订单
  const loadOrder = async (no: string, id: string) => {
    setStatus('loading')
    const res = await queryRechargeOrder(no, id)
    if (!res.success || !res.data) {
      setStatus('invalid')
      setErrorMessage(res.message || '订单校验失败')
      return
    }
    setOrder(res.data)
    const mfStatus = res.data.mf_status || ''
    if (mfStatus === 'success') {
      setStatus('success')
    } else if (mfStatus === 'failed' || mfStatus === 'failed_refunded') {
      setStatus('failed')
    } else if (mfStatus === 'unknown') {
      setStatus('unknown')
    } else if (mfStatus === 'processing' || mfStatus === 'pending') {
      setStatus('processing')
      startPolling(no, id)
    } else {
      setStatus('ready')
    }
  }

  // 提交充值
  const handleSubmit = async () => {
    const digits = phone.replace(/\D/g, '')
    // 手机号 11 位，或 QQ号/平台账号 5~12 位（QQ会员等商品直充到QQ号）
    const ok = (/^1\d{10}$/.test(digits)) || (/^\d{5,12}$/.test(digits))
    if (!ok) {
      setTip('请输入正确的充值账号（11位手机号或QQ号）')
      return
    }
    setTip('')
    setStatus('submitting')
    const res = await submitRecharge(orderNo, orderId, digits)
    if (res.success) {
      setStatus('processing')
      startPolling(orderNo, orderId)
    } else {
      // 失败保持在当前界面，展示后端返回的中文提示，允许修改后重试
      setTip(res.message || '充值提交失败，请稍后重试或联系卖家')
      setStatus('ready')
    }
  }

  // 充值中轮询
  const startPolling = (no: string, id: string) => {
    if (timerRef.current) clearInterval(timerRef.current)
    timerRef.current = setInterval(async () => {
      const res = await queryRechargeStatus(no, id)
      const s = res.data?.status || ''
      if (s === 'success') {
        clearInterval(timerRef.current!)
        setStatus('success')
        return
      }
      if (s === 'failed' || s === 'failed_refunded') {
        clearInterval(timerRef.current!)
        setStatus('failed')
        return
      }
      if (s === 'unknown') {
        clearInterval(timerRef.current!)
        setStatus('unknown')
        return
      }
      // 仍处理中：轮询计数
      setPollCount((c) => {
        const next = c + 1
        if (next >= POLL_MAX_TIMES && timerRef.current) {
          clearInterval(timerRef.current)
        }
        return next
      })
    }, POLL_INTERVAL_MS)
  }

  // 充值账号输入：仅允许数字，限制 12 位
  const handlePhoneChange = (value: string) => {
    const digits = value.replace(/\D/g, '').slice(0, 12)
    setPhone(digits)
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-violet-600 via-purple-500 to-fuchsia-500 flex items-center justify-center p-4">
      <div className="w-full max-w-sm bg-white dark:bg-slate-800 rounded-2xl shadow-2xl overflow-hidden">
        {/* 顶部标题栏 */}
        <div className="bg-gradient-to-r from-violet-700 to-fuchsia-700 px-6 py-5 text-white text-center">
          <div className="flex items-center justify-center gap-2 mb-1">
            <Zap className="w-5 h-5 flex-shrink-0" />
            <h1 className="text-xl font-bold tracking-wide drop-shadow-sm">会员自动充值</h1>
          </div>
          <p className="text-purple-100 text-sm font-medium">输入手机号，到账后闲鱼消息通知您</p>
        </div>

        <div className="p-6">
          {/* 加载中 */}
          {status === 'loading' && (
            <div className="flex flex-col items-center py-10 gap-4">
              <Loader2 className="w-12 h-12 text-purple-500 animate-spin" />
              <p className="text-slate-600 dark:text-slate-400">正在校验订单，请稍候...</p>
            </div>
          )}

          {/* 订单无效 */}
          {status === 'invalid' && (
            <div className="flex flex-col items-center py-8 gap-4 text-center">
              <div className="w-20 h-20 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center">
                <AlertCircle className="w-12 h-12 text-red-500" />
              </div>
              <div>
                <p className="text-xl font-bold text-red-600 dark:text-red-400 mb-1">链接无效</p>
                <p className="text-sm text-slate-500 dark:text-slate-400">{errorMessage}</p>
              </div>
            </div>
          )}

          {/* 输入手机号充值 */}
          {(status === 'ready' || status === 'submitting') && order && (
            <div className="flex flex-col gap-5">
              <OrderInfo order={order} />
              <div>
                <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                  充值账号
                </label>
                <div className="relative">
                  <Smartphone className="w-5 h-5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type="tel"
                    inputMode="numeric"
                    maxLength={12}
                    value={phone}
                    onChange={(e) => handlePhoneChange(e.target.value)}
                    placeholder="请输入11位手机号或QQ号"
                    disabled={status === 'submitting'}
                    className="w-full pl-10 pr-3 py-3 rounded-lg border border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-purple-400 text-base disabled:opacity-60"
                  />
                </div>
                {tip && <p className="mt-2 text-sm text-red-500 text-center">{tip}</p>}
              </div>
              <button
                onClick={handleSubmit}
                disabled={status === 'submitting'}
                className="flex items-center justify-center gap-2 w-full px-6 py-3 bg-purple-500 hover:bg-purple-600 active:bg-purple-700 disabled:opacity-60 disabled:cursor-not-allowed text-white rounded-lg text-base font-medium transition-colors"
              >
                {status === 'submitting' ? (
                  <>
                    <Loader2 className="w-5 h-5 animate-spin" />
                    正在提交充值...
                  </>
                ) : (
                  <>
                    <PhoneCall className="w-5 h-5" />
                    立即充值
                  </>
                )}
              </button>
              <p className="text-xs text-slate-500 dark:text-slate-400 text-center leading-relaxed">
                请仔细核对充值账号（QQ会员请填QQ号，话费/网盘请填手机号），输错导致的充值错误无法退款
              </p>
            </div>
          )}

          {/* 充值中（轮询） */}
          {status === 'processing' && order && (
            <div className="flex flex-col items-center gap-4 text-center py-4">
              <div className="w-16 h-16 rounded-full bg-purple-100 dark:bg-purple-900/30 flex items-center justify-center">
                <Loader2 className="w-10 h-10 text-purple-500 animate-spin" />
              </div>
              <div>
                <p className="text-lg font-bold text-purple-600 dark:text-purple-300 mb-1">充值处理中</p>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  已提交 {order.mf_account_masked || ''}，预计几分钟内到账
                </p>
                {pollCount >= POLL_MAX_TIMES && (
                  <p className="mt-2 text-xs text-amber-500">
                    处理时间较长，到账后我会通过闲鱼消息第一时间通知您
                  </p>
                )}
              </div>
            </div>
          )}

          {/* 充值成功 */}
          {status === 'success' && order && (
            <div className="flex flex-col items-center gap-4 text-center py-4">
              <div className="w-16 h-16 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center">
                <CheckCircle className="w-10 h-10 text-green-500" />
              </div>
              <div>
                <p className="text-lg font-bold text-green-600 dark:text-green-400 mb-1">充值成功！</p>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  账号 {order.mf_account_masked || ''} 已到账，请查收
                </p>
              </div>
            </div>
          )}

          {/* 充值失败 */}
          {status === 'failed' && order && (
            <div className="flex flex-col items-center gap-4 text-center py-4">
              <div className="w-16 h-16 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center">
                <XCircle className="w-10 h-10 text-red-500" />
              </div>
              <div>
                <p className="text-lg font-bold text-red-600 dark:text-red-400 mb-1">充值失败</p>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  账号 {order.mf_account_masked || ''}，请通过闲鱼联系卖家处理退款
                </p>
              </div>
            </div>
          )}

          {/* 结果待核实 */}
          {status === 'unknown' && order && (
            <div className="flex flex-col items-center gap-4 text-center py-4">
              <div className="w-16 h-16 rounded-full bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center">
                <AlertCircle className="w-10 h-10 text-amber-500" />
              </div>
              <div>
                <p className="text-lg font-bold text-amber-600 dark:text-amber-400 mb-1">充值结果待核实</p>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  平台正在人工核实，有结果会第一时间通知您
                </p>
              </div>
            </div>
          )}
        </div>

        {/* 底部提示 */}
        <div className="px-6 py-3 bg-slate-50 dark:bg-slate-700/50 border-t border-slate-100 dark:border-slate-700">
          <p className="text-xs text-slate-600 dark:text-slate-300 text-center">
            本页面仅用于本次订单充值，请确认信息无误后提交
          </p>
        </div>
      </div>
    </div>
  )
}

/** 订单信息展示块（商品标题可点击跳转闲鱼商品详情页） */
function OrderInfo({ order }: { order: RechargeOrderView }) {
  const itemLabel = order.item_title || order.item_id || ''
  const specText = [order.spec_name, order.spec_value].filter(Boolean).join(' / ')

  const rows: Array<[string, string]> = [['订单号', order.order_no || '-']]
  if (specText) rows.push(['规格', specText])
  if (order.quantity != null) rows.push(['数量', String(order.quantity)])
  if (order.amount != null) rows.push(['金额', `¥${order.amount}`])

  return (
    <div className="rounded-lg border border-slate-200 dark:border-slate-600 divide-y divide-slate-100 dark:divide-slate-700">
      {itemLabel && (
        <div className="px-4 py-3">
          <div className="flex items-center justify-between gap-2 mb-1">
            <span className="text-sm text-slate-500 dark:text-slate-400">商品</span>
            {order.item_url && (
              <a
                href={order.item_url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 flex-shrink-0 text-xs text-purple-600 dark:text-purple-400 hover:underline"
              >
                去闲鱼查看
                <ExternalLink className="w-3.5 h-3.5" />
              </a>
            )}
          </div>
          {order.item_url ? (
            <a
              href={order.item_url}
              target="_blank"
              rel="noopener noreferrer"
              className="block text-sm font-medium text-purple-600 dark:text-purple-400 hover:underline break-all"
            >
              {itemLabel}
            </a>
          ) : (
            <p className="text-sm font-medium text-slate-800 dark:text-slate-200 break-all">{itemLabel}</p>
          )}
        </div>
      )}
      {rows.map(([label, value]) => (
        <div key={label} className="flex items-center justify-between px-4 py-2.5">
          <span className="text-sm text-slate-500 dark:text-slate-400">{label}</span>
          <span className="text-sm font-medium text-slate-800 dark:text-slate-200 text-right break-all ml-4">
            {value}
          </span>
        </div>
      ))}
      {/* 安全提示 */}
      <div className="px-4 py-2.5 flex items-center gap-2">
        <ShieldCheck className="w-4 h-4 text-green-500 flex-shrink-0" />
        <span className="text-xs text-slate-500 dark:text-slate-400">
          本站充值均通过官方渠道，安全有保障
        </span>
      </div>
    </div>
  )
}
