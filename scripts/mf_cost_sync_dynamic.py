#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
蜜蜂成本动态同步 v5
============================================
- 动态清单：DB 在用卡券 miniunit_id ∪ xy_mf_goods 已有
  => 在后台新增卡券后，无需手动维护清单，30 分钟内自动纳入同步
- 每 30 分钟 cron 运行：
    1) 逐个 miniunit_id 精确查询蜜蜂最新报价 -> upsert xy_mf_goods
    2) 对清单中「未订阅」的 miniunit_id 增量调用 subscribePriceNotify
       （订阅记录存 /tmp/subscribed.json，失败的不记录，下次重试）
- 兼容：每次运行把清单回写 /tmp/mf_mini_info.json，供旧脚本/手工引用
============================================
用法:  python3 mf_cost_sync_dynamic.py
"""
import json
import time
import hashlib
import urllib.request
import urllib.parse

def load_env(path="/www/wwwroot/ppfish/.env"):
    env = {}
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env

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


def sign(params):
    buff = ""
    for k in sorted(params.keys()):
        if k in ("sign", "datas"):
            continue
        buff += f"{k}{params[k]}"
    buff += APP_SECRET
    return hashlib.md5(buff.encode("utf-8")).hexdigest()


def db_conn():
    import pymysql
    return pymysql.connect(**MYSQL, cursorclass=pymysql.cursors.DictCursor)


def load_dynamic_mids():
    """动态清单 = 当前在用卡券的 miniunit_id（新增卡券自动纳入）
    仅同步在用卡券，已下架/历史商品不同步，保证每轮几分钟内完成。
    """
    conn = db_conn()
    cur = conn.cursor()
    mids = set()
    try:
        cur.execute(
            "SELECT api_config FROM xy_cards WHERE api_config LIKE '%miniunit_id%'"
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


def query_miniunit(mid):
    params = {"miniunit_id": mid, "pageNo": 1, "pageSize": 5}
    req = dict(params)
    req["app_key"] = APP_KEY
    req["timestamp"] = int(time.time())
    req["sign"] = sign(req)
    body = json.dumps(req).encode()
    r = urllib.request.Request(BASE + "/api/merchant/productGoodsListNew", data=body, method="POST")
    r.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(r, timeout=40) as resp:
        return json.loads(resp.read().decode())


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
    mids = load_dynamic_mids()
    print("动态清单 miniunit_id 总数:", len(mids), flush=True)

    conn = db_conn()
    cur = conn.cursor()
    upsert = 0
    fail = []
    mini_info = {}
    for mid in mids:
        try:
            data = query_miniunit(mid)
        except Exception as e:
            fail.append((mid, str(e)[:60]))
            time.sleep(0.5)
            continue
        code = data.get("code")
        if code != 0:
            fail.append((mid, f"code={code}"))
            time.sleep(0.5)
            continue
        goods_list = (data.get("data") or {}).get("data") or []
        if not goods_list:
            fail.append((mid, "empty"))
            time.sleep(0.5)
            continue
        g = goods_list[0]
        cost = None
        try:
            cost = float(g.get("goods_price") or 0)
        except (TypeError, ValueError):
            cost = None
        if cost is None:
            fail.append((mid, "badprice"))
            time.sleep(0.5)
            continue
        name = str(g.get("goods_name") or "")
        spec = str(g.get("spec") or "")
        b_id = g.get("b_id") or 0
        biz = str(g.get("biz_name") or "")
        recent = g.get("recently_trade_price") or g.get("recentlyTradePrice")
        cur.execute(
            "INSERT INTO xy_mf_goods (b_id, miniunit_id, goods_name, spec, cost, updated_at) "
            "VALUES (%s,%s,%s,%s,%s,NOW()) "
            "ON DUPLICATE KEY UPDATE b_id=VALUES(b_id), goods_name=VALUES(goods_name), "
            "spec=VALUES(spec), cost=VALUES(cost), updated_at=NOW()",
            (b_id, mid, name, spec, cost),
        )
        upsert += 1
        mini_info[mid] = {
            "goods_name": name,
            "product_name": biz,
            "spec": spec,
            "goods_price": cost,
            "recently_trade_price": recent,
            "b_id": b_id,
            "biz_name": biz,
        }
        time.sleep(0.3)
    conn.commit()
    conn.close()
    print("插入/更新:", upsert, "失败:", len(fail), flush=True)
    if fail:
        print("失败样本:", fail[:10], flush=True)

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
            time.sleep(0.4)
        save_subscribed(subscribed)
        print(f"新增订阅: 成功 {ok_sub} 失败 {len(fail_sub)} 失败列表 {fail_sub[:10]}", flush=True)
    else:
        print("无新增订阅", flush=True)


if __name__ == "__main__":
    main()
