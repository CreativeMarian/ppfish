#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
蜜蜂成本动态同步 v6
============================================
- 动态清单：DB 在用卡券 miniunit_id ∪ xy_mf_goods 已有
  => 在后台新增卡券后，无需手动维护清单，30 分钟内自动纳入同步
- 触发方式：
    1) 宝塔计划任务每 30 分钟：python3 scripts/mf_cost_sync_dynamic.py
    2) 前端「同步进货价」按钮：POST /api/v1/mf/sync-cost（异步启动本脚本）
- v6 增强（修复“点了按钮没实际同步”）：
    1) 单实例锁：同一时间只允许一个同步进程，避免 UI 触发与计划任务并发
       写库导致 MySQL 1205 锁等待超时
    2) 分批提交：每 30 条 commit 一次，缩短事务持有行锁时间
    3) 单条插入容错：某条失败不中断整轮，记录后继续
    4) .env 路径可通过环境变量 MF_ENV_FILE 覆盖（本地开发可直接指定）
============================================
用法:  python3 mf_cost_sync_dynamic.py
       MF_ENV_FILE=/path/to/.env python3 mf_cost_sync_dynamic.py
"""
import json
import os
import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
import time
import hashlib
import tempfile
import urllib.request
import urllib.parse

COMMIT_EVERY = 30


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
    """单实例锁：拿不到锁说明已有同步进程在跑，直接跳过本次
    注意：锁文件固定路径、用追加模式打开，严禁删除/截断该文件，
    否则删除后其它进程会在新 inode 上重新拿锁，单例失效。"""
    lock_path = os.path.join(tempfile.gettempdir(), "mf_cost_sync.lock")
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
        print("已有同步进程在运行，本次跳过（锁文件: %s）" % lock_path, flush=True)
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


def load_dynamic_mids():
    """动态清单 = 当前在用卡券的 miniunit_id（新增卡券自动纳入）"""
    conn = db_conn()
    cur = conn.cursor()
    mids = set()
    try:
        cur.execute(
            "SELECT api_config FROM xy_cards WHERE api_config LIKE '%%miniunit_id%%'"
        )
        for row in cur.fetchall():
            try:
                cfg = json.loads(row["api_config"])
                mid = cfg.get("miniunit_id")
                if mid:
                    mids.add(str(mid))
            except Exception:
                continue
    finally:
        conn.close()
    return sorted(mids)


def query_miniunit(mid, retry=1):
    """查询蜜蜂报价；批量连发会触发频率限制(code=10010)，失败自动重试"""
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
                time.sleep(2.0 + attempt)  # 限流退避
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


def load_subscribed():
    try:
        return set(json.load(open(SUBSCRIBED_FILE, encoding="utf-8")))
    except Exception:
        return set()


def save_subscribed(subscribed):
    json.dump(sorted(subscribed), open(SUBSCRIBED_FILE, "w", encoding="utf-8"))


def main():
    lock = acquire_lock()
    if lock is None:
        return
    try:
        mids = load_dynamic_mids()
        print("动态清单 miniunit_id 总数:", len(mids), flush=True)

        conn = db_conn()
        cur = conn.cursor()
        upsert = 0
        fail = []
        insert_err = []
        mini_info = {}
        for idx, mid in enumerate(mids, 1):
            try:
                data = query_miniunit(mid)
            except Exception as e:
                fail.append((mid, str(e)[:60]))
                time.sleep(0.3)
                continue
            code = data.get("code")
            if code != 0:
                fail.append((mid, "code=%s" % code))
                time.sleep(0.3)
                continue
            goods_list = (data.get("data") or {}).get("data") or []
            if not goods_list:
                fail.append((mid, "empty"))
                time.sleep(0.3)
                continue
            g = goods_list[0]
            try:
                cost = float(g.get("goods_price") or 0)
            except (TypeError, ValueError):
                cost = None
            if cost is None:
                fail.append((mid, "badprice"))
                time.sleep(0.3)
                continue
            name = str(g.get("goods_name") or "")
            spec = str(g.get("spec") or "")
            b_id = g.get("b_id") or 0
            biz = str(g.get("biz_name") or "")
            recent = g.get("recently_trade_price") or g.get("recentlyTradePrice")
            try:
                cur.execute(
                    "INSERT INTO xy_mf_goods (b_id, miniunit_id, goods_name, spec, cost, updated_at) "
                    "VALUES (%s,%s,%s,%s,%s,NOW()) "
                    "ON DUPLICATE KEY UPDATE b_id=VALUES(b_id), goods_name=VALUES(goods_name), "
                    "spec=VALUES(spec), cost=VALUES(cost), updated_at=NOW()",
                    (b_id, mid, name, spec, cost),
                )
                upsert += 1
            except Exception as e:
                insert_err.append((mid, str(e)[:80]))
            mini_info[mid] = {
                "goods_name": name,
                "product_name": biz,
                "spec": spec,
                "goods_price": cost,
                "recently_trade_price": recent,
                "b_id": b_id,
                "biz_name": biz,
            }
            # 分批提交：缩短事务持有行锁时间，避免与其它写事务互相等待超时
            if idx % COMMIT_EVERY == 0:
                conn.commit()
            time.sleep(0.15)
        conn.commit()
        conn.close()
        print("插入/更新:", upsert, "接口失败:", len(fail), "写库失败:", len(insert_err), flush=True)
        if fail:
            print("接口失败样本:", fail[:10], flush=True)
        if insert_err:
            print("写库失败样本:", insert_err[:10], flush=True)

        # 回写兼容清单
        try:
            json.dump(mini_info, open(MINI_INFO_FILE, "w", encoding="utf-8"), ensure_ascii=False)
        except Exception as e:
            print("回写 mf_mini_info.json 失败:", e, flush=True)

        # 增量订阅（新增 miniunit_id）
        subscribed = load_subscribed()
        new_mids = [m for m in mids if m not in subscribed]
        if new_mids:
            ok_sub, fail_sub = 0, []
            for m in new_mids:
                if subscribe(m):
                    subscribed.add(m)
                    ok_sub += 1
                else:
                    fail_sub.append(m)
                time.sleep(0.3)
            save_subscribed(subscribed)
            print("新增订阅: 成功 %s 失败 %s 失败列表 %s" % (ok_sub, len(fail_sub), fail_sub[:10]), flush=True)
        else:
            print("无新增订阅", flush=True)
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
SUBSCRIBED_FILE = "/tmp/subscribed.json"
MINI_INFO_FILE = "/tmp/mf_mini_info.json"

if __name__ == "__main__":
    main()
