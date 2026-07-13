<#
.SYNOPSIS
    Hermes Agent 便携启动器（Windows / PowerShell）

.DESCRIPTION
    把 HERMES_HOME 指向「本脚本所在目录\workspace」，使运行时的全部数据
    （配置、技能、记忆、会话等）都落在源码树内部。无论这份源码被复制到
    D:\、E:\ 还是别的路径，HERMES_HOME 都会自动跟随——真正做到「复制源码即复现环境」。

    不依赖任何全局环境变量；每次启动都在进程内注入 HERMES_HOME，
    从根上消除「忘了设环境变量 → 静默回退到 ~/.hermes」这一类故障。

.EXAMPLE
    .\run.ps1                 # 启动交互式终端
    .\run.ps1 gateway start   # 启动消息网关
    .\run.ps1 doctor          # 自检
#>

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

# --- 1. 注入 HERMES_HOME（相对脚本自身定位，绝对路径随源码位置自动正确）---
$env:HERMES_HOME = Join-Path $Root 'workspace'
if (-not (Test-Path $env:HERMES_HOME)) {
    New-Item -ItemType Directory -Force -Path $env:HERMES_HOME | Out-Null
}

# --- 2. 首次运行引导：无 .env 则从模板生成并提示填密钥（fail-loud）---
$envFile    = Join-Path $env:HERMES_HOME '.env'
$envExample = Join-Path $env:HERMES_HOME '.env.example'
if (-not (Test-Path $envFile)) {
    if (Test-Path $envExample) {
        Copy-Item $envExample $envFile
        Write-Host ""
        Write-Host "[hermes] 首次运行：已从 .env.example 生成 workspace\.env" -ForegroundColor Yellow
        Write-Host "[hermes] 请打开并填入你的 API 密钥后重新运行：" -ForegroundColor Yellow
        Write-Host "         $envFile" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    } else {
        Write-Host "[hermes] 警告：缺少 workspace\.env.example，无法生成 .env" -ForegroundColor Yellow
    }
}

# --- 3. 解析 Python：优先本地 venv，否则用 PATH 上的 python ---
$py = $null
foreach ($cand in @(
    (Join-Path $Root '.venv\Scripts\python.exe'),
    (Join-Path $Root 'venv\Scripts\python.exe')
)) {
    if (Test-Path $cand) { $py = $cand; break }
}
if (-not $py) {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { $py = $cmd.Source } else { $py = 'python' }
}

# --- 4. 启动 Hermes（入口与已安装的 `hermes` 命令等价，支持全部子命令）---
Write-Host "[hermes] HERMES_HOME = $env:HERMES_HOME" -ForegroundColor DarkGray
& $py (Join-Path $Root 'hermes') @args
exit $LASTEXITCODE
