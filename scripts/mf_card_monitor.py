#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
蜜蜂启用卡券巡检 v1
============================================
- 背景：蜜蜂商品可能随时下架/改价/变 888888（无报价占位）。
        若启用中的卡券对应蜜蜂无报价，买家下单会发货失败，影响店铺。
- 功能：扫描所有 enabled=1 的 mf_api 卡券的 miniunit_id（去重），
        逐个查蜜蜂实时报价：
          * 蜜蜂有效报价（0 < price < 88888）→ 不动（成本同步由 sync 负责）
          * 蜜蜂无报价（888888 / 空 / 0）→ 自动停用该卡券（enabled=0）
        —— 与 mf_restore_disabled_cards.py（停用→恢复）形成闭环：
           启用卡券失效→自动停用；停用卡券恢复→自动启用。
- 保护策略：
          * 仅处理"启用中且蜜蜂无报价"的卡券，不碰用户手动停用的
          * 每次巡检最多停用 50 个 mid（防蜜蜂接口异常导致大面积误停）
          * 单实例锁，与成本同步/恢复脚本错峰
用法:  python3 scripts/mf_card_monitor.py
       MF_ENV_FILE=/path/to/.env python3 scripts/mf_card_monitor.py
"""
import json
import os
import re
import sys
import time
import hashlib
import tempfile
import urllib.request

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

INVALID_COST = 88888.0
MAX_DISABLE_MIDS = 50
QUERY_INTERVAL = 0.5  # 蜜蜂限流约 1 秒 2 次，取保守间隔

EXCLUDE_IDS = list(range(175, 184))  # 话费卡券，用户明确不卖


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
    lock_path = os.path.join(tempfile.gettempdir(), "mf_card_monitor.lock")
    try:
        import fcntl
        f = open(lock_path, "a")
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return f
    except OSError:
        print("已有巡检进程在运行，本次跳过", flush=True)
        return None
    except ImportError:
        import msvcrt
        f = open(lock_path, "a+")
        f.seek(0)
        if f.read(1) == "":
            f.write("x")
            f.flush()
        f.seek(0)
        msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
        return f


def release_lock(f):
    if f is None:
        return
    try:
        import fcntl
        fcntl.flock(f, fcntl.LOCK_UN)
    except Exception:
        pass
    try:
        f.close()
    except Exception:
        pass


def db_conn():
    import pymysql
    return pymysql.connect(
        host=os.getenv("MYSQL_HOST", "127.0.0.1"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        user=os.getenv("MYSQL_USER", "root"),
        password=os.getenv("MYSQL_PASSWORD", ""),
        database=os.getenv("MYSQL_DATABASE", "xianyu_data"),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )


def sign(params, app_key, app_secret):
    buff = ""
    for k in sorted(params.keys()):
        if k in ("sign", "datas"):
            continue
        buff += "%s%s" % (k, params[k])
    buff += app_secret
    return hashlib.md5(buff.encode("utf-8")).hexdigest()


def query_miniunit(mid, base, app_key, app_secret, retry=3):
    for attempt in range(retry + 1):
        try:
            params = {"miniunit_id": str(mid), "pageNo": 1, "pageSize": 5}
            req = dict(params)
            req["app_key"] = app_key
            req["timestamp"] = int(time.time())
            req["sign"] = sign(req, app_key, app_secret)
            body = json.dumps(req).encode()
            r = urllib.request.Request(base + "/api/merchant/productGoodsListNew", data=body, method="POST")
            r.add_header("Content-Type", "application/json")
            with urllib.request.urlopen(r, timeout=40) as resp:
                return json.loads(resp.read().decode())
        except Exception as e:
            if attempt < retry:
                time.sleep(1.2)
            else:
                return {"code": "exc", "err": str(e)[:80]}
    return {"code": "exc"}


def main():
    lock = acquire_lock()
    if lock is None:
        return
    try:
        env = load_env()
        # .env 键写入进程环境，供 db_conn 等读取
        for k, v in env.items():
            os.environ.setdefault(k, v)
        base = env.get("MF_API_BASE") or env.get("MF_BASE_URL", "https://merchant.task.mf178.cn")
        base = base.rstrip("/")
        app_key = env.get("MF_APP_KEY", "")
        app_secret = env.get("MF_APP_SECRET", "")
        conn = db_conn()
        cur = conn.cursor()
        mid_re = re.compile(r"[\"']?miniunit_id[\"']?\s*:\s*[\"']?(\d+)[\"']?")

        # 1. 收集启用中 mf_api 卡券的 mid
        cur.execute(
            "SELECT id, name, api_config FROM xy_cards "
            "WHERE enabled = 1 AND type = 'mf_api' "
            "AND api_config LIKE '%%miniunit_id%%' "
            "AND id NOT IN (%s)" % ",".join(str(i) for i in EXCLUDE_IDS)
        )
        rows = cur.fetchall()
        mid_to_cards = {}
        for r in rows:
            m = mid_re.search(r["api_config"])
            if not m:
                continue
            mid = m.group(1)
            mid_to_cards.setdefault(mid, []).append(r["id"])
        print("启用卡券: %d 张 / %d 个 mid" % (len(rows), len(mid_to_cards)), flush=True)

        # 2. 逐个查蜜蜂报价
        disabled_mids = []
        checked = 0
        for mid, card_ids in sorted(mid_to_cards.items()):
            data = query_miniunit(mid, base, app_key, app_secret)
            code = data.get("code")
            if code != 0:
                # 接口异常：跳过，不误停
                checked += 1
                time.sleep(QUERY_INTERVAL)
                continue
            goods_list = (data.get("data") or {}).get("data") or []
            if not goods_list:
                # 蜜蜂已无此商品 -> 无报价
                disabled_mids.append((mid, len(card_ids), "gone"))
                continue
            g = goods_list[0]
            try:
                price = float(g.get("goods_price") or 0)
            except (TypeError, ValueError):
                price = 0
            if price <= 0 or price >= INVALID_COST:
                disabled_mids.append((mid, len(card_ids), "price=%s" % g.get("goods_price")))
            checked += 1
            time.sleep(QUERY_INTERVAL)

        print("查询完成: %d 个 mid；失效需停用: %d" % (checked, len(disabled_mids)), flush=True)

        # 3. 停用（最多 MAX_DISABLE_MIDS 个 mid，防误伤）
        stopped = []
        for mid, n_cards, why in disabled_mids[:MAX_DISABLE_MIDS]:
            try:
                cur.execute(
                    "UPDATE xy_cards SET enabled=0, updated_at=NOW() "
                    "WHERE id IN (%s) AND enabled=1"
                    % ",".join(str(i) for i in mid_to_cards[mid]),
                )
                conn.commit()
                stopped.append((mid, n_cards, why))
                print("停用: mid=%s 卡券=%d (%s)" % (mid, n_cards, why), flush=True)
            except Exception as e:
                print("停用失败: mid=%s err=%s" % (mid, str(e)[:80]), flush=True)
                conn.rollback()
            time.sleep(0.2)

        skipped = len(disabled_mids) - len(stopped)
        print("本轮停用: %d 个 mid；超限跳过: %d" % (len(stopped), skipped), flush=True)
        if disabled_mids:
            print("失效样本:", disabled_mids[:10], flush=True)
        conn.close()
    finally:
        release_lock(lock)


if __name__ == "__main__":
    main()
