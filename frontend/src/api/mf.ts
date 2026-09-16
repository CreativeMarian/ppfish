import { post } from '@/utils/request'
import type { ApiResponse } from '@/types'

const MF_PREFIX = '/api/v1/mf'

/**
 * 手动触发蜜蜂成本全量同步（后台异步执行，约 5-10 分钟）
 * 完成后商品编辑页"进货价"列自动更新为最新蜜蜂报价
 */
export const syncMfCost = async (): Promise<ApiResponse> => {
  return post<ApiResponse>(`${MF_PREFIX}/sync-cost`, {})
}
