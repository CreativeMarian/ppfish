# -*- coding: utf-8 -*-
"""
ppfish × 蜜蜂汇云 直充卡券配置脚本

功能：
    1. 为用户 10 个会员直充商品创建 mf_api 类型卡券（每个规格一条，api_config 绑定蜜蜂 miniunit_id）
    2. 绑定商品↔卡券关联（xy_card_item_relations）
    3. 将商品标记为多规格（metadata.is_multi_spec=true），使自动发货按订单规格匹配对应卡券

用法：
    cd E:\\Demo\\Fish\\ppfish
    backend-web\\.venv\\Scripts\\python.exe scripts\\config_mf_cards.py

幂等：重复执行会先删除旧的 mf_api 卡券（名称前缀"蜜蜂直充-"）再重建。
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pymysql

# 项目根（脚本位于 ppfish/scripts/）
PROJECT_ROOT = Path(__file__).resolve().parents[1]
DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 3306,
    "user": "your_mysql_user",
    "password": "your_mysql_password",
    "database": "xianyu_data",
    "charset": "utf8mb4",
}
USER_ID = 1  # 默认管理员用户

# =====================================================================
# 商品 → 蜜蜂编码映射（spec_name/spec_value 取自闲鱼商品 SKU specs，
# miniunit_id 取自蜜蜂「权益会员直充」商品市场，渠道均为全部电商/闲鱼可用）
# 缺编码的规格（蜜蜂平台无对应商品）以 None 标记，脚本会跳过并提示。
# =====================================================================
MF_PRODUCT_MAP = {
    "YOUR_GOOFISH_ITEM_ID_1": {  # 腾讯QQ会员|超级会员
        "title": "腾讯QQ会员",
        "specs": [
            ("官方直充", "QQ会员月卡", "YOUR_MINIUNIT_ID_1"),
            ("官方直充", "QQ会员季卡", "YOUR_MINIUNIT_ID_2"),
            ("官方直充", "QQ会员年卡", "YOUR_MINIUNIT_ID_3"),
            ("官方直充", "超级会员月卡", "YOUR_MINIUNIT_ID_4"),
            ("官方直充", "超级会员季卡", "YOUR_MINIUNIT_ID_5"),
            ("官方直充", "超级会员年卡", "YOUR_MINIUNIT_ID_6"),
        ],
    },
    "YOUR_GOOFISH_ITEM_ID_2": {  # 哔哩哔哩大会员
        "title": "哔哩哔哩大会员",
        "specs": [
            ("会员直充", "月卡", "YOUR_MINIUNIT_ID_7"),
            ("会员直充", "季卡", "YOUR_MINIUNIT_ID_8"),
            ("会员直充", "年卡", "YOUR_MINIUNIT_ID_9"),
        ],
    },
    "YOUR_GOOFISH_ITEM_ID_3": {  # 腾讯视频|超级影视（手机号直充）
        "title": "腾讯视频直充",
        "specs": [
            ("会员直充", "视频VIP月卡", "YOUR_MINIUNIT_ID_10"),
            ("会员直充", "视频VIP季卡", "YOUR_MINIUNIT_ID_11"),
            ("会员直充", "视频VIP年卡", "YOUR_MINIUNIT_ID_12"),
            ("会员直充", "超级影视周卡", "YOUR_MINIUNIT_ID_13"),
            ("会员直充", "超级影视月卡", "YOUR_MINIUNIT_ID_14"),
            ("会员直充", "超级影视季卡", "YOUR_MINIUNIT_ID_15"),
            ("会员直充", "超级影视年卡", "YOUR_MINIUNIT_ID_16"),
        ],
    },
    "YOUR_GOOFISH_ITEM_ID_4": {  # 优酷|酷喵|黄金
        "title": "优酷会员直充",
        "specs": [
            ("官方直充", "酷喵VIP周卡", None),   # 蜜蜂平台无"酷喵VIP周卡"规格
            ("官方直充", "酷喵VIP月卡", "YOUR_MINIUNIT_ID_17"),
            ("官方直充", "酷喵VIP季卡", "YOUR_MINIUNIT_ID_18"),
            ("官方直充", "酷喵VIP年卡", "YOUR_MINIUNIT_ID_19"),
            ("官方直充", "黄金VIP周卡", "YOUR_MINIUNIT_ID_20"),
            ("官方直充", "黄金VIP月卡", "YOUR_MINIUNIT_ID_21"),
            ("官方直充", "黄金VIP季卡", "YOUR_MINIUNIT_ID_22"),
            ("官方直充", "黄金VIP年卡", "YOUR_MINIUNIT_ID_23"),
        ],
    },
    "YOUR_GOOFISH_ITEM_ID_5": {  # 爱奇艺|黄金|白金|星钻
        "title": "爱奇艺直充",
        "specs": [
            ("官方直充", "黄金VIP周卡", "YOUR_MINIUNIT_ID_24"),
            ("官方直充", "黄金VIP月卡", "YOUR_MINIUNIT_ID_25"),
            ("官方直充", "黄金VIP季卡", "YOUR_MINIUNIT_ID_26"),
            ("官方直充", "黄金VIP年卡", "YOUR_MINIUNIT_ID_27"),
            ("官方直充", "白金VIP月卡", "YOUR_MINIUNIT_ID_28"),
            ("官方直充", "白金VIP季卡", "YOUR_MINIUNIT_ID_29"),
            ("官方直充", "白金VIP年卡", "YOUR_MINIUNIT_ID_30"),
            ("官方直充", "星钻VIP月卡", "YOUR_MINIUNIT_ID_31"),
            ("官方直充", "星钻VIP季卡", "YOUR_MINIUNIT_ID_32"),
            ("官方直充", "星钻VIP年卡", "YOUR_MINIUNIT_ID_33"),
        ],
    },
    "YOUR_GOOFISH_ITEM_ID_6": {  # 夸克网盘超级会员
        "title": "夸克网盘超级会员",
        "specs": [
            ("超级会员", "周卡", "YOUR_MINIUNIT_ID_34"),
            ("超级会员", "月卡", "YOUR_MINIUNIT_ID_35"),
            ("超级会员", "季卡", "YOUR_MINIUNIT_ID_36"),
            ("超级会员", "年卡", "YOUR_MINIUNIT_ID_37"),
        ],
    },
    "YOUR_GOOFISH_ITEM_ID_7": {  # 百度网盘超级会员
        "title": "百度网盘超级会员",
        "specs": [
            ("超级会员", "周卡", "YOUR_MINIUNIT_ID_38"),
            ("超级会员", "月卡", "YOUR_MINIUNIT_ID_39"),
            ("超级会员", "季卡", "YOUR_MINIUNIT_ID_40"),
            ("超级会员", "年卡", "YOUR_MINIUNIT_ID_41"),
        ],
    },
    "YOUR_GOOFISH_ITEM_ID_8": {  # QQ音乐绿钻
        "title": "腾讯QQ音乐绿钻",
        "specs": [
            ("QQ音乐", "周卡", "YOUR_MINIUNIT_ID_42"),
            ("QQ音乐", "月卡", "YOUR_MINIUNIT_ID_43"),
            ("QQ音乐", "季卡", "YOUR_MINIUNIT_ID_44"),
            ("QQ音乐", "年卡", "YOUR_MINIUNIT_ID_45"),
        ],
    },
    "YOUR_GOOFISH_ITEM_ID_9": {  # 酷狗|豪华VIP|超会
        "title": "酷狗音乐会员",
        "specs": [
            ("会员类型", "豪华VIP周卡", "YOUR_MINIUNIT_ID_46"),
            ("会员类型", "豪华VIP月卡", "YOUR_MINIUNIT_ID_47"),
            ("会员类型", "豪华VIP季卡", "YOUR_MINIUNIT_ID_48"),
            ("会员类型", "豪华VIP年卡", "YOUR_MINIUNIT_ID_49"),
            ("会员类型", "超会月卡", "YOUR_MINIUNIT_ID_50"),
            ("会员类型", "超会季卡", "YOUR_MINIUNIT_ID_51"),
            ("会员类型", "超会年卡", "YOUR_MINIUNIT_ID_52"),
        ],
    },
    "YOUR_GOOFISH_ITEM_ID_10": {  # 网易云黑胶VIP
        "title": "网易云音乐黑胶VIP",
        "specs": [
            ("黑胶会员", "周卡", "YOUR_MINIUNIT_ID_53"),
            ("黑胶会员", "月卡", "YOUR_MINIUNIT_ID_54"),
            ("黑胶会员", "季卡", "YOUR_MINIUNIT_ID_55"),
            ("黑胶会员", "年卡", "YOUR_MINIUNIT_ID_56"),
        ],
    },
}

# 通用 api_config 模板（datas 中 {account} 会被替换为买家手机号）
BASE_API_CONFIG = {
    "require_account": True,
    "recharge_page": True,          # 网页充值模式：买家点链接输手机号充值（消息询问保留为兜底）
    "poll_delay": 60,
    "poll_interval": 60,
    "max_poll": 8,
    "datas": {"target": "{account}"},
}


def build_api_config(miniunit_id: str, goods_sku: str = "") -> str:
    cfg = dict(BASE_API_CONFIG)
    cfg["miniunit_id"] = str(miniunit_id)
    if goods_sku:
        cfg["goods_sku"] = goods_sku
    return json.dumps(cfg, ensure_ascii=False)


def main() -> int:
    conn = pymysql.connect(**DB_CONFIG)
    try:
        with conn.cursor() as cur:
            total_cards = 0
            total_relations = 0
            skipped = []

            for item_id, product in MF_PRODUCT_MAP.items():
                title = product["title"]
                specs = product["specs"]

                # 1. 删除该商品旧的 mf_api 卡券及绑定（幂等重建）
                cur.execute(
                    "SELECT id FROM xy_cards WHERE user_id=%s AND type='mf_api' AND name LIKE '蜜蜂直充-%%' "
                    "AND id IN (SELECT card_id FROM xy_card_item_relations WHERE item_id=%s)",
                    (USER_ID, item_id),
                )
                old_ids = [r[0] for r in cur.fetchall()]
                for cid in old_ids:
                    cur.execute("DELETE FROM xy_card_item_relations WHERE card_id=%s", (cid,))
                if old_ids:
                    fmt = ",".join(["%s"] * len(old_ids))
                    cur.execute(f"DELETE FROM xy_cards WHERE id IN ({fmt})", old_ids)

                # 2. 逐规格创建 mf_api 卡券并绑定
                created_here = 0
                for spec_name, spec_value, miniunit_id in specs:
                    if not miniunit_id:
                        skipped.append(f"{title}-{spec_value}: 蜜蜂无对应商品编码")
                        continue
                    api_config = build_api_config(miniunit_id)
                    cur.execute(
                        """INSERT INTO xy_cards
                           (user_id, item_id, name, type, description, enabled, delay_seconds,
                            use_no_logistics_form, delivery_count, price, is_dockable, fee_payer,
                            min_price, dock_visibility, is_multi_spec, spec_name, spec_value,
                            api_config, text_content, data_content, image_url, image_urls,
                            created_at, updated_at)
                           VALUES (%s, %s, %s, 'mf_api', %s, 1, 0, 0, 0, NULL, 0, NULL, NULL, NULL,
                            1, %s, %s, %s, NULL, NULL, NULL, NULL, NOW(), NOW())""",
                        (
                            USER_ID,
                            item_id,
                            f"蜜蜂直充-{title}-{spec_value}",
                            "蜜蜂汇云自动直充",
                            spec_name,
                            spec_value,
                            api_config,
                        ),
                    )
                    card_id = cur.lastrowid
                    cur.execute(
                        """INSERT INTO xy_card_item_relations
                           (user_id, card_id, item_id, source, dock_record_id, created_at, updated_at)
                           VALUES (%s, %s, %s, 'own', 0, NOW(), NOW())""",
                        (USER_ID, card_id, item_id),
                    )
                    created_here += 1

                # 3. 标记商品为多规格（metadata.is_multi_spec=true）
                cur.execute(
                    "SELECT metadata FROM xy_catalog_items WHERE item_id=%s", (item_id,)
                )
                row = cur.fetchone()
                if row:
                    try:
                        meta = json.loads(row[0]) if row[0] else {}
                    except Exception:
                        meta = {}
                    if not isinstance(meta, dict):
                        meta = {}
                    meta["is_multi_spec"] = True
                    cur.execute(
                        "UPDATE xy_catalog_items SET metadata=%s WHERE item_id=%s",
                        (json.dumps(meta, ensure_ascii=False), item_id),
                    )
                else:
                    cur.execute(
                        "UPDATE xy_catalog_items SET metadata=%s WHERE item_id=%s",
                        (json.dumps({"is_multi_spec": True}, ensure_ascii=False), item_id),
                    )

                total_cards += created_here
                total_relations += created_here
                print(f"✔ {title}: {created_here} 个规格卡券已配置 (item_id={item_id})")

            conn.commit()

            print(f"\n共配置 {total_cards} 张蜜蜂直充卡券、{total_relations} 条商品绑定。")
            if skipped:
                print("\n⚠️ 以下规格未配置（蜜蜂平台无对应商品编码，可联系蜜蜂开通/上架后补充）：")
                for s in skipped:
                    print("  -", s)
            return 0
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
