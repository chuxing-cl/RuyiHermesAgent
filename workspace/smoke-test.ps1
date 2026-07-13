<#
.SYNOPSIS
    新机器落地后冒烟自检：验证便携 workspace 是否真正生效。
.DESCRIPTION
    在源码根目录运行 .\workspace\smoke-test.ps1。
    所有检查 fail-loud——任何一项不通过都明确报错，杜绝「以为复现成功、实则用错环境」。
#>
$ErrorActionPreference = 'Stop'

$Root      = Split-Path -Parent $PSScriptRoot   # 源码根
$Workspace = $PSScriptRoot
$env:HERMES_HOME = $Workspace

$fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = "") {
    if ($ok) {
        Write-Host ("  [PASS] {0}" -f $name) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL] {0}  {1}" -f $name, $detail) -ForegroundColor Red
        $script:fail++
    }
}

Write-Host ""
Write-Host "=== Hermes 便携 workspace 冒烟自检 ===" -ForegroundColor Cyan
Write-Host "源码根:    $Root"
Write-Host "HERMES_HOME: $env:HERMES_HOME"
Write-Host ""

# 1. get_hermes_home() 必须指向源码内 workspace，而不是 ~/.hermes
$py = (Join-Path $Root '.venv\Scripts\python.exe')
if (-not (Test-Path $py)) { $py = 'python' }
$resolved = & $py -c "import sys; sys.path.insert(0, r'$Root'); from hermes_constants import get_hermes_home; print(get_hermes_home())" 2>&1
$resolvedNorm = ($resolved | Out-String).Trim()
Check "get_hermes_home() 指向源码内 workspace" `
      ($resolvedNorm -ieq $Workspace) `
      "实际=$resolvedNorm （若指向 ~/.hermes 说明 HERMES_HOME 未生效）"

# 2. 配置文件存在
Check "config.yaml 存在" (Test-Path (Join-Path $Workspace 'config.yaml'))

# 3. SOUL.md（人设）存在
Check "SOUL.md 存在" (Test-Path (Join-Path $Workspace 'SOUL.md'))

# 4. 源码自带 bundled 技能可见（随源码走）
$skillsDir = Join-Path $Root 'skills'
$skillCount = 0
if (Test-Path $skillsDir) { $skillCount = (Get-ChildItem -Directory $skillsDir | Measure-Object).Count }
Check "源码 skills/ 非空（bundled 技能随源码走）" ($skillCount -gt 0) "目录数=$skillCount"

# 5. .env 存在且密钥非占位符（至少配了一个 provider，或显式跳过）
$envFile = Join-Path $Workspace '.env'
if (Test-Path $envFile) {
    $envText = Get-Content $envFile -Raw
    $hasRealKey = ($envText -match '(?m)^\s*(OPENROUTER_API_KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|GLM_API_KEY|KIMI_API_KEY|DEEPSEEK_API_KEY)\s*=\s*\S+')
    Check ".env 存在" $true
    if (-not $hasRealKey) {
        Write-Host "  [WARN] .env 中尚未填入任何 LLM provider 密钥（部署后需手动填）" -ForegroundColor Yellow
    } else {
        Write-Host "  [PASS] .env 已配置至少一个 LLM provider 密钥" -ForegroundColor Green
    }
} else {
    Check ".env 存在" $false "请先运行 run.ps1 生成，或手动 Copy-Item .env.example .env"
}

# 6. 敏感运行时数据未被 git 跟踪（防泄露回归）
Push-Location $Root
try {
    $tracked = git ls-files "workspace/.env" "workspace/auth.json" "workspace/state.db" 2>$null
    Check "敏感文件未进 git（.env/auth.json/state.db）" ([string]::IsNullOrWhiteSpace($tracked)) "被跟踪: $tracked"
} finally { Pop-Location }

Write-Host ""
if ($fail -eq 0) {
    Write-Host "[OK] 全部通过：便携环境就绪。" -ForegroundColor Green
    exit 0
} else {
    Write-Host ("[X] $fail 项未通过，请按上面提示修复。") -ForegroundColor Red
    exit 1
}
