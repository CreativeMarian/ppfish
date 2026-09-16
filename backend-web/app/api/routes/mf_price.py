# -*- coding: utf-8 -*-
"""
蜜蜂汇云商品价格变更推送回调接口

蜜蜂订阅商品价格后，价格变化会实时 POST 到 callback_url：
{
  "supplierAccountGuid": "商户编号(=app_key)",
  "productNo": 商品编号(miniunit_id),
  "productCost": "100.980",   // 最新采购价(成本)
  "priceVer": 1640966400,
  "timestamp": 1640966400,
  "sign": "md5"
}
本接口验签后更新 xy_mf_goods 成本表（miniunit_id -> cost），供商品编辑页"进货价"列展示。
"""
from __future__ import annotations

import hashlib
import logging
import os
import shlex
import subprocess
from datetime import datetime
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.api import deps
from common.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/mf", tags=["蜜蜂对接"])

SYNC_LOG_PATH = "/tmp/mf_sync_manual_ui.log"


def _project_root() -> str:
    """返回项目根目录（backend-web 的上级）"""
    backend_web_dir = os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    )
    return os.path.dirname(backend_web_dir)


def _find_sync_script() -> Optional[str]:
    """定位成本同步脚本：优先项目内 scripts/，其次 /tmp 旧脚本"""
    candidates = [
        os.path.join(_project_root(), "scripts", "mf_cost_sync_dynamic.py"),
        "/www/wwwroot/ppfish/scripts/mf_cost_sync_dynamic.py",
        "/tmp/mf_cost_sync_dynamic.py",
    ]
    for p in candidates:
        if os.path.exists(p):
            return p
    return None


class PriceNotifyBody(BaseModel):
    """商品价格变更推送请求体"""
    supplierAccountGuid: str
    productNo: int
    productCost: str
    priceVer: int
    timestamp: int
    sign: str


def _get_secret() -> str:
    """读取 MF_APP_SECRET（优先环境变量，其次项目根 .env 文件）"""
    val = os.getenv("MF_APP_SECRET")
    if val:
        return val
    # 尝试项目根 .env（backend-web 的上级目录）
    candidates = [
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), ".env"),
        "/www/wwwroot/ppfish/.env",
    ]
    for env_path in candidates:
        try:
            for line in open(env_path, encoding="utf-8"):
                line = line.strip()
                if line.startswith("MF_APP_SECRET="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
        except OSError:
            continue
    return ""


def _verify_sign(params: Dict[str, Any]) -> bool:
    """验签：参数按 key 正序拼接（排除 sign），末尾追加 app_secret，MD5 小写比对"""
    secret = _get_secret()
    if not secret:
        logger.warning("MF_APP_SECRET 未配置，跳过验签")
        return True
    buff = ""
    for k in sorted(params.keys()):
        if k == "sign":
            continue
        buff += f"{k}{params[k]}"
    buff += secret
    calc = hashlib.md5(buff.encode("utf-8")).hexdigest()
    return calc == params.get("sign")


def _update_cost(product_no: int, cost: float) -> bool:
    """更新 xy_mf_goods 成本（按 miniunit_id）"""
    try:
        import pymysql
        conn = pymysql.connect(
            host=os.getenv("MYSQL_HOST", "127.0.0.1"),
            port=int(os.getenv("MYSQL_PORT", "3306")),
            user=os.getenv("MYSQL_USER", "root"),
            password=os.getenv("MYSQL_PASSWORD", "Aa123456."),
            database=os.getenv("MYSQL_DATABASE", "xianyu_data"),
            charset="utf8mb4",
        )
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE xy_mf_goods SET cost=%s, updated_at=NOW() WHERE miniunit_id=%s",
                    (round(cost, 3), str(product_no)),
                )
                affected = cur.rowcount
            conn.commit()
            return affected > 0
        finally:
            conn.close()
    except Exception as e:  # pragma: no cover
        logger.exception("更新成本失败 productNo=%s: %s", product_no, e)
        return False


@router.post("/price-notify", tags=["蜜蜂对接"])
async def price_notify(payload: PriceNotifyBody):
    """接收蜜蜂商品价格变更推送，更新成本表"""
    try:
        if not _verify_sign(payload.model_dump()):
            return {"code": 10002, "message": "sign error", "data": None}
        cost = float(payload.productCost)
        if cost <= 0:
            return {"code": 10001, "message": "productCost invalid", "data": None}
        ok = _update_cost(payload.productNo, cost)
        if ok:
            logger.info("蜜蜂价格推送已更新 miniunit_id=%s cost=%s", payload.productNo, cost)
        else:
            logger.info("蜜蜂价格推送 miniunit_id=%s 未匹配本地商品(忽略)", payload.productNo)
        return {"code": 200, "msg": "success"}
    except Exception as e:  # pragma: no cover
        logger.exception("price-notify 处理异常: %s", e)
        return {"code": 10010, "message": "请求异常", "data": None}


@router.post("/sync-cost", tags=["蜜蜂对接"])
def sync_cost(current_user: User = Depends(deps.get_current_active_user)):
    """手动触发蜜蜂成本全量同步（后台异步执行，立即返回，不阻塞请求）

    等价于宝塔计划任务执行 mf_cost_sync_dynamic.py：
    逐个查询在用卡券 miniunit_id 的最新蜜蜂报价 -> upsert xy_mf_goods，
    完成后商品编辑页"进货价"列自动显示最新成本。
    执行日志写入 /tmp/mf_sync_manual_ui.log（约 5-10 分钟）。
    """
    script = _find_sync_script()
    if not script:
        logger.warning("UI 手动同步失败：未找到 mf_cost_sync_dynamic.py")
        return {"code": 10001, "message": "未找到成本同步脚本 mf_cost_sync_dynamic.py", "data": None}
    try:
        os.makedirs("/tmp", exist_ok=True)
        with open(SYNC_LOG_PATH, "a", encoding="utf-8") as f:
            f.write(
                f"\n===== UI手动触发 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} "
                f"user={current_user.username if current_user else 'admin'} script={script} =====\n"
            )
        cmd = "nohup python3 {} >> {} 2>&1 &".format(
            shlex.quote(script), shlex.quote(SYNC_LOG_PATH)
        )
        subprocess.Popen(cmd, shell=True, start_new_session=True)
        logger.info("UI 手动触发成本同步 script=%s", script)
        return {
            "code": 200,
            "msg": "已启动成本同步（约5-10分钟），完成后商品编辑页进货价自动更新",
            "data": {"log": SYNC_LOG_PATH},
        }
    except Exception as e:  # pragma: no cover
        logger.exception("启动成本同步失败: %s", e)
        return {"code": 10002, "message": f"启动失败: {e}", "data": None}
