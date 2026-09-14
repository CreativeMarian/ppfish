#!/bin/bash
# ============================================================
# ppfish 一键部署脚本（Linux 原生 / 宝塔双模式）
#
# 支持系统:
#   CentOS 7/8/9、Rocky Linux、AlmaLinux（yum/dnf）
#   Ubuntu 20.04+、Debian 11+（apt）
#
# 部署内容:
#   1. 基础依赖（Python 3.11+ / Node 18+ / Nginx / MySQL / Redis / Xvfb）
#   2. 三个 Python 服务（backend-web:8089 / websocket:8090 / scheduler:8091）
#   3. 前端构建（npm build -> frontend/dist）
#   4. systemd 守护（ppfish-backend / ppfish-websocket / ppfish-scheduler / xvfb）
#   5. Nginx 站点（默认 9000 端口，含 /api 反代 + WebSocket 反代）
#   6. 防火墙放行 + 健康检查
#
# 用法:
#   bash linux-deploy.sh                          # 交互式
#   bash linux-deploy.sh --mode baota             # 指定宝塔模式
#   bash linux-deploy.sh --mode native            # 指定原生模式
#   bash linux-deploy.sh --src local              # 使用脚本所在目录(已在项目内)
#   bash linux-deploy.sh --src git                # 从 GitHub 拉取代码
#   bash linux-deploy.sh --db-pass xxx --redis-pass xxx \
#        --mf-key xxx --mf-secret xxx --recharge-url http://1.2.3.4:9000
#
# 参数说明:
#   --mode baota|native|auto      部署模式（默认 auto：自动检测宝塔）
#   --src local|git|auto          代码来源（默认 local：脚本所在目录即项目）
#   --project-dir <path>          项目目录（默认 /www/wwwroot/ppfish 或 /opt/ppfish）
#   --db-pass <pwd>               MySQL root 密码（留空自动生成）
#   --redis-pass <pwd>            Redis 密码（留空自动生成）
#   --mf-key <key>                蜜蜂汇云 APP_KEY
#   --mf-secret <sec>             蜜蜂汇云 APP_SECRET
#   --recharge-url <url>          充值页公网地址（买家访问，如 http://IP:9000）
#   --frontend-port <port>        Nginx 端口（默认 9000）
#   --backup-sql <path>           数据库备份文件（可选，导入已有数据）
#   --skip-build                  跳过前端构建（dist 已存在时）
#   --yes                        全部使用默认值/自动生成，不交互（配合参数使用）
# ============================================================

set -euo pipefail

# ---------- 颜色 ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info()  { echo -e "${CYAN}[信息]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[成功]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[提示]${NC} $*"; }
log_err()   { echo -e "${RED}[错误]${NC} $*"; }
die()       { log_err "$*"; exit 1; }

# ---------- 默认值 ----------
MODE="auto"                 # baota / native / auto
SRC="auto"                  # local / git / auto
PROJECT_DIR=""
DB_PASS=""
REDIS_PASS=""
MF_KEY=""
MF_SECRET=""
RECHARGE_URL=""
FRONTEND_PORT=9000
BACKUP_SQL=""
SKIP_BUILD=0
ASSUME_YES=0

# ---------- 解析参数 ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --src) SRC="$2"; shift 2 ;;
        --project-dir) PROJECT_DIR="$2"; shift 2 ;;
        --db-pass) DB_PASS="$2"; shift 2 ;;
        --redis-pass) REDIS_PASS="$2"; shift 2 ;;
        --mf-key) MF_KEY="$2"; shift 2 ;;
        --mf-secret) MF_SECRET="$2"; shift 2 ;;
        --recharge-url) RECHARGE_URL="$2"; shift 2 ;;
        --frontend-port) FRONTEND_PORT="$2"; shift 2 ;;
        --backup-sql) BACKUP_SQL="$2"; shift 2 ;;
        --skip-build) SKIP_BUILD=1; shift ;;
        --yes) ASSUME_YES=1; shift ;;
        -h|--help) grep -E '^#   ' "$0" | sed 's/^#   //'; exit 0 ;;
        *) die "未知参数: $1（用 --help 查看用法）" ;;
    esac
done

# ---------- 环境检测 ----------
[[ $EUID -eq 0 ]] || die "请用 root 运行：sudo bash $0"

OS_ID=""; OS_VERSION=""; PKG=""; OS_FAMILY=""
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="$ID"; OS_VERSION="$VERSION_ID"
fi
case "$OS_ID" in
    centos|rhel|rocky|almalinux|anolis|tencentos|openeuler)
        OS_FAMILY="rhel"
        if command -v dnf &>/dev/null; then PKG="dnf"; else PKG="yum"; fi
        ;;
    ubuntu|debian|kylin|uos)
        OS_FAMILY="debian"; PKG="apt-get"
        ;;
    *)
        die "暂不支持的系统: $OS_ID（支持 CentOS/Rocky/Alma、Ubuntu、Debian）"
        ;;
esac
log_info "系统: $OS_ID $OS_VERSION (包管理器: $PKG)"

# ---------- 硬件检查 ----------
MEM_MB=$(free -m 2>/dev/null | awk '/Mem:/{print $2}' || echo 0)
if [[ $MEM_MB -gt 0 && $MEM_MB -lt 3000 ]]; then
    log_warn "内存仅 ${MEM_MB}MB，建议 4GB+（Playwright 浏览器 + 4 个服务较吃内存）"
fi

# ---------- 工具函数 ----------
apt_install()  { DEBIAN_FRONTEND=noninteractive $PKG install -y "$@"; }
yum_install()  { $PKG install -y "$@"; }
pkg_install()  {
    if [[ "$OS_FAMILY" == "debian" ]]; then apt_install "$@";
    else yum_install "$@"; fi
}
svc_enable()   { systemctl enable "$1" 2>/dev/null || true; }
svc_start()    { systemctl start "$1" 2>/dev/null || true; }
svc_restart()  { systemctl restart "$1" 2>/dev/null || true; }

gen_password() { openssl rand -hex 10 2>/dev/null || echo "ppfish$(date +%s)"; }

ask() { # ask "提示" "默认值" -> 输出到 REPLY
    local prompt="$1" def="$2"
    if [[ $ASSUME_YES -eq 1 ]]; then
        REPLY="$def"; echo "$REPLY"; return
    fi
    if [[ -n "$def" ]]; then
        read -rp "$(echo -e "${CYAN}[输入]${NC} ${prompt}（默认: $def）: ")" REPLY
        REPLY="${REPLY:-$def}"
    else
        read -rp "$(echo -e "${CYAN}[输入]${NC} ${prompt}: ")" REPLY
    fi
    echo "$REPLY" >/dev/null
}

# ============================================================
# 1. 模式选择
# ============================================================
BAOTA_INSTALLED=0
if [[ -d /www/server/panel ]]; then BAOTA_INSTALLED=1; fi

if [[ "$MODE" == "auto" ]]; then
    if [[ $BAOTA_INSTALLED -eq 1 ]]; then
        log_info "检测到宝塔面板，默认使用宝塔模式"
        MODE="baota"
        if [[ $ASSUME_YES -eq 0 ]]; then
            ask "是否使用宝塔模式？[y/n]" "y"
            [[ "$REPLY" != "y" ]] && MODE="native"
        fi
    else
        MODE="native"
        log_info "未检测到宝塔，使用原生模式（脚本自动安装 MySQL/Redis/Nginx）"
    fi
fi
case "$MODE" in
    baota)   [[ $BAOTA_INSTALLED -eq 1 ]] || die "选择宝塔模式但未检测到宝塔面板（/www/server/panel 不存在）" ;;
    native)  ;;
    *)       die "无效模式: $MODE（baota / native / auto）" ;;
esac
log_ok "部署模式: ${MODE}"

# ============================================================
# 2. 项目目录与代码来源
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -z "$PROJECT_DIR" ]]; then
    PROJECT_DIR="/www/wwwroot/ppfish"
    [[ "$MODE" == "native" ]] && PROJECT_DIR="/opt/ppfish"
fi

if [[ "$SRC" == "auto" ]]; then
    if [[ -f "$SCRIPT_DIR/backend-web/main.py" && -f "$SCRIPT_DIR/frontend/package.json" ]]; then
        SRC="local"
        log_info "检测到脚本位于项目目录内（$SCRIPT_DIR），使用本地代码"
    else
        SRC="git"
    fi
fi

case "$SRC" in
    local)
        if [[ ! -f "$SCRIPT_DIR/backend-web/main.py" || ! -f "$SCRIPT_DIR/frontend/package.json" ]]; then
            die "本地模式要求脚本放在项目根目录（含 backend-web/、frontend/、websocket/、scheduler/、common/）"
        fi
        PROJECT_DIR="$SCRIPT_DIR"
        ;;
    git)
        if [[ ! -d "$PROJECT_DIR" ]]; then
            log_info "从 GitHub 拉取代码到 $PROJECT_DIR ..."
            mkdir -p "$(dirname "$PROJECT_DIR")"
            git clone --depth 1 https://github.com/CreativeMarian/ppfish.git "$PROJECT_DIR" \
                || die "GitHub 克隆失败（国内网络可先手动上传代码包到 $PROJECT_DIR 再运行 --src local）"
        else
            log_info "项目目录已存在: $PROJECT_DIR（跳过克隆）"
        fi
        ;;
    *) die "无效代码来源: $SRC（local / git / auto）" ;;
esac
cd "$PROJECT_DIR"
log_ok "项目目录: $PROJECT_DIR"

# ============================================================
# 3. 安装基础依赖
# ============================================================
install_base_pkgs() {
    log_info "安装基础依赖（git curl wget tar unzip xvfb ...）..."
    if [[ "$OS_FAMILY" == "debian" ]]; then
        apt_install curl wget git tar unzip xz-utils openssl ca-certificates xvfb cron
        apt_install python3 python3-pip python3-venv
        apt_install nginx redis-server
        apt_install mysql-server || apt_install mariadb-server || log_warn "MySQL/MariaDB 安装失败，请手动安装后重试"
    else
        yum_install curl wget git tar unzip xz openssl ca-certificates xorg-x11-server-Xvfb cronie
        if [[ "$PKG" == "dnf" ]]; then
            yum_install python3 python3-pip python3-devel
            yum_install nginx redis
            yum_install mysql-server || yum_install mariadb-server || log_warn "MySQL/MariaDB 安装失败，请手动安装后重试"
        else
            # CentOS 7：需要 EPEL 才有 redis/nginx
            yum install -y epel-release || true
            yum_install python3 python3-pip python3-devel
            yum_install nginx redis
            yum_install mariadb-server || log_warn "MariaDB 安装失败，请手动安装后重试"
        fi
    fi
    log_ok "基础依赖安装完成"
}

# Python 3.11+ 检查（项目 requires-python >= 3.11）
ensure_python() {
    local py=""
    for c in python3.12 python3.11 python3.10 python3; do
        if command -v "$c" &>/dev/null; then py="$c"; break; fi
    done
    [[ -z "$py" ]] && die "未找到 python3"
    local ver=$("$py" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || echo "0")
    local maj=${ver%%.*}; local min=${ver#*.}; min=${min%%.*}
    if (( maj > 3 || (maj == 3 && min >= 11) )); then
        PYTHON_BIN="$py"
        log_ok "Python: $("$PYTHON_BIN" --version)"
        return
    fi
    # 版本不足，尝试安装 3.11+
    log_warn "当前 Python 为 $ver，项目需要 3.11+，尝试安装..."
    if [[ "$OS_FAMILY" == "debian" ]]; then
        if command -v add-apt-repository &>/dev/null; then
            add-apt-repository -y ppa:deadsnakes/ppa >/dev/null 2>&1 || true
            apt-get update -y >/dev/null 2>&1 || true
        fi
        apt_install python3.11 python3.11-venv python3.11-dev || true
        if command -v python3.11 &>/dev/null; then PYTHON_BIN="python3.11"; fi
    else
        if [[ "$PKG" == "dnf" ]]; then
            $PKG install -y python3.11 python3.11-pip python3.11-devel 2>/dev/null || true
            if command -v python3.11 &>/dev/null; then PYTHON_BIN="python3.11"; fi
        fi
    fi
    if [[ -z "${PYTHON_BIN:-}" || ! -x "$(command -v $PYTHON_BIN 2>/dev/null)" ]]; then
        die "Python 3.11+ 安装失败。请手动安装 Python 3.11+ 后重新运行（Ubuntu: ppa:deadsnakes；CentOS: dnf install python3.11）"
    fi
    log_ok "Python: $("$PYTHON_BIN" --version)"
}
PYTHON_BIN=""

# Node 18+ 检查（前端构建用）
ensure_node() {
    if command -v node &>/dev/null; then
        local nver=$(node -v 2>/dev/null | tr -d 'v')
        local nmaj=${nver%%.*}
        if (( nmaj >= 18 )); then
            log_ok "Node: $(node -v)"
            return
        fi
        log_warn "Node 版本过低 ($(node -v))，需要 18+，升级中..."
    fi
    if [[ "$OS_FAMILY" == "debian" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1 || true
        apt_install nodejs || true
    else
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - >/dev/null 2>&1 || true
        $PKG install -y nodejs || true
    fi
    command -v node &>/dev/null || die "Node.js 安装失败，请手动安装 Node 18+"
    log_ok "Node: $(node -v)"
}

# ============================================================
# 4. 数据库/Redis/Nginx 就绪（按模式）
# ============================================================
MYSQL_SERVICE="mysqld"; REDIS_SERVICE="redis"; NGINX_SERVICE="nginx"
[[ "$OS_FAMILY" == "debian" ]] && MYSQL_SERVICE="mysql"

detect_services() {
    # 根据实际 systemd 服务名修正
    for s in mysqld mysql mariadb; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${s}\.service"; then MYSQL_SERVICE="$s"; break; fi
    done
    for s in redis redis-server; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${s}\.service"; then REDIS_SERVICE="$s"; break; fi
    done
    log_info "服务名: MySQL=$MYSQL_SERVICE Redis=$REDIS_SERVICE Nginx=$NGINX_SERVICE"
}

ensure_mysql() {
    if [[ "$MODE" == "baota" ]]; then
        # 宝塔：MySQL 应已安装，检测端口
        log_info "检测宝塔 MySQL ..."
        if [[ -z "$DB_PASS" ]]; then
            if [[ $ASSUME_YES -eq 0 ]]; then
                ask "请输入宝塔 MySQL root 密码" ""
                DB_PASS="$REPLY"
            fi
            [[ -n "$DB_PASS" ]] || die "宝塔模式必须提供 MySQL root 密码（--db-pass 或交互输入）"
        fi
        if ! systemctl is-active "$MYSQL_SERVICE" &>/dev/null; then
            systemctl start "$MYSQL_SERVICE" 2>/dev/null || true
        fi
        for i in $(seq 1 30); do
            mysqladmin ping --silent 2>/dev/null && break
            sleep 2
        done
        mysqladmin ping --silent 2>/dev/null || die "宝塔 MySQL 未运行，请先在宝塔面板安装/启动 MySQL"
        mysql -uroot -p"$DB_PASS" -e "SELECT 1" &>/dev/null || die "MySQL root 密码验证失败，请确认密码正确"
        log_ok "宝塔 MySQL 运行中"
    else
        log_info "启动并初始化 MySQL ..."
        svc_enable "$MYSQL_SERVICE"; svc_start "$MYSQL_SERVICE"
        for i in $(seq 1 60); do
            mysqladmin ping --silent 2>/dev/null && break
            sleep 2
        done
        mysqladmin ping --silent 2>/dev/null || die "MySQL 启动失败，查看: journalctl -u $MYSQL_SERVICE -n 50"
        # 设置 root 密码（首次）
        if [[ -z "$DB_PASS" ]]; then DB_PASS="$(gen_password)"; log_warn "已自动生成 MySQL root 密码: $DB_PASS（请务必记录）"; fi
        if mysql -uroot -p"$DB_PASS" -e "SELECT 1" &>/dev/null; then
            log_ok "MySQL root 密码已生效"
        elif mysql -uroot -e "SELECT 1" &>/dev/null; then
            mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${DB_PASS}'; FLUSH PRIVILEGES;" 2>/dev/null \
                || mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASS}'; FLUSH PRIVILEGES;" 2>/dev/null \
                || mysql -uroot -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${DB_PASS}'); FLUSH PRIVILEGES;"
            # 允许本地 TCP 登录（部分发行版 root 默认仅 socket）
            mysql -uroot -p"$DB_PASS" -e "CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>/dev/null || true
            log_ok "MySQL root 密码已设置"
        else
            # 需要用户提供密码（非交互模式无法免密登录时）
            if [[ $ASSUME_YES -eq 0 ]]; then
                ask "MySQL 当前无法免密登录。请输入 MySQL root 密码" ""
                DB_PASS="$REPLY"
                [[ -n "$DB_PASS" ]] || die "未提供 MySQL root 密码"
            else
                die "MySQL 免密登录失败且未提供 --db-pass，无法继续"
            fi
        fi
    fi
    # 建库
    if [[ -z "$DB_PASS" && "$MODE" == "baota" ]]; then
        die "请通过 --db-pass 提供 MySQL root 密码（宝塔模式需要）"
    fi
    mysql -uroot -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS xianyu_data CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
        || die "创建数据库失败，请确认 MySQL root 密码正确"
    log_ok "数据库 xianyu_data 已就绪"
}

ensure_redis() {
    if [[ "$MODE" == "baota" ]]; then
        systemctl is-active "$REDIS_SERVICE" &>/dev/null || systemctl start "$REDIS_SERVICE" 2>/dev/null || true
        sleep 2
    else
        svc_enable "$REDIS_SERVICE"; svc_start "$REDIS_SERVICE"
    fi
    if [[ -z "$REDIS_PASS" ]]; then REDIS_PASS="$(gen_password)"; log_warn "已自动生成 Redis 密码: $REDIS_PASS（请务必记录）"; fi
    # 设置 requirepass
    local redis_conf=""
    [[ -f /etc/redis/redis.conf ]] && redis_conf="/etc/redis/redis.conf"
    [[ -f /etc/redis.conf ]] && redis_conf="/etc/redis.conf"
    [[ -f /www/server/redis/redis.conf ]] && redis_conf="/www/server/redis/redis.conf"
    [[ -z "$redis_conf" ]] && die "未找到 Redis 配置文件"
    if grep -q '^requirepass' "$redis_conf"; then
        sed -i "s/^requirepass.*/requirepass ${REDIS_PASS}/" "$redis_conf"
    else
        sed -i "s/^#\s*requirepass.*/requirepass ${REDIS_PASS}/" "$redis_conf"
        grep -q '^requirepass' "$redis_conf" || echo "requirepass ${REDIS_PASS}" >> "$redis_conf"
    fi
    svc_restart "$REDIS_SERVICE"
    sleep 2
    redis-cli -a "$REDIS_PASS" ping 2>/dev/null | grep -q PONG || die "Redis 密码设置失败"
    log_ok "Redis 密码已设置并验证通过"
}

ensure_nginx() {
    if [[ "$MODE" == "baota" ]]; then
        systemctl is-active nginx &>/dev/null || systemctl start nginx 2>/dev/null || true
    else
        svc_enable nginx; svc_start nginx
    fi
    log_ok "Nginx 就绪"
}

# ============================================================
# 5. 数据库备份导入（可选）
# ============================================================
import_backup() {
    [[ -z "$BACKUP_SQL" ]] && return
    [[ -f "$BACKUP_SQL" ]] || die "数据库备份文件不存在: $BACKUP_SQL"
    log_info "导入数据库备份 $BACKUP_SQL ..."
    mysql -uroot -p"$DB_PASS" xianyu_data < "$BACKUP_SQL" || die "导入数据库备份失败"
    log_ok "数据库备份导入完成"
}

# ============================================================
# 6. 生成 .env
# ============================================================
generate_env() {
    if [[ -f .env && $ASSUME_YES -eq 0 ]]; then
        ask "检测到已有 .env，是否覆盖重新生成？[y/n]" "n"
        [[ "$REPLY" != "y" ]] && { log_ok "保留现有 .env"; return; }
    fi
    if [[ -z "$MF_KEY" ]]; then
        ask "蜜蜂汇云 APP_KEY（MF_APP_KEY）" ""
        MF_KEY="$REPLY"
    fi
    if [[ -z "$MF_SECRET" ]]; then
        ask "蜜蜂汇云 APP_SECRET（MF_APP_SECRET）" ""
        MF_SECRET="$REPLY"
    fi
    if [[ -z "$RECHARGE_URL" ]]; then
        # 自动探测公网 IP
        local pub_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "你的服务器IP")
        ask "充值页公网地址（买家填手机号充值的链接，如 http://${pub_ip}:${FRONTEND_PORT}）" "http://${pub_ip}:${FRONTEND_PORT}"
        RECHARGE_URL="$REPLY"
    fi
    cat > .env << EOF
# ==========================================
# ppfish - 环境变量配置（由 linux-deploy.sh 生成）
# ==========================================
ENVIRONMENT=production
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=${DB_PASS}
MYSQL_DATABASE=xianyu_data
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASS}
REDIS_DB=0
CORS_ORIGINS=*
BACKEND_WEB_PORT=8089
WEBSOCKET_PORT=8090
SCHEDULER_PORT=8091
WEBSOCKET_SERVICE_URL=http://127.0.0.1:8090
SCHEDULER_SERVICE_URL=http://127.0.0.1:8091
BACKEND_WEB_SERVICE_URL=http://127.0.0.1:8089
STATIC_DIR=static
TZ=Asia/Shanghai

# 蜜蜂汇云 API 对接
MF_APP_KEY=${MF_KEY}
MF_APP_SECRET=${MF_SECRET}
MF_BASE_URL=https://merchant.task.mf178.cn

# 蜜蜂直充充值页公网地址（买家访问；证书到位后改为 https://你的域名）
MF_RECHARGE_BASE_URL=${RECHARGE_URL}

# 日志级别
LOG_LEVEL=INFO
SQL_ECHO=false
EOF
    chmod 600 .env
    log_ok ".env 已生成（包含数据库/Redis 密码，请妥善保管）"
}

# ============================================================
# 7. Python 虚拟环境 + 依赖
# ============================================================
PIP_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"

setup_venv() {
    local svc="$1"; shift
    log_info "安装 $svc Python 依赖 ..."
    cd "$PROJECT_DIR/$svc"
    "$PYTHON_BIN" -m venv .venv
    ./.venv/bin/pip install --upgrade pip -i "$PIP_INDEX" -q
    ./.venv/bin/pip install -e . -i "$PIP_INDEX" -q || die "$svc 依赖安装失败"
    # 公共补充依赖（bcrypt/passlib/jose 等）
    ./.venv/bin/pip install bcrypt passlib "python-jose[cryptography]" pycryptodome qrcode email-validator -i "$PIP_INDEX" -q || true
    cd "$PROJECT_DIR"
    log_ok "$svc 依赖安装完成"
}

# ============================================================
# 8. Playwright / Patchright 浏览器
# ============================================================
install_browsers() {
    log_info "安装 Playwright / Patchright 浏览器（需下载约 1-2GB，视带宽 5-30 分钟）..."
    # 浏览器装到系统默认缓存路径（~/.cache/ms-playwright），systemd 服务以 root 运行可共用
    export PLAYWRIGHT_DOWNLOAD_HOST="https://cdn.npmmirror.com/binaries/playwright"
    cd "$PROJECT_DIR/backend-web"
    ./.venv/bin/python -m playwright install chromium 2>/dev/null || log_warn "playwright 浏览器下载失败，可稍后手动重试"
    ./.venv/bin/python -m patchright install chromium 2>/dev/null || log_warn "patchright 浏览器下载失败，可稍后手动重试"
    ./.venv/bin/python -m playwright install-deps chromium >/dev/null 2>&1 || true
    ./.venv/bin/python -m patchright install-deps chromium >/dev/null 2>&1 || true
    cd "$PROJECT_DIR"
    log_ok "浏览器安装完成（或已提示手动重试项）"
}

# ============================================================
# 9. 前端构建
# ============================================================
build_frontend() {
    if [[ $SKIP_BUILD -eq 1 && -d frontend/dist && -f frontend/dist/index.html ]]; then
        log_ok "跳过前端构建（--skip-build，dist 已存在）"
        return
    fi
    log_info "构建前端（npm install + build，约 2-10 分钟）..."
    cd "$PROJECT_DIR/frontend"
    npm install --registry=https://registry.npmmirror.com --no-audit --no-fund || die "npm install 失败"
    npm run build || die "前端构建失败"
    cd "$PROJECT_DIR"
    log_ok "前端构建完成"
}

# ============================================================
# 10. systemd 服务
# ============================================================
write_systemd() {
    log_info "写入 systemd 服务 ..."
    mkdir -p "$PROJECT_DIR/logs"
    cat > /etc/systemd/system/xvfb.service << 'EOF'
[Unit]
Description=Xvfb Virtual Display Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    for svc in backend-web websocket scheduler; do
        local unit="ppfish-${svc}"
        cat > "/etc/systemd/system/${unit}.service" << EOF
[Unit]
Description=ppfish ${svc} service
After=network.target ${MYSQL_SERVICE}.service ${REDIS_SERVICE}.service

[Service]
Environment=DISPLAY=:99
Type=simple
WorkingDirectory=${PROJECT_DIR}
ExecStart=${PROJECT_DIR}/${svc}/.venv/bin/python ${PROJECT_DIR}/${svc}/main.py
Restart=always
RestartSec=5
Environment=TZ=Asia/Shanghai

[Install]
WantedBy=multi-user.target
EOF
        svc_enable "$unit"
    done
    svc_enable xvfb
    systemctl daemon-reload
    log_ok "systemd 服务已写入并启用"
}

# ============================================================
# 11. Nginx 配置
# ============================================================
write_nginx() {
    local conf_path=""
    if [[ "$MODE" == "baota" ]]; then
        mkdir -p /www/server/nginx/conf/vhost
        conf_path="/www/server/nginx/conf/vhost/ppfish.conf"
    else
        if [[ "$OS_FAMILY" == "debian" ]]; then
            conf_path="/etc/nginx/conf.d/ppfish.conf"
        else
            mkdir -p /etc/nginx/conf.d
            conf_path="/etc/nginx/conf.d/ppfish.conf"
        fi
    fi
    cat > "$conf_path" << EOF
server {
    listen ${FRONTEND_PORT};
    server_name _;
    root ${PROJECT_DIR}/frontend/dist;
    index index.html;
    client_max_body_size 100m;

    # WebSocket 反代（前端在线聊天 -> backend-web 8089）
    location /api/v1/chat-new/ws/ {
        proxy_pass http://127.0.0.1:8089;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }

    # API 反代 -> backend-web 8089
    location /api/ {
        proxy_pass http://127.0.0.1:8089;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # 静态资源 + SPA 路由
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /assets/ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    # 默认 nginx.conf 若未 include conf.d，追加
    local main_conf=""
    [[ -f /etc/nginx/nginx.conf ]] && main_conf="/etc/nginx/nginx.conf"
    [[ -f /www/server/nginx/conf/nginx.conf ]] && main_conf="/www/server/nginx/conf/nginx.conf"
    if [[ -n "$main_conf" ]]; then
        grep -q "conf.d/\*.conf" "$main_conf" || \
            sed -i "s|include /etc/nginx/conf.d/\*.conf;|include /etc/nginx/conf.d/*.conf;|" "$main_conf" 2>/dev/null || true
        grep -q "vhost/\*.conf" "$main_conf" || \
            sed -i "s|include /www/server/nginx/conf/vhost/\*.conf;|include /www/server/nginx/conf/vhost/*.conf;|" "$main_conf" 2>/dev/null || true
    fi
    nginx -t 2>/dev/null || { log_warn "nginx 配置检查失败，请手动检查 $conf_path"; return; }
    svc_restart nginx
    log_ok "Nginx 配置已写入: $conf_path（端口 ${FRONTEND_PORT}）"
}

# ============================================================
# 12. 防火墙放行
# ============================================================
open_firewall() {
    local ports=("${FRONTEND_PORT}" 8089 8090 8091 80 443)
    if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
        for p in "${ports[@]}"; do
            firewall-cmd --permanent --add-port=${p}/tcp >/dev/null 2>&1 || true
        done
        firewall-cmd --reload >/dev/null 2>&1 || true
        log_ok "firewalld 已放行端口: ${ports[*]}"
    elif command -v ufw &>/dev/null && systemctl is-active ufw &>/dev/null; then
        for p in "${ports[@]}"; do
            ufw allow ${p}/tcp >/dev/null 2>&1 || true
        done
        log_ok "ufw 已放行端口: ${ports[*]}"
    else
        log_warn "未检测到活动防火墙（firewalld/ufw），跳过；云服务器请到安全组放行 ${ports[*]}"
    fi
}

# ============================================================
# 13. 启动 + 验证
# ============================================================
start_services() {
    systemctl start xvfb
    systemctl start ppfish-backend ppfish-websocket ppfish-scheduler || true
    log_info "等待服务启动（backend 首次启动自动建表+默认管理员 admin/admin123）..."
    sleep 12
}

verify() {
    local ok=1
    for svc in ppfish-backend ppfish-websocket ppfish-scheduler xvfb; do
        if systemctl is-active "$svc" &>/dev/null; then
            log_ok "$svc 运行中"
        else
            log_err "$svc 未运行（日志: journalctl -u $svc -n 30）"
            ok=0
        fi
    done
    local checks=(8089 8090 8091)
    for port in "${checks[@]}"; do
        local body
        body=$(curl -s --max-time 10 "http://127.0.0.1:${port}/health" 2>/dev/null || true)
        if echo "$body" | grep -q '"success": *true'; then
            log_ok "健康检查 :${port} 通过"
        else
            log_err "健康检查 :${port} 未通过（返回: ${body:0:120}）"
            ok=0
        fi
    done
    local front_code
    front_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://127.0.0.1:${FRONTEND_PORT}/" 2>/dev/null || true)
    if [[ "$front_code" == "200" ]]; then
        log_ok "前端 :${FRONTEND_PORT} 正常"
    else
        log_err "前端 :${FRONTEND_PORT} 异常（HTTP $front_code）"
        ok=0
    fi
    return $ok
}

# ============================================================
# 主流程
# ============================================================
echo "=========================================="
echo "  ppfish 一键部署脚本"
echo "  模式: ${MODE} / 项目: ${PROJECT_DIR}"
echo "=========================================="
echo ""

install_base_pkgs
ensure_python
ensure_node
detect_services
ensure_mysql
ensure_redis
ensure_nginx
import_backup
generate_env
setup_venv backend-web
setup_venv websocket
setup_venv scheduler
install_browsers
build_frontend
write_systemd
write_nginx
open_firewall
start_services

echo ""
if verify; then
    echo -e "${GREEN}=========================================="
    echo "  部署完成！"
    echo "==========================================${NC}"
    echo ""
    echo "访问地址:"
    echo "  前端:       http://服务器IP:${FRONTEND_PORT}"
    echo "  后端健康:   http://127.0.0.1:8089/health"
    echo "  登录账号:   admin / admin123 （登录后请立即修改密码）"
    echo ""
    echo "常用命令:"
    echo "  查看日志:   journalctl -u ppfish-backend -f"
    echo "              journalctl -u ppfish-websocket -f"
    echo "              journalctl -u ppfish-scheduler -f"
    echo "  重启服务:   systemctl restart ppfish-backend ppfish-websocket ppfish-scheduler"
    echo ""
    log_warn "重要提醒："
    echo "  1. .env 中 DB/Redis 密码与 MF_APP_KEY/SECRET 请妥善保管，勿公开"
    echo "  2. 若本机无法访问 9000 端口，检查云安全组是否放行"
    echo "  3. 买家充值链接打不开时，检查 .env 的 MF_RECHARGE_BASE_URL 是否为公网可访问地址"
    echo "  4. 登录后台后立即修改 admin 默认密码"
    echo ""
else
    log_err "部分服务未通过健康检查，请按上方提示排查（journalctl -u 服务名 -n 50）"
    exit 1
fi
