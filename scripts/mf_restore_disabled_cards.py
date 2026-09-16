#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
蜜蜂无报价卡券自动恢复 v1
============================================
- 背景：蜜蜂某些商品无定价（goods_price=888888 占位），同步后卡券被停用
- 功能：每小时扫描"因无报价停用"的卡券，若蜜蜂已上架报价（有效价>0 且 <88888），
       自动更新 xy_mf_goods 成本并重新启用卡券（enabled=1），同时增量订阅价格通知
- 恢复条件（保守，避免误启用用户手动停用的卡券）：
    enabled=0 AND type='mf_api'
    AND api_config 含 miniunit_id
    AND (xy_mf_goods 中该 mid 的 cost 为空/0/>=88888  → 属于"无报价停用")
  话费卡券(175-183)用户明确不卖，永久排除
用法:  python3 scripts/mf_restore_disabled_cards.py
       MF_ENV_FILE=/path/to/.env python3 scripts/mf_restore_disabled_cards.py
"""
import json
import os
import sys
import time
import hashlib
import tempfile
import urllib.request
import urllib.parse

# 用户明确不卖话费，永久排除
EXCLUDE_IDS = list(range(175, 184))
INVALID_COST = 88888.0


def load_env(path=None):
    path = path or os.getenv("MF_ENV_FILE") or "/www/wwwroot/ppfish/.env"
    env = {}
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def acquire_lock():
    lock_path = os.path.join(tempfile.gettempdir(), "mf_restore_cards.lock")
    try:
        if sys.platform == "win32":
            import msvcrt
            f = open(lock_path, "a+")
            f.seek(0)
            if f.read(1) == "":
                f.write("x")
                f.flush()
            f.seek(0)
            msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
            return f
        else:
            import fcntl
            f = open(lock_path, "a")
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return f
    except OSError:
        print("已有恢复进程在运行，本次跳过", flush=True)
        return None


def release_lock(f):
    if f is None:
        return
    try:
        if sys.platform == "win32":
            import msvcrt
            f.seek(0)
            msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl
            fcntl.flock(f, fcntl.LOCK_UN)
    except OSError:
        pass
    try:
        f.close()
    except OSError:
        pass


def sign(params):
    buff = ""
    for k in sorted(params.keys()):
        if k in ("sign", "datas"):
            continue
        buff += "%s%s" % (k, params[k])
    buff += APP_SECRET
    return hashlib.md5(buff.encode("utf-8")).hexdigest()


def db_conn():
    import pymysql
    return pymysql.connect(**MYSQL, cursorclass=pymysql.cursors.DictCursor)


def query_miniunit(mid, retry=1):
    last = None
    for attempt in range(retry + 1):
        try:
            params = {"miniunit_id": mid, "pageNo": 1, "pageSize": 5}
            req = dict(params)
            req["app_key"] = APP_KEY
            req["timestamp"] = int(time.time())
            req["sign"] = sign(req)
            body = json.dumps(req).encode()
            r = urllib.request.Request(BASE + "/api/merchant/productGoodsListNew", data=body, method="POST")
            r.add_header("Content-Type", "application/json")
            with urllib.request.urlopen(r, timeout=40) as resp:
                data = json.loads(resp.read().decode())
            if data.get("code") != 0 and attempt < retry:
                time.sleep(2.0 + attempt)
                last = data
                continue
            return data
        except Exception as e:
            last = {"code": "exc", "err": str(e)[:60]}
            if attempt < retry:
                time.sleep(2.0 + attempt)
            continue
    return last if last is not None else {"code": "exc", "err": "unknown"}


def subscribe(product_no):
    params = {
        "productNo": str(product_no),
        "supplierAccountGuid": APP_KEY,
        "callback_url": CALLBACK,
    }
    req = dict(params)
    req["app_key"] = APP_KEY
    req["timestamp"] = int(time.time())
    req["sign"] = sign(req)
    body = urllib.parse.urlencode(req).encode()
    r = urllib.request.Request(BASE + "/api/merchant/subscribePriceNotify", data=body, method="POST")
    r.add_header("Content-Type", "application/x-www-form-urlencoded")
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            data = json.loads(resp.read().decode())
            return data.get("code") == 200
    except Exception:
        return False


def main():
    lock = acquire_lock()
    if lock is None:
        return
    try:
        conn = db_conn()
        cur = conn.cursor()
        import re
        mid_re = re.compile(r"[\"']?miniunit_id[\"']?\s*:\s*[\"']?(\d+)[\"']?")
        # 找出所有停用的 mf_api 卡券（排除话费）
        cur.execute(
            "SELECT id, name, api_config FROM xy_cards "
            "WHERE enabled = 0 AND type = 'mf_api' "
            "AND api_config LIKE '%%miniunit_id%%' "
            "AND id NOT IN (%s)" % ",".join(str(i) for i in EXCLUDE_IDS)
        )
        rows = cur.fetchall()
        # 按 mid 分组，仅保留"无报价停用"（xy_mf_goods 成本缺失或占位）
        targets = {}
        for r in rows:
            m = mid_re.search(r["api_config"])
            if not m:
                continue
            mid = m.group(1)
            cur.execute("SELECT cost FROM xy_mf_goods WHERE miniunit_id=%s", (mid,))
            row = cur.fetchone()
            cost = row["cost"] if row else None
            if cost is not None and float(cost) > 0 and float(cost) < INVALID_COST:
                continue  # 成本正常却停用 -> 用户手动停用，不自动恢复
            targets.setdefault(mid, []).append(r["id"])
        print("待检测的无报价停用卡券: %d 张 / %d 个 mid" % (sum(len(v) for v in targets.values()), len(targets)), flush=True)

        restored = []
        still = []
        for mid, card_ids in sorted(targets.items()):
            data = query_miniunit(mid)
            code = data.get("code")
            if code != 0:
                still.append((mid, "code=%s" % code))
                time.sleep(0.2)
                continue
            goods_list = (data.get("data") or {}).get("data") or []
            if not goods_list:
                still.append((mid, "empty"))
                time.sleep(0.2)
                continue
            g = goods_list[0]
            try:
                cost = float(g.get("goods_price") or 0)
            except (TypeError, ValueError):
                cost = 0
            if cost <= 0 or cost >= INVALID_COST:
                still.append((mid, "price=%s" % g.get("goods_price")))
                time.sleep(0.2)
                continue
            # 有效报价：更新成本 + 启用卡券
            name = str(g.get("goods_name") or "")
            spec = str(g.get("spec") or "")
            b_id = g.get("b_id") or 0
            biz = str(g.get("biz_name") or "")
            try:
                cur.execute(
                    "INSERT INTO xy_mf_goods (b_id, miniunit_id, goods_name, spec, cost, updated_at) "
                    "VALUES (%s,%s,%s,%s,%s,NOW()) "
                    "ON DUPLICATE KEY UPDATE b_id=VALUES(b_id), goods_name=VALUES(goods_name), "
                    "spec=VALUES(spec), cost=VALUES(cost), updated_at=NOW()",
                    (b_id, mid, name, spec, cost),
                )
                cur.execute(
                    "UPDATE xy_cards SET enabled=1, updated_at=NOW() WHERE id IN (%s)"
                    % ",".join(str(i) for i in card_ids),
                )
                conn.commit()
                restored.append((mid, len(card_ids), cost, name[:20]))
                print("恢复: mid=%s 卡券=%d 成本=%s %s" % (mid, len(card_ids), cost, name[:20]), flush=True)
                # 订阅价格通知
                subscribe(mid)
            except Exception as e:
                print("恢复失败: mid=%s err=%s" % (mid, str(e)[:80]), flush=True)
            time.sleep(0.2)
        conn.close()
        print("本轮恢复: %d 个 mid；仍无报价: %d" % (len(restored), len(still)), flush=True)
        if still:
            print("仍无报价样本:", still[:10], flush=True)
    finally:
        release_lock(lock)


env = load_env()
APP_KEY = env.get("MF_APP_KEY")
APP_SECRET = env.get("MF_APP_SECRET")
BASE = env.get("MF_BASE_URL", "https://merchant.task.mf178.cn").rstrip("/")
CALLBACK = env.get("MF_PRICE_CALLBACK", "http://43.226.44.86:9000/api/v1/mf/price-notify")
MYSQL = {
    "host": env.get("MYSQL_HOST", "127.0.0.1"),
    "port": int(env.get("MYSQL_PORT", "3306")),
    "user": env.get("MYSQL_USER", "root"),
    "password": env.get("MYSQL_PASSWORD", ""),
    "database": env.get("MYSQL_DATABASE", "xianyu_data"),
    "charset": "utf8mb4",
}

if __name__ == "__main__":
    main()
