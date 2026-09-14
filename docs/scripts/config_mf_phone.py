# -*- coding: utf-8 -*-
"""
ppfish × 蜜蜂汇云 话费直充 配置脚本

功能：
    1. 插入闲鱼话费宝贝（xy_catalog_items），若不存在
    2. 为 9 个规格（移动/联通/电信 × 50/100/200）创建 mf_api 卡券（datas 含 target+amount）
    3. 绑定商品↔卡券关联（xy_card_item_relations）
    4. 标记商品为多规格（metadata.is_multi_spec=true）

用法：
    cd E:\\Demo\\Fish\\ppfish
    backend-web\\.venv\\Scripts\\python.exe scripts\\config_mf_phone.py

幂等：重复执行会先删除旧的 mf_api 卡券（名称前缀"蜜蜂直充-话费"）再重建。
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pymysql

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 3306,
    "user": "your_mysql_user",
    "password": "your_mysql_password",
    "database": "xianyu_data",
    "charset": "utf8mb4",
}
OWNER_ID = 1
ACCOUNT_ID = 1  # 用户的闲鱼账号（xy_accounts 中 id=1）

# 闲鱼话费宝贝
ITEM_ID = "YOUR_GOOFISH_ITEM_ID"
ITEM_TITLE = "全国话费慢充 移动/联通/电信 三网通用 自动充值"
ITEM_PRICE = "51.5"

# 规格 → (miniunit_id, amount, goods_sku, 售价)
# miniunit_id 取自蜜蜂「话费直充」市场（b_id=6，全国话费直充-常规）
SPECS = [
    ("移动50元",   "YOUR_MINIUNIT_ID_1", "50", "YOUR_GOODS_SKU_1", "52"),
    ("移动100元",  "YOUR_MINIUNIT_ID_2", "100", "YOUR_GOODS_SKU_2", "102"),
    ("移动200元",  "YOUR_MINIUNIT_ID_3", "200", "YOUR_GOODS_SKU_3", "202"),
    ("联通50元",   "YOUR_MINIUNIT_ID_4", "50", "YOUR_GOODS_SKU_4", "51"),
    ("联通100元",  "YOUR_MINIUNIT_ID_5", "100", "YOUR_GOODS_SKU_5", "101"),
    ("联通200元",  "YOUR_MINIUNIT_ID_6", "200", "YOUR_GOODS_SKU_6", "201"),
    ("电信50元",   "YOUR_MINIUNIT_ID_7", "50", "YOUR_GOODS_SKU_7", "51.5"),
    ("电信100元",  "YOUR_MINIUNIT_ID_8", "100", "YOUR_GOODS_SKU_8", "101.5"),
    ("电信200元",  "YOUR_MINIUNIT_ID_9", "200", "YOUR_GOODS_SKU_9", "201.5"),
]


def build_api_config(miniunit_id: str, amount: str, goods_sku: str) -> str:
    cfg = {
        "require_account": True,
        "recharge_page": True,          # 网页充值模式：买家点链接输手机号充值
        "poll_delay": 60,
        "poll_interval": 60,
        "max_poll": 8,
        "miniunit_id": str(miniunit_id),
        "goods_sku": goods_sku,
        "datas": {"target": "{account}", "amount": amount},
    }
    return json.dumps(cfg, ensure_ascii=False)


def build_item_metadata() -> str:
    """构造话费宝贝 metadata（detail 字符串含 idle_item_sku_list）"""
    sku_list = []
    for i, (spec_value, miniunit_id, amount, goods_sku, price) in enumerate(SPECS, start=1):
        sku_list.append({
            "sku_id": f"hf{i}",
            "inventory_id": f"hf_inv_{i}",
            "quantity": 9999,
            "price": price,
            "specs": [{"name": "颜色", "value": spec_value}],
        })
    detail = {
        "id": ITEM_ID,
        "title": ITEM_TITLE,
        "price": "51~202",
        "price_text": "51~202",
        "category_id": "",
        "auction_type": "",
        "item_status": 0,
        "detail_url": "",
        "pic_info": {"url": ""},
        "detail_params": {},
        "track_params": {},
        "item_label_data": {},
        "card_type": 0,
        "source": "seller",
        "item_status_desc": "在卖",
        "quantity": 9999,
        "gmt_create": "2026-09-14 01:00:00",
        "gmt_shelf": "2026-09-14 01:00:00",
        "item_type": "b",
        "image_url": "",
        "fan_price": {"canSetFansPrice": False},
        "item_extend_list": [],
        "item_operation_info": {"moreOperateItemList": [], "operateItemList": []},
        "idle_item_sku_list": sku_list,
    }
    meta = {"detail": json.dumps(detail, ensure_ascii=False), "is_multi_spec": True}
    return json.dumps(meta, ensure_ascii=False)


def main() -> int:
    conn = pymysql.connect(**DB_CONFIG)
    try:
        with conn.cursor() as cur:
            # ========== 1. 插入话费宝贝（若不存在） ==========
            cur.execute("SELECT id FROM xy_catalog_items WHERE item_id=%s", (ITEM_ID,))
            if cur.fetchone():
                print(f"✔ 话费宝贝已存在（item_id={ITEM_ID}），跳过插入")
            else:
                cur.execute(
                    """INSERT INTO xy_catalog_items
                       (owner_id, account_id, item_id, title, price, is_polished, metadata, created_at, updated_at)
                       VALUES (%s, %s, %s, %s, %s, 0, %s, NOW(), NOW())""",
                    (OWNER_ID, ACCOUNT_ID, ITEM_ID, ITEM_TITLE, ITEM_PRICE, build_item_metadata()),
                )
                print(f"✔ 话费宝贝已插入（item_id={ITEM_ID}）")
                conn.commit()

            # ========== 2. 幂等清理旧话费卡券 ==========
            cur.execute(
                "SELECT id FROM xy_cards WHERE user_id=%s AND type='mf_api' "
                "AND name LIKE '蜜蜂直充-话费%%' "
                "AND id IN (SELECT card_id FROM xy_card_item_relations WHERE item_id=%s)",
                (OWNER_ID, ITEM_ID),
            )
            old_ids = [r[0] for r in cur.fetchall()]
            for cid in old_ids:
                cur.execute("DELETE FROM xy_card_item_relations WHERE card_id=%s", (cid,))
            if old_ids:
                fmt = ",".join(["%s"] * len(old_ids))
                cur.execute(f"DELETE FROM xy_cards WHERE id IN ({fmt})", old_ids)
                print(f"♻  清理旧话费卡券 {len(old_ids)} 张")

            # ========== 3. 创建 9 张话费卡券并绑定 ==========
            total = 0
            for spec_value, miniunit_id, amount, goods_sku, price in SPECS:
                api_config = build_api_config(miniunit_id, amount, goods_sku)
                cur.execute(
                    """INSERT INTO xy_cards
                       (user_id, item_id, name, type, description, enabled, delay_seconds,
                        use_no_logistics_form, delivery_count, price, is_dockable, fee_payer,
                        min_price, dock_visibility, is_multi_spec, spec_name, spec_value,
                        api_config, text_content, data_content, image_url, image_urls,
                        created_at, updated_at)
                       VALUES (%s, %s, %s, 'mf_api', %s, 1, 0, 0, 0, %s, 0, NULL, NULL, NULL,
                        1, '颜色', %s, %s, NULL, NULL, NULL, NULL, NOW(), NOW())""",
                    (
                        OWNER_ID,
                        ITEM_ID,
                        f"蜜蜂直充-话费-{spec_value}",
                        "蜜蜂汇云话费自动直充",
                        price,
                        spec_value,
                        api_config,
                    ),
                )
                card_id = cur.lastrowid
                cur.execute(
                    """INSERT INTO xy_card_item_relations
                       (user_id, card_id, item_id, source, dock_record_id, created_at, updated_at)
                       VALUES (%s, %s, %s, 'own', 0, NOW(), NOW())""",
                    (OWNER_ID, card_id, ITEM_ID),
                )
                total += 1
                print(f"  ✔ {spec_value}: miniunit_id={miniunit_id} amount={amount} goods_sku={goods_sku}")

            # ========== 4. 标记多规格 ==========
            cur.execute("SELECT metadata FROM xy_catalog_items WHERE item_id=%s", (ITEM_ID,))
            row = cur.fetchone()
            try:
                meta = json.loads(row[0]) if row and row[0] else {}
            except Exception:
                meta = {}
            if not isinstance(meta, dict):
                meta = {}
            meta["is_multi_spec"] = True
            cur.execute(
                "UPDATE xy_catalog_items SET metadata=%s WHERE item_id=%s",
                (json.dumps(meta, ensure_ascii=False), ITEM_ID),
            )

            conn.commit()
            print(f"\n共配置 {total} 张话费直充卡券（item_id={ITEM_ID}），全部规格已绑定。")
            return 0
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
