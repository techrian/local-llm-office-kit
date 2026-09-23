<#
 원격 지원 종료 후 정리 : RustDesk 프로세스 종료, 실행 파일·설정 삭제
   .\rustdesk-cleanup.ps1
#>
$ErrorActionPreference = "Continue"
Get-Process -Name "rustdesk*" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
$paths = @(
  (Join-Path $env:TEMP "rustdesk-onetime"),
  (Join-Path $env:APPDATA "RustDesk")          # ID·비밀번호·접속 기록 설정
)
foreach ($p in $paths) { if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Host "[OK] 삭제: $p" -ForegroundColor Green } }
if (Get-Service -Name "RustDesk" -ErrorAction SilentlyContinue) {
  Write-Host "[!!] RustDesk가 '설치'되어 서비스로 등록돼 있습니다." -ForegroundColor Yellow
  Write-Host "     설정 > 앱 > 설치된 앱 에서 RustDesk를 제거하세요."
} else {
  Write-Host "[OK] RustDesk 서비스 없음 (설치 흔적 없음)" -ForegroundColor Green
}
Write-Host "원격 지원 정리가 끝났습니다. 이후에는 외부에서 이 PC에 접속할 수 없습니다."
