<#
=============================================================================
 local-llm-office-kit : Windows 10/11 설치 스크립트
   - NVIDIA 드라이버 확인
   - Ollama 설치(winget) 및 환경 변수 설정
   - Open WebUI 설치 (Docker Desktop 이 있으면 Docker, 없으면 Python/uv 방식)
   - 첫 모델 내려받기

 실행 방법 (PowerShell을 "관리자 권한으로 실행"):
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\install.ps1                         # 기본값 (이 PC 전용, qwen3:32b)
   .\install.ps1 -Model gpt-oss:20b      # 첫 모델 지정
   .\install.ps1 -Lan                    # 사내망 다른 PC에서도 접속 허용
   .\install.ps1 -NoWebUI                # Ollama만 설치
   .\install.ps1 -WebUIMode python       # Docker 대신 Python 방식 강제
=============================================================================
#>
param(
  [string]$Model = "qwen3:32b",
  [switch]$Lan,
  [switch]$NoWebUI,
  [ValidateSet("auto","docker","python")][string]$WebUIMode = "auto",
  [int]$Port = 3000,
  [string]$WebUIName = "우리회사 AI",
  [string]$DataDir = "C:\open-webui-data"
)
# 네이티브 명령(docker, ollama)의 stderr가 PowerShell 5.1에서 오류로 취급되지 않도록 Continue 사용
$ErrorActionPreference = "Continue"
function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Info($m){ Write-Host "[..] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[!!] $m" -ForegroundColor Yellow }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Warn "관리자 권한이 아닙니다. 방화벽 규칙 추가가 실패할 수 있습니다." }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host "winget이 없습니다. Microsoft Store에서 '앱 설치 관리자(App Installer)'를 설치한 뒤 다시 실행하세요." -ForegroundColor Red; exit 1
}

# --- 1. GPU ------------------------------------------------------------------
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
  Ok "NVIDIA 드라이버 확인됨"
  nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader
} else {
  Warn "nvidia-smi 를 찾을 수 없습니다. https://www.nvidia.com/drivers 에서 최신 드라이버를 설치하세요."
  Warn "GPU 없이도 동작하지만 매우 느립니다."
}

# --- 2. Ollama ---------------------------------------------------------------
if (Get-Command ollama -ErrorAction SilentlyContinue) {
  Ok "Ollama 이미 설치됨: $(ollama --version)"
} else {
  Info "Ollama 설치 중 (winget)"
  winget install --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
}

# 환경 변수 (사용자 범위)
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "30m", "User")
[Environment]::SetEnvironmentVariable("OLLAMA_NUM_PARALLEL", "4", "User")
if ($Lan -or $WebUIMode -eq "docker" -or ($WebUIMode -eq "auto" -and (Get-Command docker -ErrorAction SilentlyContinue))) {
  # Docker 컨테이너나 다른 PC에서 접속하려면 0.0.0.0 으로 열어야 함 (방화벽으로 범위 제한)
  [Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0:11434", "User")
} else {
  [Environment]::SetEnvironmentVariable("OLLAMA_HOST", "127.0.0.1:11434", "User")
}
$env:OLLAMA_HOST = [Environment]::GetEnvironmentVariable("OLLAMA_HOST","User")

# 환경 변수 반영을 위해 Ollama 재시작
Get-Process -Name "ollama app","ollama" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
$ollamaApp = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama app.exe"
if (Test-Path $ollamaApp) { Start-Process $ollamaApp } else { Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden }
Start-Sleep 5
try { Invoke-RestMethod http://127.0.0.1:11434/api/tags | Out-Null; Ok "Ollama API 응답 확인 (11434)" }
catch { Warn "Ollama 응답 없음. 작업 표시줄의 Ollama 아이콘을 확인하세요." }

# --- 3. 모델 -----------------------------------------------------------------
Info "모델 내려받는 중: $Model (수 GB~수십 GB)"
ollama pull $Model
if ($LASTEXITCODE -eq 0) { Ok "모델 준비 완료: $Model" } else { Warn "모델 이름 확인: https://ollama.com/library" }
ollama pull bge-m3 | Out-Null

if ($NoWebUI) { Ok "Ollama 설치 완료 (-NoWebUI). 사용: ollama run $Model"; exit 0 }

# --- 4. Open WebUI -----------------------------------------------------------
$mode = $WebUIMode
if ($mode -eq "auto") {
  $mode = "python"
  if (Get-Command docker -ErrorAction SilentlyContinue) {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { $mode = "docker" } else { Warn "Docker Desktop이 설치돼 있지만 실행 중이 아닙니다 → Python 방식으로 진행" }
  }
}
$bind = if ($Lan) { "0.0.0.0" } else { "127.0.0.1" }

if ($mode -eq "docker") {
  Info "Open WebUI (Docker) 실행"
  docker network inspect ai-net *> $null; if ($LASTEXITCODE -ne 0) { docker network create ai-net | Out-Null }
  docker rm -f open-webui *> $null
  $pub = if ($Lan) { "${Port}:8080" } else { "127.0.0.1:${Port}:8080" }
  docker run -d --name open-webui --network ai-net --restart always -p $pub `
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 -e "WEBUI_NAME=$WebUIName" `
    -v open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main | Out-Null
} else {
  Info "Open WebUI (Python/uv) 설치"
  if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    winget install --id astral-sh.uv -e --accept-source-agreements --accept-package-agreements
    $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
  }
  uv tool install --python 3.11 open-webui
  uv tool update-shell | Out-Null
  $env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + $env:Path
  New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

  # 실행 배치 파일 + 로그인 시 자동 시작(작업 스케줄러)
  $runner = Join-Path $DataDir "start-open-webui.cmd"
  @"
@echo off
chcp 65001 >nul
set DATA_DIR=$DataDir
set OLLAMA_BASE_URL=http://127.0.0.1:11434
set WEBUI_NAME=$WebUIName
open-webui serve --host $bind --port $Port >> "$DataDir\open-webui.log" 2>&1
"@ | ForEach-Object { [IO.File]::WriteAllText($runner, $_, (New-Object Text.UTF8Encoding $false)) }  # BOM 없는 UTF-8 (cmd 호환)
  $action  = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$runner`""
  $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
  Register-ScheduledTask -TaskName "OpenWebUI" -Action $action -Trigger $trigger -Force `
    -Settings (New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries) | Out-Null
  Start-ScheduledTask -TaskName "OpenWebUI"
  Ok "작업 스케줄러 'OpenWebUI' 등록 (로그인 시 자동 시작)"
}

# --- 5. 방화벽 ---------------------------------------------------------------
if ($Lan -and $isAdmin) {
  Remove-NetFirewallRule -DisplayName "Open WebUI (LAN)" -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName "Open WebUI (LAN)" -Direction Inbound -Protocol TCP -LocalPort $Port `
    -RemoteAddress LocalSubnet -Action Allow -Profile Private,Domain | Out-Null
  Ok "방화벽: 같은 서브넷에서만 $Port 허용 (네트워크 프로필이 '개인'이어야 함)"
}

Info "Open WebUI 시작 대기 (최초 1~3분)"
for ($i=0; $i -lt 60; $i++) {
  try { Invoke-WebRequest "http://127.0.0.1:$Port" -UseBasicParsing -TimeoutSec 3 | Out-Null; break } catch { Start-Sleep 3 }
}
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -in "Dhcp","Manual" -and $_.IPAddress -notlike "169.*" } | Select-Object -First 1).IPAddress
Write-Host ""
Ok "설치 완료! (모드: $mode)"
Write-Host "  이 PC:     http://127.0.0.1:$Port"
if ($Lan) { Write-Host "  사내 PC:   http://${ip}:$Port" }
Write-Host "  첫 번째로 가입하는 계정이 관리자가 됩니다."
Write-Host "  상태 점검: .\healthcheck.ps1"
Start-Process "http://127.0.0.1:$Port"
