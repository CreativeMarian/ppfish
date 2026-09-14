# ============================================================
# ppfish Windows 一键打包上传工具
#
# 功能:
#   1. 把本地项目打包成 tar.gz（自动排除 .git/node_modules/.venv/.env/日志/浏览器缓存）
#   2. 可选包含数据库全量备份 backups/xianyu_data_full.sql
#   3. 可选包含前端构建产物 frontend/dist（服务器可跳过 npm 构建）
#   4. 用 scp 上传到服务器（交互输入 root 密码）
#   5. 打印服务器端解压 + 一键部署命令
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File 打包上传.ps1
#   powershell -ExecutionPolicy Bypass -File 打包上传.ps1 -ServerIp 1.2.3.4
#   powershell -ExecutionPolicy Bypass -File 打包上传.ps1 -NoUpload      # 只打包
#   powershell -ExecutionPolicy Bypass -File 打包上传.ps1 -SkipBackup   # 不带数据库备份
#   powershell -ExecutionPolicy Bypass -File 打包上传.ps1 -SkipDist     # 不带前端构建产物
# ============================================================

param(
    [string]$ProjectDir = "",
    [string]$ServerIp = "",
    [string]$RemotePath = "/tmp",
    [switch]$NoUpload,
    [switch]$SkipBackup,
    [switch]$SkipDist
)

# ---------- 目录确定 ----------
if (-not $ProjectDir) {
    $ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$ProjectDir = [System.IO.Path]::GetFullPath($ProjectDir)
if (-not (Test-Path "$ProjectDir\backend-web\main.py")) {
    Write-Host "[错误] 未找到项目: $ProjectDir（应包含 backend-web\main.py）" -ForegroundColor Red
    exit 1
}

# ---------- 包名 ----------
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$pkgName = "ppfish-deploy-$stamp.tar.gz"
$pkgPath = Join-Path $ProjectDir $pkgName

# ---------- 打包排除项 ----------
$excludes = @(
    "--exclude=.git",
    "--exclude=node_modules",
    "--exclude=.venv",
    "--exclude=__pycache__",
    "--exclude=.env",
    "--exclude=logs",
    "--exclude=browser_data",
    "--exclude=backups/*.sql.gz",   # 定时备份(.gz)不打包，只保留全量 xianyu_data_full.sql
    "--exclude=*.tar.gz"            # 排除历史部署包自身
)
if ($SkipDist) {
    $excludes += "--exclude=frontend/dist"
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  ppfish 打包工具" -ForegroundColor Cyan
Write-Host "  项目: $ProjectDir" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ---------- 确认备份 ----------
if (-not $SkipBackup) {
    $backupFile = "$ProjectDir\backups\xianyu_data_full.sql"
    if (Test-Path $backupFile) {
        $sizeMB = [math]::Round((Get-Item $backupFile).Length / 1MB, 2)
        Write-Host "[信息] 将包含数据库全量备份: backups\xianyu_data_full.sql (${sizeMB} MB)" -ForegroundColor Yellow
    } else {
        Write-Host "[提示] 未找到 backups\xianyu_data_full.sql，本次不包含数据库备份" -ForegroundColor Yellow
    }
}

# ---------- 打包 ----------
Write-Host "[信息] 正在打包（可能需要 1-3 分钟）..."
$excludeArgs = $excludes -join " "
$cmd = "tar -czf `"$pkgPath`" $excludeArgs -C `"$ProjectDir`" ."
Invoke-Expression $cmd
if (-not (Test-Path $pkgPath)) {
    Write-Host "[错误] 打包失败" -ForegroundColor Red
    exit 1
}

$sizeMB = [math]::Round((Get-Item $pkgPath).Length / 1MB, 2)
Write-Host "[成功] 打包完成: $pkgPath (${sizeMB} MB)" -ForegroundColor Green

# ---------- 上传 ----------
if ($NoUpload) {
    Write-Host ""
    Write-Host "已跳过上传。可手动上传此包到服务器（如宝塔文件管理器 /tmp/）。" -ForegroundColor Yellow
} else {
    if (-not $ServerIp) {
        $ServerIp = Read-Host "请输入服务器 IP"
    }
    if (-not $ServerIp) {
        Write-Host "[错误] 未提供服务器 IP" -ForegroundColor Red
        exit 1
    }

    $scp = "C:\Windows\System32\OpenSSH\scp.exe"
    if (-not (Test-Path $scp)) {
        $scp = "scp"
    }

    Write-Host "[信息] 上传到 root@${ServerIp}:${RemotePath}/ （按提示输入 root 密码）..."
    & $scp -P 22 "$pkgPath" "root@${ServerIp}:${RemotePath}/"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 上传失败（请确认 IP/密码/网络，或改用宝塔文件管理器手动上传）" -ForegroundColor Red
        exit 1
    }
    Write-Host "[成功] 上传完成" -ForegroundColor Green
}

# ---------- 服务器操作指引 ----------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  下一步：服务器上执行" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1) 登录服务器（SSH）后解压到项目目录:"
Write-Host "   mkdir -p /www/wwwroot/ppfish && tar -xzf ${RemotePath}/$pkgName -C /www/wwwroot/ppfish"
Write-Host ""
Write-Host "2) 运行一键部署（推荐带备份导入 + 跳过前端构建）:"
$distArg = ""
if (-not $SkipDist) { $distArg = "--skip-build " }
$backupArg = ""
if (-not $SkipBackup -and (Test-Path "$ProjectDir\backups\xianyu_data_full.sql")) {
    $backupArg = "--backup-sql /www/wwwroot/ppfish/backups/xianyu_data_full.sql "
}
Write-Host "   cd /www/wwwroot/ppfish && bash linux-deploy.sh --src local ${distArg}${backupArg}--recharge-url http://你的服务器IP:9000"
Write-Host ""
Write-Host "   （不带 --backup-sql 时，系统会自动建空库 + 默认管理员 admin/admin123）"
Write-Host ""
