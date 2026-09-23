<#
 주간 점검 (Windows)
   .\healthcheck.ps1
#>
$ErrorActionPreference = "Continue"
$pass = 0; $warn = 0
function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green; $script:pass++ }
function Ng($m){ Write-Host "[!!] $m" -ForegroundColor Yellow; $script:warn++ }

Write-Host "== GPU =="
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
  nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader
  Ok "nvidia-smi 동작"
} else { Ng "nvidia-smi 없음 (드라이버 확인)" }

Write-Host "== 서비스 =="
try { Invoke-RestMethod http://127.0.0.1:11434/api/tags -TimeoutSec 5 | Out-Null; Ok "Ollama API 응답" } catch { Ng "Ollama 무응답 (작업 표시줄 아이콘 확인)" }
Write-Host "  OLLAMA_HOST = $([Environment]::GetEnvironmentVariable('OLLAMA_HOST','User'))"
$ps = ollama ps; $ps | ForEach-Object { "    $_" }
if ($ps -match "CPU") { Ng "일부 모델이 CPU로 동작 중 (VRAM 부족 → 느림)" }
try { Invoke-WebRequest http://127.0.0.1:3000 -UseBasicParsing -TimeoutSec 5 | Out-Null; Ok "Open WebUI 응답 (3000)" } catch { Ng "Open WebUI 무응답" }

Write-Host "== 디스크 =="
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
  $pct = [math]::Round($_.Used / ($_.Used + $_.Free) * 100)
  "  $($_.Name): 사용 $pct% / 여유 $([math]::Round($_.Free/1GB)) GB"
  if ($pct -ge 80) { Ng "$($_.Name): 디스크 80% 이상" }
}
Write-Host "  모델 저장 위치: $env:USERPROFILE\.ollama\models (변경: OLLAMA_MODELS 환경변수)"

Write-Host "== 백업 =="
$last = Get-ChildItem "D:\backup\open-webui" -Filter "owui-*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($last -and $last.LastWriteTime -gt (Get-Date).AddDays(-2)) { Ok "최근 백업: $($last.Name)" } else { Ng "2일 이내 백업 없음 (.\backup.ps1 -InstallTask)" }

Write-Host "== 외부에서 대기 중인 포트 =="
Get-NetTCPConnection -State Listen | Where-Object { $_.LocalAddress -in "0.0.0.0","::" -and $_.LocalPort -in 3000,4000,8000,11434 } |
  ForEach-Object { Ng "포트 $($_.LocalPort) 가 모든 인터페이스에 열림 (firewall.ps1 로 범위 제한 확인)" }

Write-Host ""; Write-Host "결과: 정상 $pass / 확인 필요 $warn"
