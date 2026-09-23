<#
=============================================================================
 1회성 원격 지원 : RustDesk 포터블 실행 (고객 PC에서 실행)
   - 설치하지 않고 실행만 합니다 (종료하면 접속 불가)
   - 접속할 때마다 바뀌는 "일회용 비밀번호"만 컨설턴트에게 알려주세요

 실행: PowerShell에서
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\rustdesk-onetime.ps1
 종료 후 정리: .\rustdesk-cleanup.ps1
=============================================================================
#>
$ErrorActionPreference = "Stop"
$dir = Join-Path $env:TEMP "rustdesk-onetime"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Write-Host "[..] RustDesk 최신 버전 확인 (공식 GitHub: github.com/rustdesk/rustdesk)" -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$rel = Invoke-RestMethod "https://api.github.com/repos/rustdesk/rustdesk/releases/latest" -Headers @{ "User-Agent" = "llm-kit" }
$asset = $rel.assets | Where-Object { $_.name -match '^rustdesk-.*-x86_64\.exe$' } | Select-Object -First 1
if (-not $asset) { throw "Windows용 실행 파일을 찾지 못했습니다. https://rustdesk.com 에서 직접 받아주세요." }
$exe = Join-Path $dir $asset.name
if (-not (Test-Path $exe)) {
  Write-Host "[..] 다운로드: $($asset.name) ($([math]::Round($asset.size/1MB,1)) MB)"
  Invoke-WebRequest $asset.browser_download_url -OutFile $exe -UseBasicParsing
}
$sig = Get-AuthenticodeSignature $exe
Write-Host "[..] 디지털 서명: $($sig.Status) / $($sig.SignerCertificate.Subject)"
if ($sig.Status -ne "Valid") { Write-Host "[!!] 서명이 유효하지 않습니다. 실행하지 말고 컨설턴트에게 알려주세요." -ForegroundColor Yellow; exit 1 }

Start-Process $exe
Write-Host ""
Write-Host "================ 고객님께 ================" -ForegroundColor Green
Write-Host " 1. 설치 여부를 물으면 '설치하지 않고 실행(Run without install)'을 선택하세요."
Write-Host " 2. 화면 왼쪽의 'ID'와 '일회용 비밀번호'를 컨설턴트에게 알려주세요."
Write-Host " 3. 접속 요청 창이 뜨면 '수락'을 누르세요. 작업은 화면에서 계속 지켜보실 수 있습니다."
Write-Host " 4. 작업이 끝나면 RustDesk 창을 닫고 .\rustdesk-cleanup.ps1 을 실행하세요."
Write-Host " ※ 언제든 창을 닫거나 '연결 끊기'를 누르면 즉시 접속이 종료됩니다."
Write-Host "=========================================="
