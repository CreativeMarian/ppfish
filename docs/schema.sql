-- MySQL dump 10.13  Distrib 8.0.29, for Win64 (x86_64)
--
-- Host: localhost    Database: xianyu_data
-- ------------------------------------------------------
-- Server version	8.0.29

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `xy_account_login_logs`
--

DROP TABLE IF EXISTS `xy_account_login_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_account_login_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '日志ID',
  `owner_id` bigint DEFAULT NULL COMMENT '所属用户ID',
  `account_id` bigint DEFAULT NULL COMMENT '关联账号ID（xy_accounts.id）',
  `account_identifier` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '业务账号ID',
  `username` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '登录用户名快照',
  `trigger_reason` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '触发本次登录的原因',
  `login_status` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT 'failed' COMMENT '登录状态：success/failed/skipped_cooldown/no_credentials',
  `failure_reason` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '失败大类：bad_credentials/baxia_punish_captcha/account_info_missing/exception/...',
  `error_message` text COLLATE utf8mb4_unicode_ci COMMENT '详细错误消息',
  `updated_cookie_names` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '接口续期更新的Cookie字段名（逗号分隔）',
  `duration_ms` int DEFAULT NULL COMMENT '整个登录流程耗时（毫秒）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_all_owner_id` (`owner_id`),
  KEY `idx_all_account_id` (`account_id`),
  KEY `idx_all_login_status` (`login_status`),
  KEY `idx_all_identifier_status_created` (`account_identifier`,`login_status`,`created_at`),
  KEY `idx_all_owner_created` (`owner_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账号登录日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_accounts`
--

DROP TABLE IF EXISTS `xy_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_accounts` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '账号ID',
  `owner_id` bigint NOT NULL COMMENT '所属用户ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号标识',
  `display_name` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '显示名称',
  `unb` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'UNB标识',
  `cookie` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Cookie信息',
  `login_method` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '登录方式',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active' COMMENT '账号状态',
  `username` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '登录用户名',
  `login_password` text COLLATE utf8mb4_unicode_ci COMMENT '登录密码',
  `remark` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `pause_duration` int DEFAULT '10' COMMENT '暂停时长(分钟)',
  `auto_confirm` tinyint(1) DEFAULT '0' COMMENT '自动确认发货',
  `show_browser` tinyint(1) DEFAULT '0' COMMENT '显示浏览器',
  `metadata` json DEFAULT NULL COMMENT '元数据',
  `last_login_at` datetime DEFAULT NULL COMMENT '最后登录时间',
  `last_refresh_at` datetime DEFAULT NULL COMMENT '最后刷新时间',
  `proxy_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'none' COMMENT '代理类型',
  `proxy_host` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '代理主机',
  `proxy_port` int DEFAULT NULL COMMENT '代理端口',
  `proxy_user` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '代理用户名',
  `proxy_pass` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '代理密码',
  `message_expire_time` int DEFAULT '3600' COMMENT '相同消息等待时间(秒)',
  `reply_delay_seconds` int DEFAULT '0' COMMENT '自动回复延迟时间(秒)，0表示立即回复',
  `disable_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '禁用原因',
  `scheduled_redelivery` tinyint(1) NOT NULL DEFAULT '0' COMMENT '定时补发货开关',
  `scheduled_rate` tinyint(1) NOT NULL DEFAULT '0' COMMENT '定时补评价开关',
  `auto_polish` tinyint(1) NOT NULL DEFAULT '0' COMMENT '商品自动擦亮开关',
  `confirm_before_send` tinyint(1) NOT NULL DEFAULT '0' COMMENT '发货成功再发卡券开关',
  `send_before_confirm` tinyint(1) NOT NULL DEFAULT '0' COMMENT '卡券发送成功再确认发货开关',
  `auto_red_flower` tinyint(1) NOT NULL DEFAULT '0' COMMENT '自动求小红花开关',
  `delivery_disabled` tinyint(1) NOT NULL DEFAULT '0' COMMENT '禁止发货开关',
  `delivery_disabled_reason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '禁止发货原因',
  `auto_close_order` tinyint(1) NOT NULL DEFAULT '0' COMMENT '主动关闭订单开关',
  `delivery_only_card_after_close` tinyint(1) NOT NULL DEFAULT '0' COMMENT '关闭订单后继续发货（只发卡券）',
  `delivery_disabled_excluded_items` json DEFAULT NULL COMMENT '禁止发货排除商品列表（item_id 数组，命中后按正常流程发货）',
  `ai_reply_block_ordered_users` tinyint(1) NOT NULL DEFAULT '0' COMMENT '已下单用户禁止AI回复',
  `refund_cancel_enabled` tinyint(1) NOT NULL DEFAULT '0' COMMENT '退款订单注销开关',
  `refund_cancel_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '退款订单注销请求URL',
  `refund_cancel_timeout` int DEFAULT '60' COMMENT '退款订单注销超时时间(秒)',
  `agree_deliver_enabled` tinyint(1) NOT NULL DEFAULT '0' COMMENT '同意后发货开关',
  `agree_deliver_notify_message` varchar(2000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '同意后发货-通知用户信息',
  `agree_deliver_pickup_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '同意后发货-提货URL',
  `only_send_card` tinyint(1) NOT NULL DEFAULT '0' COMMENT '只发卡券不确认发货开关',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_id` (`account_id`),
  KEY `idx_owner_id` (`owner_id`),
  KEY `idx_unb` (`unb`),
  KEY `idx_account_created` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='闲鱼账号表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_advertisements`
--

DROP TABLE IF EXISTS `xy_advertisements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_advertisements` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '广告ID',
  `user_id` bigint NOT NULL COMMENT '申请用户ID',
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '广告标题',
  `content` text COLLATE utf8mb4_unicode_ci COMMENT '广告正文',
  `link` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '广告链接',
  `expire_date` date DEFAULT NULL COMMENT '到期日期',
  `image_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '图片URL',
  `ad_type` enum('carousel','text') COLLATE utf8mb4_unicode_ci DEFAULT 'text' COMMENT '广告类型',
  `months` int DEFAULT NULL COMMENT '购买月数',
  `total_amount` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '广告总金额',
  `status` enum('unpaid','pending','approved') COLLATE utf8mb4_unicode_ci DEFAULT 'unpaid' COMMENT '审核状态',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_ad_type` (`ad_type`),
  KEY `idx_expire_date` (`expire_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='广告表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_agent_orders`
--

DROP TABLE IF EXISTS `xy_agent_orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_agent_orders` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '下单用户ID（发货方）',
  `order_no` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '闲鱼订单号',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '商品ID',
  `card_id` bigint NOT NULL COMMENT '使用的卡券ID',
  `dock_record_id` bigint NOT NULL COMMENT '对接记录ID',
  `dock_level` int NOT NULL COMMENT '对接层级：1=一级，2=二级',
  `sale_price` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '售价（用户卖出的价格）',
  `dock_price` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '对接价格（拿货价）',
  `card_price` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '卡券成本（货主对接价）',
  `level2_cost` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '二级拿货价（一级的sub_dock_price）',
  `profit` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '0.00' COMMENT '利润（售价-对接价）',
  `fee_amount` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '手续费金额',
  `fee_payer` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '手续费承担方：dealer-分销商，distributor-货主',
  `upstream_user_id` bigint DEFAULT NULL COMMENT '上级用户ID',
  `upstream_dock_record_id` bigint DEFAULT NULL COMMENT '上级对接记录ID',
  `owner_user_id` bigint DEFAULT NULL COMMENT '货主用户ID',
  `delivery_content` text COLLATE utf8mb4_unicode_ci COMMENT '发货内容',
  `buyer_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '买家ID',
  `status` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'delivered' COMMENT '状态：delivered-已发货，settled-已结算，failed-失败',
  `settle_remark` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '结算备注',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_order_no` (`order_no`),
  KEY `idx_dock_record_id` (`dock_record_id`),
  KEY `idx_upstream_user_id` (`upstream_user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_agent_order_created` (`created_at`),
  KEY `idx_ao_upstream_status` (`upstream_user_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='代理订单表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_ai_chat_messages`
--

DROP TABLE IF EXISTS `xy_ai_chat_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_ai_chat_messages` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '消息ID',
  `chat_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '聊天ID',
  `cookie_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号标识',
  `user_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '用户ID',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品ID',
  `role` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '角色(user/assistant)',
  `content` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '消息内容',
  `intent` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '意图(price/tech/default)',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_chat_id` (`chat_id`),
  KEY `idx_cookie_id` (`cookie_id`),
  KEY `ix_ai_chat_messages_chat_cookie` (`chat_id`,`cookie_id`),
  KEY `ix_ai_chat_messages_intent` (`cookie_id`,`intent`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI聊天消息表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_ai_listing_configs`
--

DROP TABLE IF EXISTS `xy_ai_listing_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_ai_listing_configs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint NOT NULL COMMENT '归属用户（本系统用户ID）',
  `name` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '配置名称',
  `provider_type` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'openai_compatible' COMMENT '服务商类型：openai_compatible 等',
  `text_base_url` varchar(300) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '文案接口地址',
  `text_api_key` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '文案接口密钥',
  `text_model` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '文案模型名称',
  `text_temperature` decimal(4,2) NOT NULL DEFAULT '0.70' COMMENT '文案生成温度',
  `text_max_tokens` int NOT NULL DEFAULT '2048' COMMENT '文案生成最大token数',
  `prompt_template` text COLLATE utf8mb4_unicode_ci COMMENT '自定义提示词模板（为空则用内置模板）',
  `image_enabled` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否启用AI图片生成',
  `image_base_url` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '图片接口地址',
  `image_api_key` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '图片接口密钥',
  `image_model` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '图片模型名称',
  `image_size` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '1024x1024' COMMENT '图片尺寸，如 1024x1024',
  `image_count` int NOT NULL DEFAULT '1' COMMENT '每条素材生成图片数量（1~9）',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已删除（软删除）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `ix_xy_ai_listing_configs_owner_id` (`owner_id`),
  KEY `idx_alc_owner_deleted` (`owner_id`,`is_deleted`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI铺货配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_ai_listing_task_items`
--

DROP TABLE IF EXISTS `xy_ai_listing_task_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_ai_listing_task_items` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '所属任务ID',
  `owner_id` bigint NOT NULL COMMENT '归属用户（本系统用户ID）',
  `seq` int NOT NULL DEFAULT '0' COMMENT '序号（从1开始）',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending' COMMENT '状态：pending/running/success/failed',
  `title` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '生成的商品标题',
  `material_id` bigint DEFAULT NULL COMMENT '入库后的素材ID',
  `image_count` int NOT NULL DEFAULT '0' COMMENT '本条素材图片数量',
  `error_message` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '失败原因',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `ix_xy_ai_listing_task_items_task_id` (`task_id`),
  KEY `idx_alti_task_status` (`task_id`,`status`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI铺货任务明细表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_ai_listing_tasks`
--

DROP TABLE IF EXISTS `xy_ai_listing_tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_ai_listing_tasks` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint NOT NULL COMMENT '归属用户（本系统用户ID）',
  `task_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '任务ID（UUID）',
  `config_id` bigint NOT NULL COMMENT '使用的AI铺货配置ID',
  `config_name` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '配置名称快照',
  `keyword` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '生成主题/关键词',
  `total_count` int NOT NULL DEFAULT '0' COMMENT '计划生成条数',
  `success_count` int NOT NULL DEFAULT '0' COMMENT '已成功条数',
  `failed_count` int NOT NULL DEFAULT '0' COMMENT '已失败条数',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending' COMMENT '状态：pending/running/success/partial/failed/canceled',
  `error_message` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '整体失败原因',
  `params` json DEFAULT NULL COMMENT '提交参数快照（价格模式、素材默认值等）',
  `started_at` datetime DEFAULT NULL COMMENT '开始执行时间',
  `finished_at` datetime DEFAULT NULL COMMENT '执行结束时间',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已删除（软删除）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_xy_ai_listing_tasks_task_id` (`task_id`),
  KEY `ix_xy_ai_listing_tasks_owner_id` (`owner_id`),
  KEY `idx_alt_owner_created` (`owner_id`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI铺货任务表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_announcements`
--

DROP TABLE IF EXISTS `xy_announcements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_announcements` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '公告ID',
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '公告标题',
  `content` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '公告内容',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已删除',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='公告信息表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_auto_rate_configs`
--

DROP TABLE IF EXISTS `xy_auto_rate_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_auto_rate_configs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `enabled` tinyint(1) DEFAULT '0' COMMENT '是否启用自动评价',
  `rate_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'text' COMMENT '评价类型',
  `text_content` text COLLATE utf8mb4_unicode_ci COMMENT '固定评价文字内容',
  `api_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'API地址',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_id` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='自动评价配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_auto_reply_message_logs`
--

DROP TABLE IF EXISTS `xy_auto_reply_message_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_auto_reply_message_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint DEFAULT NULL COMMENT '所属系统用户ID',
  `owner_username` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '所属系统用户名',
  `account_pk` bigint DEFAULT NULL COMMENT '账号主键ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '闲鱼账号ID',
  `account_name` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '闲鱼账号显示名称',
  `chat_id` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '聊天会话ID',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品ID',
  `item_title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品标题',
  `order_no` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '订单号（自动发货等场景关联订单）',
  `source_message_id` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '源消息ID',
  `sender_user_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '发送方闲鱼用户ID',
  `sender_user_name` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '发送方昵称',
  `source_message` text COLLATE utf8mb4_unicode_ci COMMENT '收到的消息内容',
  `source_message_time` datetime DEFAULT NULL COMMENT '收到消息时间',
  `process_status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'processing' COMMENT '处理状态：processing/success/skipped/failed',
  `decision_reason` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'processing' COMMENT '决策原因',
  `reply_strategy` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'none' COMMENT '回复策略：keyword/ai/default/none',
  `reply_mode` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'none' COMMENT '回复模式：text/image/text_image/none',
  `matched_keyword` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '命中的关键词',
  `matched_rule_type` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '命中的规则类型',
  `default_reply_scope` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '默认回复作用域：item/account',
  `default_reply_once` tinyint(1) NOT NULL DEFAULT '0' COMMENT '默认回复是否仅回复一次',
  `ai_model_name` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'AI模型名称',
  `ai_provider_name` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'AI服务商名称',
  `reply_text` text COLLATE utf8mb4_unicode_ci COMMENT '回复文本内容',
  `reply_image_url` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '回复图片URL',
  `reply_segments` json DEFAULT NULL COMMENT '拆分后的回复分段',
  `error_message` text COLLATE utf8mb4_unicode_ci COMMENT '错误信息',
  `send_status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unknown' COMMENT '发送状态：success-发送成功/failed-发送失败/unknown-未知(无响应)/timeout-超时(无响应超过阈值)',
  `send_fail_reason` text COLLATE utf8mb4_unicode_ci COMMENT '发送失败原因（如被安全拦截的明文文案）',
  `raw_message_json` json DEFAULT NULL COMMENT '原始消息JSON',
  `context_snapshot` json DEFAULT NULL COMMENT '上下文快照',
  `send_result_json` json DEFAULT NULL COMMENT '发送结果快照',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_owner_id` (`owner_id`),
  KEY `idx_account_pk` (`account_pk`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_chat_id` (`chat_id`),
  KEY `idx_item_id` (`item_id`),
  KEY `idx_order_no` (`order_no`),
  KEY `idx_source_message_id` (`source_message_id`),
  KEY `idx_sender_user_id` (`sender_user_id`),
  KEY `idx_process_status` (`process_status`),
  KEY `idx_decision_reason` (`decision_reason`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_arml_account_created` (`account_id`,`created_at`),
  KEY `idx_arml_account_status_created` (`account_id`,`process_status`,`created_at`),
  KEY `idx_arml_owner_created` (`owner_id`,`created_at`),
  KEY `idx_arml_owner_status_created` (`owner_id`,`process_status`,`created_at`),
  KEY `idx_arml_status_created` (`process_status`,`created_at`),
  KEY `idx_arml_status_strategy_created` (`process_status`,`reply_strategy`,`created_at`),
  KEY `idx_arml_strategy_created` (`reply_strategy`,`created_at`),
  KEY `idx_arml_order_strategy_id` (`order_no`,`reply_strategy`,`id`),
  KEY `idx_arml_strategy_order_id` (`reply_strategy`,`order_no`,`id`)
) ENGINE=InnoDB AUTO_INCREMENT=172 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='自动回复消息日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_card_item_relations`
--

DROP TABLE IF EXISTS `xy_card_item_relations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_card_item_relations` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '所属用户ID',
  `card_id` bigint NOT NULL COMMENT '卡券ID',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '商品ID',
  `source` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'own' COMMENT '卡券来源：own-自有，dock_l1-一级对接，dock_l2-二级对接',
  `dock_record_id` bigint NOT NULL DEFAULT '0' COMMENT '对接记录ID（对接卡券时关联，0表示自有卡券）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_card_item_dock` (`card_id`,`item_id`,`dock_record_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_card_id` (`card_id`),
  KEY `idx_item_id` (`item_id`),
  KEY `idx_cir_user_item` (`user_id`,`item_id`),
  KEY `idx_cir_item_card` (`item_id`,`card_id`)
) ENGINE=InnoDB AUTO_INCREMENT=184 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='卡券商品关联表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_cards`
--

DROP TABLE IF EXISTS `xy_cards`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_cards` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '卡券ID',
  `user_id` bigint NOT NULL COMMENT '所属用户ID',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '关联商品ID',
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '卡券名称',
  `type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '卡券类型(api/text/data/image)',
  `description` text COLLATE utf8mb4_unicode_ci COMMENT '卡券描述',
  `enabled` tinyint(1) DEFAULT '1' COMMENT '是否启用',
  `delay_seconds` int DEFAULT '0' COMMENT '延迟秒数',
  `use_no_logistics_form` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否通过无需邮寄表单发货',
  `delivery_count` int DEFAULT '0' COMMENT '发货次数',
  `price` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '对接价格',
  `is_dockable` tinyint(1) DEFAULT '0' COMMENT '是否可对接',
  `fee_payer` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '手续费支付方式：distributor-分销主支付，dealer-分销商支付',
  `min_price` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '最低售价',
  `dock_visibility` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '对接可见性：public-所有人可见，dealer_only-仅分销商可见',
  `is_multi_spec` tinyint(1) DEFAULT '0' COMMENT '是否多规格',
  `spec_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '规格名称',
  `spec_value` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '规格值',
  `api_config` text COLLATE utf8mb4_unicode_ci COMMENT 'API配置(JSON)',
  `text_content` longtext COLLATE utf8mb4_unicode_ci,
  `data_content` longtext COLLATE utf8mb4_unicode_ci,
  `image_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '图片URL',
  `image_urls` text COLLATE utf8mb4_unicode_ci COMMENT '多图片URL列表(JSON数组，最多3张)',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_item_id` (`item_id`),
  KEY `idx_card_user_item` (`user_id`,`item_id`),
  KEY `idx_cards_dockable_enabled` (`is_dockable`,`enabled`),
  KEY `idx_cards_user_id_desc` (`user_id`,`id`),
  KEY `idx_cards_user_enabled` (`user_id`,`enabled`)
) ENGINE=InnoDB AUTO_INCREMENT=184 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='卡券表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_catalog_items`
--

DROP TABLE IF EXISTS `xy_catalog_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_catalog_items` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '商品ID',
  `owner_id` bigint NOT NULL COMMENT '所属用户ID',
  `account_id` bigint NOT NULL COMMENT '关联账号ID',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '商品标识',
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品标题',
  `price` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品价格',
  `ai_prompt` text COLLATE utf8mb4_unicode_ci COMMENT '商品AI提示词',
  `is_polished` tinyint(1) DEFAULT '0' COMMENT '是否擦亮',
  `metadata` json DEFAULT NULL COMMENT '商品元数据',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cat_account_item` (`account_id`,`item_id`),
  KEY `idx_owner_id` (`owner_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_item_id` (`item_id`),
  KEY `idx_cat_account_item` (`account_id`,`item_id`),
  KEY `idx_cat_owner_created` (`owner_id`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品目录表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_chat_quick_phrases`
--

DROP TABLE IF EXISTS `xy_chat_quick_phrases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_chat_quick_phrases` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint NOT NULL COMMENT '归属用户（本系统用户ID）',
  `title` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '短语标题',
  `content` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '短语内容（发送的文本）',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序值，越小越靠前',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `ix_xy_chat_quick_phrases_owner_id` (`owner_id`),
  KEY `idx_chat_quick_phrase_owner_sort` (`owner_id`,`sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='在线聊天快捷短语';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_collect_fallback_accounts`
--

DROP TABLE IF EXISTS `xy_collect_fallback_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_collect_fallback_accounts` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint NOT NULL COMMENT '归属用户ID',
  `category_id` bigint DEFAULT NULL COMMENT '所属分类ID（NULL=未分类全局兜底）',
  `account_ids` json DEFAULT NULL COMMENT '兜底采集账号ID列表（JSON数组，多选轮换使用）',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已删除（软删除）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cfa_owner_category` (`owner_id`,`category_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户级兜底采集账号配置表（按分类配置）';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_confirm_receipt_messages`
--

DROP TABLE IF EXISTS `xy_confirm_receipt_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_confirm_receipt_messages` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `enabled` tinyint(1) DEFAULT '0' COMMENT '是否启用',
  `message_content` text COLLATE utf8mb4_unicode_ci COMMENT '消息文本内容',
  `message_image` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '消息图片URL',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_id` (`account_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='确认收货消息配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_cookie_refresh_schedules`
--

DROP TABLE IF EXISTS `xy_cookie_refresh_schedules`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_cookie_refresh_schedules` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `expire_at` datetime NOT NULL COMMENT '当前Cookie续期到期时间',
  `last_refresh_at` datetime DEFAULT NULL COMMENT '最近一次续期成功时间',
  `last_status` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '最近一次状态：initialized/success/failed',
  `last_error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '最近一次错误信息',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_id` (`account_id`),
  KEY `idx_expire_at` (`expire_at`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Cookie续期计划表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_db_backup_log`
--

DROP TABLE IF EXISTS `xy_db_backup_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_db_backup_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '状态：success/failed',
  `file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备份文件名',
  `file_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备份文件绝对路径',
  `file_size` bigint DEFAULT NULL COMMENT '备份文件大小(字节)',
  `table_count` int DEFAULT NULL COMMENT '备份的数据表数量',
  `total_rows` bigint DEFAULT NULL COMMENT '备份的数据总行数',
  `duration_ms` int DEFAULT NULL COMMENT '备份耗时(毫秒)',
  `error_message` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '错误信息',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=67 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='数据库备份日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_default_replies`
--

DROP TABLE IF EXISTS `xy_default_replies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_default_replies` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '回复ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号标识',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品ID(空为账号默认回复)',
  `enabled` tinyint(1) DEFAULT '0' COMMENT '是否启用',
  `reply_type` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT 'text' COMMENT '回复类型：text-文本(可附带图片)，api-接口',
  `reply_content` text COLLATE utf8mb4_unicode_ci COMMENT '回复内容',
  `reply_image` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '回复图片URL',
  `api_url` varchar(1024) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'API地址(reply_type=api时POST此地址)',
  `api_timeout` int DEFAULT '80' COMMENT 'API请求超时时间(秒)',
  `reply_once` tinyint(1) DEFAULT '0' COMMENT '只回复一次',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_item` (`account_id`,`item_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_item_id` (`item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='默认回复表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_default_reply_records`
--

DROP TABLE IF EXISTS `xy_default_reply_records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_default_reply_records` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '记录ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号标识',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品ID(空为账号默认回复)',
  `user_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '被回复用户ID',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_account_item_user` (`account_id`,`item_id`,`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='默认回复记录表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_delivery_block_rules`
--

DROP TABLE IF EXISTS `xy_delivery_block_rules`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_delivery_block_rules` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `account_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `rule_code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '规则编码',
  `enabled` tinyint(1) NOT NULL DEFAULT '0' COMMENT '规则开关',
  `priority` int NOT NULL DEFAULT '0' COMMENT '执行优先级（越小越先执行）',
  `block_reason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '禁止发货原因（发给买家的消息）',
  `auto_close_order` tinyint(1) NOT NULL DEFAULT '0' COMMENT '命中后主动关闭订单',
  `only_card_after_close` tinyint(1) NOT NULL DEFAULT '0' COMMENT '关闭订单后继续发货（只发卡券）',
  `excluded_item_ids` json DEFAULT NULL COMMENT '该规则的排除商品列表（命中则跳过本规则）',
  `config` json DEFAULT NULL COMMENT '规则专属参数',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_rule` (`account_id`,`rule_code`),
  KEY `idx_account_id` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='禁止发货规则配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_dock_code_bindings`
--

DROP TABLE IF EXISTS `xy_dock_code_bindings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_dock_code_bindings` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '绑定用户ID（分销商）',
  `dock_code` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '对接码',
  `target_user_id` bigint NOT NULL COMMENT '对接码拥有者用户ID（供应商）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '绑定时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_target` (`user_id`,`target_user_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_target_user_id` (`target_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对接码绑定表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_dock_records`
--

DROP TABLE IF EXISTS `xy_dock_records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_dock_records` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `card_id` bigint NOT NULL COMMENT '来源卡券ID',
  `dock_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '对接名称',
  `markup_amount` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '0.00' COMMENT '加价金额',
  `remark` text COLLATE utf8mb4_unicode_ci COMMENT '备注',
  `delivery_count` int NOT NULL DEFAULT '0' COMMENT '发货次数',
  `status` tinyint(1) DEFAULT '1' COMMENT '对接状态：1启用 0停用',
  `disable_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '禁用原因',
  `owner_disabled` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否被上级禁用锁定：1是 0否',
  `level` int NOT NULL DEFAULT '1' COMMENT '分销层级：1=一级分销，2=二级分销',
  `parent_dock_id` bigint DEFAULT NULL COMMENT '上级对接记录ID，一级分销为NULL',
  `source_user_id` bigint DEFAULT NULL COMMENT '上级分销商用户ID，一级分销为NULL',
  `allow_sub_dock` tinyint(1) DEFAULT '0' COMMENT '是否允许下级对接',
  `sub_dock_price` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '给下级的对接价格（一级分销商设定）',
  `sub_dock_visibility` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '下级对接可见性：public-所有人可见，dealer_only-仅绑定对接码的分销商可见',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_card_id` (`card_id`),
  KEY `idx_parent_dock_id` (`parent_dock_id`),
  KEY `idx_dock_user_level` (`user_id`,`level`),
  KEY `idx_dock_source_level` (`source_user_id`,`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对接记录表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_feedback_messages`
--

DROP TABLE IF EXISTS `xy_feedback_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_feedback_messages` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '消息ID',
  `feedback_id` bigint NOT NULL COMMENT '关联反馈ID',
  `user_id` bigint NOT NULL COMMENT '发送者用户ID',
  `content` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '消息内容',
  `is_admin` tinyint(1) DEFAULT '0' COMMENT '是否为管理员消息',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_feedback_id` (`feedback_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='意见反馈消息表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_feedbacks`
--

DROP TABLE IF EXISTS `xy_feedbacks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_feedbacks` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '反馈ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `cookie_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '关联账号ID',
  `title` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '标题',
  `content` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '内容',
  `feedback_type` enum('FEATURE','BUG','OTHER') COLLATE utf8mb4_unicode_ci DEFAULT 'OTHER' COMMENT '反馈类型',
  `images` text COLLATE utf8mb4_unicode_ci COMMENT '图片URL(JSON数组)',
  `is_resolved` tinyint(1) DEFAULT '0' COMMENT '是否已解决',
  `resolved_at` datetime DEFAULT NULL COMMENT '解决时间',
  `admin_reply` text COLLATE utf8mb4_unicode_ci COMMENT '管理员回复',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_is_resolved` (`is_resolved`),
  KEY `idx_feedback_type` (`feedback_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='意见反馈表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_fund_flows`
--

DROP TABLE IF EXISTS `xy_fund_flows`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_fund_flows` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `type` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '流水类型：income-收入，expense-支出',
  `amount` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '发生额',
  `balance_before` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '发生前余额',
  `balance_after` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '发生后余额',
  `order_id` bigint DEFAULT NULL COMMENT '关联订单ID',
  `dock_record_id` bigint DEFAULT NULL COMMENT '关联对接记录ID',
  `description` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '流水描述',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '发生时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_dock_record_id` (`dock_record_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_ff_user_id_desc` (`user_id`,`id`),
  KEY `idx_ff_user_type_id_desc` (`user_id`,`type`,`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='资金流水表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_goofish_crawl_items`
--

DROP TABLE IF EXISTS `xy_goofish_crawl_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_goofish_crawl_items` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `job_id` bigint NOT NULL COMMENT '关联的抓取任务ID',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '闲鱼商品ID',
  `title` text COLLATE utf8mb4_unicode_ci COMMENT '商品标题',
  `price` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品价格',
  `area` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '所在地区',
  `seller_name` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '卖家昵称',
  `item_url` text COLLATE utf8mb4_unicode_ci COMMENT '商品链接',
  `main_image` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '主图URL',
  `publish_time` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '发布时间',
  `want_count` int DEFAULT NULL COMMENT '想要人数',
  `view_count` int DEFAULT NULL COMMENT '浏览次数',
  `description` text COLLATE utf8mb4_unicode_ci COMMENT '商品描述',
  `detail_error` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '详情抓取错误信息',
  `raw_json` json DEFAULT NULL COMMENT '原始数据JSON',
  `fetched_at` datetime NOT NULL COMMENT '抓取时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_job_item` (`job_id`,`item_id`),
  KEY `idx_job_id` (`job_id`),
  KEY `idx_fetched_at` (`fetched_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_goofish_crawl_jobs`
--

DROP TABLE IF EXISTS `xy_goofish_crawl_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_goofish_crawl_jobs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint NOT NULL COMMENT '归属用户ID',
  `cookie_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号标识',
  `keyword` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '抓取关键词',
  `interval_seconds` int NOT NULL DEFAULT '900' COMMENT '执行间隔(秒)',
  `start_page` int NOT NULL DEFAULT '1' COMMENT '起始页码',
  `pages` int NOT NULL DEFAULT '1' COMMENT '抓取页数',
  `page_size` int NOT NULL DEFAULT '20' COMMENT '每页数量',
  `fetch_detail` tinyint(1) DEFAULT '1' COMMENT '是否抓取详情',
  `detail_limit` int NOT NULL DEFAULT '20' COMMENT '抓取详情数量上限',
  `enabled` tinyint(1) DEFAULT '1' COMMENT '是否启用',
  `last_run_at` datetime DEFAULT NULL COMMENT '最近一次执行时间',
  `last_error` text COLLATE utf8mb4_unicode_ci COMMENT '最近一次错误信息',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_owner_id` (`owner_id`),
  KEY `idx_cookie_id` (`cookie_id`),
  KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_keyword_rules`
--

DROP TABLE IF EXISTS `xy_keyword_rules`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_keyword_rules` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '规则ID',
  `owner_id` bigint NOT NULL COMMENT '所属用户ID',
  `account_id` bigint DEFAULT NULL COMMENT '关联账号ID',
  `keyword` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '关键词',
  `reply_content` text COLLATE utf8mb4_unicode_ci COMMENT '回复内容',
  `reply_type` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '回复类型(text/image)',
  `image_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '图片URL',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品ID',
  `priority` int DEFAULT '100' COMMENT '优先级',
  `is_active` tinyint(1) DEFAULT '1' COMMENT '是否启用',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_owner_id` (`owner_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_keyword` (`keyword`),
  KEY `idx_kw_account_item` (`account_id`,`item_id`),
  KEY `idx_kw_account_active` (`account_id`,`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='关键词规则表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_listing_monitor_categories`
--

DROP TABLE IF EXISTS `xy_listing_monitor_categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_listing_monitor_categories` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint NOT NULL COMMENT '归属用户ID',
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '分类名称',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已删除（软删除）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_lmc_owner` (`owner_id`),
  KEY `idx_lmc_owner_deleted` (`owner_id`,`is_deleted`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品监控分类表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_listing_monitor_items`
--

DROP TABLE IF EXISTS `xy_listing_monitor_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_listing_monitor_items` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `monitor_task_id` bigint NOT NULL COMMENT '关联的商品监控任务ID',
  `owner_id` bigint DEFAULT NULL COMMENT '归属用户ID',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '闲鱼商品ID',
  `title` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品标题',
  `price` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品价格（展示文本）',
  `area` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品所在地区',
  `pic_url` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品主图URL',
  `seller_id` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '卖家ID（搜索返回，可能为加密串）',
  `seller_user_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '卖家真实用户ID（商品详情接口补全）',
  `seller_nick` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '卖家昵称',
  `seller_avatar` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '卖家头像URL',
  `want_count` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '想要数（从营销标签解析的真实想要人数）',
  `tags` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品营销标签（逗号分隔，如：4天内上新,235人想要）',
  `publish_time` datetime DEFAULT NULL COMMENT '商品发布时间',
  `target_url` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品详情跳转URL',
  `raw_json` text COLLATE utf8mb4_unicode_ci COMMENT '商品原始数据（搜索结果项JSON，兜底）',
  `detail_json` mediumtext COLLATE utf8mb4_unicode_ci COMMENT '商品详情数据（详情接口返回JSON）',
  `seller_fill_status` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '卖家ID补全结果：failed-明确失败不再补全（如跨境商品/已下架）',
  `seller_fill_fail_reason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '卖家ID补全失败原因（明确业务失败的原文）',
  `is_dm_sent` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已发起私信（已处理，避免重复发送）',
  `dm_account_id` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '成功私信使用的账号ID（后续优先用该账号下单）',
  `dm_chat_id` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '私信会话ID（create-chat 返回的 chat_id）',
  `dm_status` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '私信发送结果：success/failed/unknown',
  `dm_fail_reason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '私信发送失败原因',
  `dm_attempts` int NOT NULL DEFAULT '0' COMMENT '私信发送尝试次数（失败重试用）',
  `is_ordered` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已下单成功',
  `order_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '下单成功的订单ID（拍下）',
  `order_account_id` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '下单成功使用的账号ID（发起私信时严格使用该账号）',
  `order_status` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '下单结果：success/failed/duplicate',
  `order_fail_reason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '下单失败原因',
  `order_attempts` int NOT NULL DEFAULT '0' COMMENT '下单尝试次数（失败重试用）',
  `dm_sent_at` datetime DEFAULT NULL COMMENT '实际私信成功/发起时间（用于按日统计私信数）',
  `ordered_at` datetime DEFAULT NULL COMMENT '下单成功时间（用于按日统计下单数）',
  `last_seen_at` datetime DEFAULT NULL COMMENT '最近一次采集到的时间',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_lmi_task_item` (`monitor_task_id`,`item_id`),
  KEY `idx_lmi_task` (`monitor_task_id`),
  KEY `idx_lmi_owner` (`owner_id`),
  KEY `idx_lmi_publish_time` (`publish_time`),
  KEY `idx_lmi_created` (`created_at`),
  KEY `idx_lmi_dm_send` (`order_status`,`is_dm_sent`,`ordered_at`),
  KEY `idx_lmi_order_pending` (`is_ordered`,`order_attempts`),
  KEY `idx_lmi_item_ordered` (`item_id`,`is_ordered`),
  KEY `idx_lmi_owner_publish` (`owner_id`,`publish_time`),
  KEY `idx_lmi_owner_order_pending` (`owner_id`,`is_ordered`,`created_at`,`order_attempts`),
  KEY `idx_lmi_owner_task_created` (`owner_id`,`monitor_task_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品监控采集商品信息表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_listing_monitor_logs`
--

DROP TABLE IF EXISTS `xy_listing_monitor_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_listing_monitor_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `monitor_task_id` bigint NOT NULL COMMENT '关联的商品监控任务ID',
  `owner_id` bigint DEFAULT NULL COMMENT '归属用户ID',
  `monitor_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '监控类型：listing-上新监控，price_drop-降价监控',
  `keyword` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '监控关键字',
  `trigger_type` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'auto' COMMENT '触发方式：auto-定时自动，manual-手动',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '本次实际使用的主账号ID',
  `used_account_ids` json DEFAULT NULL COMMENT '本次执行实际使用过的账号ID列表（可能多个）',
  `pages` int NOT NULL DEFAULT '0' COMMENT '本次采集页数',
  `fetched_count` int NOT NULL DEFAULT '0' COMMENT '本次获取的商品数',
  `inserted_count` int NOT NULL DEFAULT '0' COMMENT '本次新增的商品数',
  `updated_count` int NOT NULL DEFAULT '0' COMMENT '本次更新的商品数',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'success' COMMENT '执行状态：success/failed/partial',
  `message` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '执行结果说明',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_lml_task` (`monitor_task_id`),
  KEY `idx_lml_owner` (`owner_id`),
  KEY `idx_lml_created_at` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=104 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品监控执行日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_listing_monitor_tasks`
--

DROP TABLE IF EXISTS `xy_listing_monitor_tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_listing_monitor_tasks` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint DEFAULT NULL COMMENT '归属用户ID，用于多用户数据隔离',
  `category_id` bigint DEFAULT NULL COMMENT '所属分类ID（NULL=未分类）',
  `monitor_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'listing' COMMENT '监控类型：listing-上新监控，price_drop-降价监控',
  `keyword` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '商品监控关键字',
  `price_min` decimal(12,2) DEFAULT NULL COMMENT '商品价格区间最低值',
  `price_max` decimal(12,2) DEFAULT NULL COMMENT '商品价格区间最高值',
  `publish_days` int DEFAULT NULL COMMENT '上新天数筛选（searchFilter 的 publishDays，单位天，NULL/0=不限）',
  `interval_minutes` int NOT NULL DEFAULT '5' COMMENT '任务执行间隔（分钟）',
  `collect_pages` int NOT NULL DEFAULT '1' COMMENT '每次采集页数',
  `proxy_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '代理API地址（GET返回IP:PORT列表，取一个作HTTP代理；空=不使用代理）',
  `account_ids` json DEFAULT NULL COMMENT '关联的闲鱼账号ID列表（JSON数组）',
  `order_account_ids` json DEFAULT NULL COMMENT '下单账号ID列表（多选，私信与下单共用）',
  `dm_content` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '私信内容（配置下单账号后必填）',
  `dm_batch_size` int NOT NULL DEFAULT '5' COMMENT '每次定时私信任务最多处理条数',
  `order_batch_size` int NOT NULL DEFAULT '5' COMMENT '每次定时下单任务最多处理条数',
  `direct_order` tinyint(1) NOT NULL DEFAULT '0' COMMENT '采集后是否直接下单（开启则新采集商品立即用下单账号下单后再入库）',
  `is_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否启用监控任务',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已删除（软删除）',
  `last_run_at` datetime DEFAULT NULL COMMENT '最近一次执行时间',
  `created_by` bigint DEFAULT NULL COMMENT '创建人用户ID',
  `remark` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_lmt_owner_enabled` (`owner_id`,`is_enabled`),
  KEY `idx_lmt_owner_deleted` (`owner_id`,`is_deleted`),
  KEY `idx_lmt_created_at` (`created_at`),
  KEY `idx_lmt_category` (`category_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品上新监控任务表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_message_filters`
--

DROP TABLE IF EXISTS `xy_message_filters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_message_filters` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '规则ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号标识',
  `keyword` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '过滤关键词',
  `filter_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '过滤类型',
  `enabled` tinyint(1) DEFAULT '1' COMMENT '是否启用',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_keyword_type` (`account_id`,`keyword`,`filter_type`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_keyword` (`keyword`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='消息过滤规则表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_message_notifications`
--

DROP TABLE IF EXISTS `xy_message_notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_message_notifications` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '通知ID',
  `owner_id` bigint NOT NULL COMMENT '所属用户ID',
  `account_pk` bigint NOT NULL COMMENT '关联账号ID',
  `account_identifier` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号标识',
  `channel_id` bigint NOT NULL COMMENT '渠道ID',
  `enabled` tinyint(1) DEFAULT '1' COMMENT '是否启用',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_owner_id` (`owner_id`),
  KEY `idx_account_pk` (`account_pk`),
  KEY `idx_channel_id` (`channel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='消息通知表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_notification_channels`
--

DROP TABLE IF EXISTS `xy_notification_channels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_notification_channels` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '渠道ID',
  `owner_id` bigint NOT NULL COMMENT '所属用户ID',
  `name` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '渠道名称',
  `channel_type` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '渠道类型',
  `config` json DEFAULT NULL COMMENT '渠道配置',
  `enabled` tinyint(1) DEFAULT '1' COMMENT '是否启用',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_owner_id` (`owner_id`),
  KEY `idx_channel_type` (`channel_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知渠道表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_order_fallback_accounts`
--

DROP TABLE IF EXISTS `xy_order_fallback_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_order_fallback_accounts` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint NOT NULL COMMENT '归属用户ID',
  `category_id` bigint DEFAULT NULL COMMENT '所属分类ID（NULL=未分类全局兜底）',
  `account_ids` json DEFAULT NULL COMMENT '兜底下单账号ID列表（JSON数组，多选轮换使用）',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已删除（软删除）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ofa_owner_category` (`owner_id`,`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户级兜底下单账号配置表（按分类配置）';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_orders`
--

DROP TABLE IF EXISTS `xy_orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_orders` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '订单ID',
  `owner_id` bigint NOT NULL COMMENT '所属用户ID',
  `order_no` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '订单号',
  `status` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '订单状态',
  `buyer_nick` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '买家昵称',
  `buyer_fish_nick` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '买家闲鱼昵称（明文）',
  `buyer_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '买家ID',
  `chat_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '聊天会话ID',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品ID',
  `spec_name` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '规格名称',
  `spec_value` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '规格值',
  `quantity` int DEFAULT '1' COMMENT '数量',
  `amount` decimal(12,2) DEFAULT NULL COMMENT '金额',
  `currency` varchar(8) COLLATE utf8mb4_unicode_ci DEFAULT 'CNY' COMMENT '货币',
  `account_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '账号标识',
  `account_name` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '账号名称',
  `is_bargain` tinyint(1) DEFAULT '0' COMMENT '是否小刀',
  `receiver_name` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '收货人姓名',
  `receiver_phone` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '收货人手机号',
  `receiver_address` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '收货地址',
  `is_rated` tinyint(1) DEFAULT '0' COMMENT '是否已评价',
  `is_red_flower` tinyint(1) DEFAULT '0' COMMENT '是否已求小红花',
  `is_unregistered` tinyint(1) DEFAULT '0' COMMENT '是否已请求注销接口',
  `unregister_error_reason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '注销接口错误原因',
  `delivery_method` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '发货方式',
  `delivery_content` varchar(2000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '发货内容',
  `delivery_fail_reason` varchar(2000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '发货失败原因',
  `card_only_delivered` tinyint(1) NOT NULL DEFAULT '0' COMMENT '仅发卡券流程是否已处理',
  `agree_deliver_agreed` tinyint(1) NOT NULL DEFAULT '0' COMMENT '同意后发货-买家是否已点击同意',
  `agree_deliver_agreed_at` datetime DEFAULT NULL COMMENT '同意后发货-买家点击同意时间',
  `item_snapshot` json DEFAULT NULL COMMENT '商品快照',
  `metadata` json DEFAULT NULL COMMENT '元数据',
  `source` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '数据来源：fetch_xianyu-获取闲鱼订单按钮',
  `placed_at` datetime DEFAULT NULL COMMENT '下单时间',
  `synced_at` datetime DEFAULT NULL COMMENT '同步时间',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_account_no` (`account_id`,`order_no`),
  KEY `idx_owner_id` (`owner_id`),
  KEY `idx_order_no` (`order_no`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_order_created_at` (`created_at`),
  KEY `idx_order_placed_status` (`placed_at`,`status`),
  KEY `idx_order_created_status` (`created_at`,`status`),
  KEY `idx_order_owner_placed` (`owner_id`,`placed_at`),
  KEY `idx_order_owner_created` (`owner_id`,`created_at`),
  KEY `idx_order_owner_account_placed` (`owner_id`,`account_id`,`placed_at`),
  KEY `idx_order_owner_account_buyer_created` (`owner_id`,`account_id`,`buyer_id`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=26 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_personal_blacklist`
--

DROP TABLE IF EXISTS `xy_personal_blacklist`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_personal_blacklist` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint NOT NULL COMMENT '用户ID',
  `account_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '账号ID',
  `buyer_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '买家ID',
  `buyer_nick` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '买家昵称',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品ID',
  `reason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '拉黑原因',
  `is_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否启用',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_pb_owner_id` (`owner_id`),
  KEY `idx_pb_owner_buyer` (`owner_id`,`buyer_id`),
  KEY `idx_pb_owner_account` (`owner_id`,`account_id`),
  KEY `idx_pb_owner_created` (`owner_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='个人黑名单表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_platform_blacklist`
--

DROP TABLE IF EXISTS `xy_platform_blacklist`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_platform_blacklist` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint NOT NULL COMMENT '拉黑用户（本系统用户ID）',
  `buyer_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '买家ID',
  `buyer_nick` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '买家昵称',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_plb_owner_id` (`owner_id`),
  KEY `idx_plb_owner_buyer` (`owner_id`,`buyer_id`),
  KEY `idx_plb_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='闲鱼黑名单表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_popup_announcements`
--

DROP TABLE IF EXISTS `xy_popup_announcements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_popup_announcements` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '弹窗公告ID',
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '公告标题',
  `content` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '公告内容',
  `link` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '跳转链接',
  `is_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否启用',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已删除',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='弹窗公告表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_product_materials`
--

DROP TABLE IF EXISTS `xy_product_materials`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_product_materials` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '所属用户ID',
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '商品标题',
  `description` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '商品描述',
  `price` decimal(12,2) NOT NULL COMMENT '价格',
  `original_price` decimal(12,2) DEFAULT NULL COMMENT '原价（划线价）',
  `category` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '商品分类',
  `platform_category_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '平台末级分类ID（catId）',
  `platform_category_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '平台末级分类名称（catName）',
  `platform_channel_category_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '平台频道分类ID（channelCatId）',
  `platform_channel_category_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '平台频道分类名称（channelCatName）',
  `platform_leaf_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '平台叶子分类ID（leafId）',
  `platform_tb_category_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '淘宝分类ID（tbCatId）',
  `platform_category_path` json DEFAULT NULL COMMENT '平台多级分类路径（各级ID和名称）',
  `platform_attributes` json DEFAULT NULL COMMENT '平台属性标签列表（itemLabelExtList）',
  `category_source` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'manual' COMMENT '分类来源：manual-手动，recommendation-推荐',
  `category_confidence` decimal(8,6) DEFAULT NULL COMMENT '分类推荐置信度',
  `images` json DEFAULT NULL COMMENT '图片URL列表（最多9张）',
  `videos` json DEFAULT NULL COMMENT '视频素材列表（URL、文件ID、尺寸等）',
  `specifications` json DEFAULT NULL COMMENT '商品规格列表',
  `sku_rows` json DEFAULT NULL COMMENT '规格组合价格和库存列表',
  `quantity` int NOT NULL DEFAULT '1' COMMENT '发布数量',
  `delivery_method` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'express' COMMENT '发货方式：express-快递, pickup-自提',
  `shipping_method` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'free' COMMENT '运费方式：free/distance/fixed/template/none',
  `support_pickup` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否支持自提',
  `postage` decimal(8,2) DEFAULT '0.00' COMMENT '邮费，0表示包邮',
  `address` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '宝贝所在地',
  `address_expected_text` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '所在地选择时的期望文本',
  `brand` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '品牌',
  `condition` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT '全新' COMMENT '成色',
  `remark` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注（仅内部使用）',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已删除（软删除）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_pm_user_created` (`user_id`,`created_at`),
  KEY `idx_pm_platform_category` (`platform_category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品素材库表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_publish_addresses`
--

DROP TABLE IF EXISTS `xy_publish_addresses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_publish_addresses` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `name` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '地址名称',
  `search_keyword` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '地址搜索关键词',
  `expected_text` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '期望命中的候选文本',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '限定使用的闲鱼账号ID，空表示全局通用',
  `weight` int NOT NULL DEFAULT '1' COMMENT '随机权重',
  `sort_order` int NOT NULL DEFAULT '100' COMMENT '排序值',
  `is_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否启用',
  `use_count` int NOT NULL DEFAULT '0' COMMENT '使用次数',
  `last_used_at` datetime DEFAULT NULL COMMENT '最后使用时间',
  `created_by` bigint DEFAULT NULL COMMENT '创建人用户ID',
  `remark` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_pa_enabled_account` (`is_enabled`,`account_id`),
  KEY `idx_pa_sort_created` (`sort_order`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=156 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品发布随机地址池表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_publish_logs`
--

DROP TABLE IF EXISTS `xy_publish_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_publish_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '操作用户ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '闲鱼账号ID（cookie_id）',
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '商品标题',
  `description` text COLLATE utf8mb4_unicode_ci COMMENT '商品描述',
  `price` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '发布价格',
  `material_id` bigint DEFAULT NULL COMMENT '关联的素材ID（批量发布时使用）',
  `batch_id` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '批次ID（批量发布任务标识）',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending' COMMENT '状态：pending/publishing/success/failed',
  `item_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '发布成功后的商品链接',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '发布成功后的商品ID',
  `error_message` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '失败原因',
  `resolved_address_id` bigint DEFAULT NULL COMMENT '本次发布命中的地址池ID',
  `resolved_address_text` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '本次发布实际使用的地址搜索词',
  `address_source` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '地址来源：material/account_pool/global_pool',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_publish_user_created` (`user_id`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品发布日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_recharge_orders`
--

DROP TABLE IF EXISTS `xy_recharge_orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_recharge_orders` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `order_no` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '充值订单号',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `amount` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '充值金额',
  `order_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'recharge' COMMENT '订单类型：recharge-余额充值，ad-广告申请付款',
  `status` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending' COMMENT '订单状态：pending-待支付，paid-已支付，expired-已过期，failed-失败',
  `trade_no` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '支付宝交易号',
  `qr_code` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '支付二维码内容',
  `paid_at` datetime DEFAULT NULL COMMENT '支付时间',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_order_no` (`order_no`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='充值订单表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_risk_control_logs`
--

DROP TABLE IF EXISTS `xy_risk_control_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_risk_control_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '日志ID',
  `owner_id` bigint DEFAULT NULL COMMENT '所属用户ID',
  `account_id` bigint DEFAULT NULL COMMENT '关联账号ID',
  `account_identifier` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '账号标识',
  `event_type` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT 'slider_captcha' COMMENT '事件类型',
  `event_description` text COLLATE utf8mb4_unicode_ci COMMENT '事件描述',
  `processing_result` text COLLATE utf8mb4_unicode_ci COMMENT '处理结果',
  `processing_status` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT 'processing' COMMENT '处理状态',
  `captcha_engine` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '验证通过引擎：playwright-主引擎/drissionpage-兜底引擎/real_mouse-真人鼠标引擎',
  `call_type` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT 'local' COMMENT '调用类型：local-本机/remote-远程(外部凭秘钥调用)',
  `call_user` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '调用用户：仅远程调用记录(按秘钥查到的用户名)',
  `error_message` text COLLATE utf8mb4_unicode_ci COMMENT '错误信息',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_owner_id` (`owner_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_event_type` (`event_type`),
  KEY `idx_rcl_account_status` (`account_id`,`processing_status`),
  KEY `idx_rcl_identifier_status_created` (`account_identifier`,`processing_status`,`created_at`),
  KEY `idx_rcl_status_event` (`processing_status`,`event_type`),
  KEY `idx_rcl_owner_created` (`owner_id`,`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='风控日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_scheduled_api_cookie_renew_log`
--

DROP TABLE IF EXISTS `xy_scheduled_api_cookie_renew_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_scheduled_api_cookie_renew_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `batch_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '批次ID，标识一次定时任务执行',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '状态：success/cookie_updated/browser_renewed/need_password_login/failed',
  `updated_cookie_count` int NOT NULL DEFAULT '0' COMMENT '本次更新的Cookie字段数量',
  `updated_cookie_names` text COLLATE utf8mb4_unicode_ci COMMENT '本次更新的Cookie字段名列表（逗号分隔）',
  `response_content` text COLLATE utf8mb4_unicode_ci COMMENT '接口返回内容（用于失败排查），最大裁剪到2000字符',
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '错误信息或处理说明',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=65 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='接口续期Cookies执行日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_scheduled_close_notice_log`
--

DROP TABLE IF EXISTS `xy_scheduled_close_notice_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_scheduled_close_notice_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `batch_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '批次ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '状态：success/failed',
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '错误信息',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账号消息通知关闭执行日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_scheduled_cookies_refresh_log`
--

DROP TABLE IF EXISTS `xy_scheduled_cookies_refresh_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_scheduled_cookies_refresh_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `batch_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '批次ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '状态：initialized/success/failed',
  `updated_cookie_count` int NOT NULL DEFAULT '0' COMMENT '本次增量更新的Cookie字段数量',
  `next_expire_at` datetime DEFAULT NULL COMMENT '下次到期时间',
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '错误信息或处理说明',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='COOKIES刷新日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_scheduled_login_renew_log`
--

DROP TABLE IF EXISTS `xy_scheduled_login_renew_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_scheduled_login_renew_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `batch_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '批次ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '状态：success/token_refreshed/session_expired/failed',
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '错误信息或处理说明',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='登录续期执行日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_scheduled_polish_log`
--

DROP TABLE IF EXISTS `xy_scheduled_polish_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_scheduled_polish_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `batch_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '批次ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `item_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '商品ID',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '状态',
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '错误信息',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_spol_created_batch` (`created_at`,`batch_id`),
  KEY `idx_spol_batch_created_status` (`batch_id`,`created_at`,`status`)
) ENGINE=InnoDB AUTO_INCREMENT=48 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='定时擦亮执行日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_scheduled_rate_log`
--

DROP TABLE IF EXISTS `xy_scheduled_rate_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_scheduled_rate_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `batch_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '批次ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `order_no` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '订单号',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '状态',
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '错误信息',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_srate_created_batch` (`created_at`,`batch_id`),
  KEY `idx_srate_batch_created_status` (`batch_id`,`created_at`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='定时补评价执行日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_scheduled_red_flower_log`
--

DROP TABLE IF EXISTS `xy_scheduled_red_flower_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_scheduled_red_flower_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `batch_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '批次ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `order_no` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '订单号',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '状态：success/failed',
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '错误信息',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_srf_created_batch` (`created_at`,`batch_id`),
  KEY `idx_srf_batch_created_status` (`batch_id`,`created_at`,`status`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='定时求小红花执行日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_scheduled_redelivery_log`
--

DROP TABLE IF EXISTS `xy_scheduled_redelivery_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_scheduled_redelivery_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `batch_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '批次ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `order_no` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '订单号',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '状态',
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '错误信息',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_srl_created_batch` (`created_at`,`batch_id`),
  KEY `idx_srl_batch_created_status` (`batch_id`,`created_at`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='定时补发货执行日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_scheduled_tasks`
--

DROP TABLE IF EXISTS `xy_scheduled_tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_scheduled_tasks` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `task_code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '任务代码',
  `task_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '任务名称',
  `interval_seconds` int NOT NULL DEFAULT '60' COMMENT '执行间隔(秒)',
  `enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT '是否启用',
  `description` text COLLATE utf8mb4_unicode_ci COMMENT '任务描述',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_code` (`task_code`)
) ENGINE=InnoDB AUTO_INCREMENT=599 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='定时任务配置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_scheduled_token_renewal_log`
--

DROP TABLE IF EXISTS `xy_scheduled_token_renewal_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_scheduled_token_renewal_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `batch_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '批次ID',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '账号ID',
  `token_user_id` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Token缓存用户ID（myid）',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '状态：success/failed',
  `renew_expire_at` datetime DEFAULT NULL COMMENT '续期Token到期时间',
  `error_message` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '执行结果说明或错误信息',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_batch_id` (`batch_id`),
  KEY `idx_account_id` (`account_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_strl_created_batch` (`created_at`,`batch_id`),
  KEY `idx_strl_batch_created_status` (`batch_id`,`created_at`,`status`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Token续期执行日志表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_settlement_records`
--

DROP TABLE IF EXISTS `xy_settlement_records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_settlement_records` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `alipay_id` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '支付宝ID',
  `payment_type` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '收款方式：alipay-支付宝，wechat-微信',
  `payment_qrcode` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '收款码图片路径',
  `amount` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '提现金额',
  `status` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending_review' COMMENT '状态：pending_review-待审核，approved-已通过，rejected-已拒绝，paid-已打款',
  `remark` text COLLATE utf8mb4_unicode_ci COMMENT '备注',
  `reject_reason` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '拒绝原因',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_sr_user_created_id` (`user_id`,`created_at`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='结算记录表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_shared_scan_sessions`
--

DROP TABLE IF EXISTS `xy_shared_scan_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_shared_scan_sessions` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `session_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '会话唯一ID（UUID）',
  `owner_id` bigint NOT NULL COMMENT '创建者用户ID',
  `owner_username` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '创建者用户名',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active' COMMENT '会话状态：active/closed',
  `expires_at` datetime NOT NULL COMMENT '过期时间（默认72小时）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `session_id` (`session_id`),
  KEY `idx_session_id` (`session_id`),
  KEY `idx_owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='共享扫码登录会话表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_shared_scan_workers`
--

DROP TABLE IF EXISTS `xy_shared_scan_workers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_shared_scan_workers` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `shared_session_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '关联的共享会话ID',
  `sub_session_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '兼职子会话唯一ID（UUID）',
  `xianyu_session_id` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '关联的闲鱼QR登录会话ID',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'qrcode_ready' COMMENT '状态：qrcode_ready/scanning/success/failed',
  `qr_code_url` longtext COLLATE utf8mb4_unicode_ci COMMENT '二维码图片base64 data URL',
  `account_id` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '扫码成功后的闲鱼账号ID（unb）',
  `cookie_saved` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Cookie是否已保存到账号表',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `sub_session_id` (`sub_session_id`),
  KEY `idx_shared_session_id` (`shared_session_id`),
  KEY `idx_sub_session_id` (`sub_session_id`),
  KEY `idx_account_id` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='共享扫码登录兼职工作者表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_system_settings`
--

DROP TABLE IF EXISTS `xy_system_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_system_settings` (
  `key` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '设置键',
  `value` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '设置值',
  `description` text COLLATE utf8mb4_unicode_ci COMMENT '设置描述',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统设置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_token_cache`
--

DROP TABLE IF EXISTS `xy_token_cache`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_token_cache` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '用户ID（myid）',
  `token` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'IM Token',
  `device_id` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '设备ID',
  `expire_at` datetime NOT NULL COMMENT '过期时间',
  `renew_expire_at` datetime DEFAULT NULL COMMENT '续期Token过期时间',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_id` (`user_id`),
  KEY `idx_token_cache_expiries` (`expire_at`,`renew_expire_at`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Token缓存表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_user_publish_addresses`
--

DROP TABLE IF EXISTS `xy_user_publish_addresses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_user_publish_addresses` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `owner_id` bigint NOT NULL COMMENT '归属用户ID',
  `address` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '地址文本（去重键）',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否已删除（软删除）',
  `use_count` int NOT NULL DEFAULT '0' COMMENT '使用次数',
  `last_used_at` datetime DEFAULT NULL COMMENT '最后使用时间',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_upa_owner_deleted` (`owner_id`,`is_deleted`),
  KEY `idx_upa_owner_addr` (`owner_id`,`address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='个人发布地址库表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_user_settings`
--

DROP TABLE IF EXISTS `xy_user_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_user_settings` (
  `id` int NOT NULL AUTO_INCREMENT COMMENT '设置ID',
  `user_id` int NOT NULL COMMENT '用户ID',
  `key` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '设置键',
  `value` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '设置值',
  `description` text COLLATE utf8mb4_unicode_ci COMMENT '设置描述',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_key` (`user_id`,`key`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户设置表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `xy_users`
--

DROP TABLE IF EXISTS `xy_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `xy_users` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `external_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '外部ID',
  `username` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '用户名',
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '邮箱',
  `phone` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '手机号',
  `password_hash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '密码哈希',
  `status` enum('ACTIVE','INACTIVE','SUSPENDED','DELETED') COLLATE utf8mb4_unicode_ci DEFAULT 'ACTIVE' COMMENT '用户状态',
  `role` enum('ADMIN','OPERATOR','MEMBER') COLLATE utf8mb4_unicode_ci DEFAULT 'MEMBER' COMMENT '用户角色',
  `account_limit` int DEFAULT NULL COMMENT '可添加账号数量',
  `last_login_at` datetime DEFAULT NULL COMMENT '最后登录时间',
  `login_fail_count` int DEFAULT '0' COMMENT '登录失败次数',
  `login_locked_until` datetime DEFAULT NULL COMMENT '登录锁定截止时间',
  `dock_code` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '对接码，用于分销商识别',
  `secret_key` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '分销秘钥，32位随机字符，全局唯一',
  `expire_at` datetime DEFAULT NULL COMMENT '账号到期日（精确到秒，NULL=永不过期）',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `dock_code` (`dock_code`),
  UNIQUE KEY `secret_key` (`secret_key`),
  KEY `idx_external_id` (`external_id`),
  KEY `idx_username` (`username`),
  KEY `idx_email` (`email`),
  KEY `idx_user_created` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'xianyu_data'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-09-14 13:45:50
