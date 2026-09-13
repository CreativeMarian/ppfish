# ============================================================
#  ppfish 一键启动脚本 (Windows PowerShell)
#  功能: 环境检查 -> 拉起 MySQL/Redis -> 依次启动三个后端 + 前端
#  用法: 双击「一键启动.bat」，或在 PowerShell 中运行本脚本
#  日志: E:\Demo\Fish\env\logs\
# ============================================================

$HostAddr = '127.0.0.1'
$MysqlPort = 3306
$RedisPort = 6379
$PortBackend = 8089
$PortWs = 8090
$PortSched = 8091
$PortFront = 9000

# ---------- 路径配置 ----------
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvRoot = 'E:\Demo\Fish\env'
$MysqlDir = Join-Path $EnvRoot 'mysql\mysql-8.0.29-winx64'
$MysqlBin = Join-Path $MysqlDir 'bin\mysqld.exe'
$MysqlIni = Join-Path $MysqlDir 'my.ini'
$RedisBin = Join-Path $EnvRoot 'redis\redis-server.exe'
$LogDir = Join-Path $EnvRoot 'logs'

$Services = @(
  @{ Name='backend-web'; Port=$PortBackend; Dir=Join-Path $ProjectRoot 'backend-web'; Log='backend-web'; Health="http://$HostAddr`:$PortBackend/health" },
  @{ Name='websocket';   Port=$PortWs;     Dir=Join-Path $ProjectRoot 'websocket';   Log='websocket';   Health="http://$HostAddr`:$PortWs/health" },
  @{ Name='scheduler';   Port=$PortSched;  Dir=Join-Path $ProjectRoot 'scheduler';   Log='scheduler';   Health="http://$HostAddr`:$PortSched/health" }
)

# ---------- 工具函数 ----------
function Test-PortOpen {
  param([string]$HostName, [int]$Port, [int]$TimeoutMs = 1000)
  try {
    $c = New-Object System.Net.Sockets.TcpClient
    $iar = $c.BeginConnect($HostName, $Port, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs)
    if ($ok) { $c.EndConnect($iar) }
    $c.Close()
    return $ok
  } catch { return $false }
}

function Wait-PortOpen {
  param([string]$HostName, [int]$Port, [int]$TimeoutSec)
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if (Test-PortOpen $HostName $Port 800) { return $true }
    Start-Sleep -Milliseconds 500
  }
  return $false
}

function Wait-HttpOk {
  param([string]$Url, [int]$TimeoutSec)
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    try {
      $r = Invoke-WebRequest -Uri $Url -TimeoutSec 3 -UseBasicParsing
      if ($r.StatusCode -eq 200) { return $true }
    } catch { }
    Start-Sleep -Seconds 2
  }
  return $false
}

function Write-Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "[OK]   $Msg" -ForegroundColor Green }
function Write-Fail { param([string]$Msg) Write-Host "[FAIL] $Msg" -ForegroundColor Red }
function Write-Warn { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

# ---------- 前置检查 ----------
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "   ppfish 一键启动" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

$fails = @()
if (-not (Test-Path $ProjectRoot))              { $fails += "项目目录不存在: $ProjectRoot" }
if (-not (Test-Path (Join-Path $ProjectRoot '.env'))) { $fails += '缺少 .env 配置文件' }
if (-not (Test-Path (Join-Path $ProjectRoot 'backend-web\.venv\Scripts\python.exe'))) { $fails += 'backend-web/.venv 不存在' }
if (-not (Test-Path (Join-Path $ProjectRoot 'websocket\.venv\Scripts\python.exe')))   { $fails += 'websocket/.venv 不存在' }
if (-not (Test-Path (Join-Path $ProjectRoot 'scheduler\.venv\Scripts\python.exe')))   { $fails += 'scheduler/.venv 不存在' }
if (-not (Test-Path (Join-Path $ProjectRoot 'frontend\node_modules')))                 { $fails += 'frontend/node_modules 不存在（请先运行 npm install）' }
if ($fails.Count -gt 0) {
  Write-Host "`n环境检查未通过：" -ForegroundColor Red
  $fails | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
Write-Ok "项目环境检查通过"

# ---------- MySQL ----------
Write-Step "MySQL (端口 $MysqlPort)"
if (Test-PortOpen $HostAddr $MysqlPort 800) {
  Write-Ok "MySQL 已在运行"
} else {
  if (-not (Test-Path $MysqlBin)) { Write-Fail "MySQL 未安装: $MysqlBin"; exit 1 }
  if (-not (Test-Path $MysqlIni)) { Write-Fail "缺少 my.ini: $MysqlIni"; exit 1 }
  New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
  $mysqlOut = Join-Path $LogDir 'mysql.out.log'
  $mysqlErr = Join-Path $LogDir 'mysql.err.log'
  Write-Host "  正在启动 mysqld ..."
  Start-Process -FilePath $MysqlBin `
    -ArgumentList "--defaults-file=$MysqlIni", "--console" `
    -WindowStyle Hidden `
    -RedirectStandardOutput $mysqlOut -RedirectStandardError $mysqlErr | Out-Null
  if (Wait-PortOpen $HostAddr $MysqlPort 60) {
    Write-Ok "MySQL 启动成功"
  } else {
    Write-Fail "MySQL 启动失败，错误日志尾部："
    Get-Content $mysqlErr -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    exit 1
  }
}

# ---------- Redis ----------
Write-Step "Redis (端口 $RedisPort)"
if (Test-PortOpen $HostAddr $RedisPort 800) {
  Write-Ok "Redis 已在运行"
} else {
  if (-not (Test-Path $RedisBin)) { Write-Fail "Redis 未安装: $RedisBin"; exit 1 }
  New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
  $redisOut = Join-Path $LogDir 'redis.out.log'
  $redisErr = Join-Path $LogDir 'redis.err.log'
  Write-Host "  正在启动 redis-server ..."
  Start-Process -FilePath $RedisBin -ArgumentList "--port", "$RedisPort" `
    -WindowStyle Hidden `
    -RedirectStandardOutput $redisOut -RedirectStandardError $redisErr | Out-Null
  if (Wait-PortOpen $HostAddr $RedisPort 30) {
    Write-Ok "Redis 启动成功"
  } else {
    Write-Fail "Redis 启动失败，错误日志尾部："
    Get-Content $redisErr -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    exit 1
  }
}

# ---------- 后端服务 ----------
$started = @()
foreach ($svc in $Services) {
  Write-Step "$($svc.Name) (端口 $($svc.Port))"
  $py = Join-Path $svc.Dir '.venv\Scripts\python.exe'
  if (-not (Test-Path $py)) { Write-Fail "venv 缺失: $py"; continue }

  # 端口已占用：判断是否健康
  if (Test-PortOpen $HostAddr $svc.Port 800) {
    if (Wait-HttpOk $svc.Health 5) {
      Write-Ok "$($svc.Name) 已在运行且健康"
      $started += $svc.Name
      continue
    } else {
      Write-Fail "端口 $($svc.Port) 被占用但健康检查失败（可能被其他程序占用），请先排查"
      continue
    }
  }

  $outLog = Join-Path $LogDir "$($svc.Log).out.log"
  $errLog = Join-Path $LogDir "$($svc.Log).err.log"
  Write-Host "  正在启动 $($svc.Name) ..."
  Start-Process -FilePath $py -ArgumentList 'main.py' `
    -WorkingDirectory $svc.Dir -WindowStyle Hidden `
    -RedirectStandardOutput $outLog -RedirectStandardError $errLog | Out-Null

  if (Wait-PortOpen $HostAddr $svc.Port 90) {
    if (Wait-HttpOk $svc.Health 60) {
      Write-Ok "$($svc.Name) 启动成功（health 200）"
      $started += $svc.Name
    } else {
      Write-Fail "$($svc.Name) 端口已开但 health 异常，日志尾部："
      Get-Content $errLog -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
    }
  } else {
    Write-Fail "$($svc.Name) 启动超时，错误日志尾部："
    Get-Content $errLog -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
  }
}

# ---------- 前端 ----------
Write-Step "前端 (端口 $PortFront)"
if (Test-PortOpen $HostAddr $PortFront 800) {
  Write-Ok "前端已在运行"
} else {
  $frontDir = Join-Path $ProjectRoot 'frontend'
  $frontOut = Join-Path $LogDir 'frontend.out.log'
  $frontErr = Join-Path $LogDir 'frontend.err.log'
  Write-Host "  正在启动 npm run dev ..."
  Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'npm run dev' `
    -WorkingDirectory $frontDir -WindowStyle Hidden `
    -RedirectStandardOutput $frontOut -RedirectStandardError $frontErr | Out-Null
  if (Wait-PortOpen $HostAddr $PortFront 60) {
    Write-Ok "前端启动成功"
  } else {
    Write-Fail "前端启动超时，日志尾部："
    Get-Content $frontOut -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Get-Content $frontErr -Tail 5 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
  }
}

# ---------- 汇总 ----------
Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "   启动结果汇总" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
$allOk = $true
foreach ($item in @(
  @{ Name='MySQL';       Port=3306 },
  @{ Name='Redis';       Port=6379 },
  @{ Name='backend-web'; Port=8089 },
  @{ Name='websocket';   Port=8090 },
  @{ Name='scheduler';   Port=8091 },
  @{ Name='前端';        Port=9000 }
)) {
  $open = Test-PortOpen $HostAddr $item.Port 800
  $mark = if ($open) { '运行中' } else { '未运行' }
  $color = if ($open) { 'Green' } else { 'Red' }
  Write-Host ("  {0,-14} 端口 {1,-5} {2}" -f $item.Name, $item.Port, $mark) -ForegroundColor $color
  if (-not $open) { $allOk = $false }
}
Write-Host ""
Write-Host "  访问地址: http://localhost:9000  （管理员 admin / admin123，登录后请改密码）" -ForegroundColor Yellow
if (-not $allOk) {
  Write-Host "  部分服务未就绪，请查看日志目录: $LogDir" -ForegroundColor Yellow
  exit 1
}
Write-Ok "全部服务就绪"
