<#
 Open WebUI 데이터 백업 (Docker/Python 방식 자동 판별)
   .\backup.ps1                              # 기본: D:\backup\open-webui, 14일 보관
   .\backup.ps1 -Dest E:\ai-backup -Keep 30
   .\backup.ps1 -InstallTask                 # 매일 03:00 자동 백업 등록
#>
param([string]$Dest = "D:\backup\open-webui", [int]$Keep = 14,
      [string]$DataDir = "C:\open-webui-data", [switch]$InstallTask)
$ErrorActionPreference = "Continue"
if ($InstallTask) {
  $self = $MyInvocation.MyCommand.Path
  $a = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$self`" -Dest `"$Dest`" -Keep $Keep"
  $t = New-ScheduledTaskTrigger -Daily -At 3am
  Register-ScheduledTask -TaskName "OpenWebUI-Backup" -Action $a -Trigger $t -Force | Out-Null
  Write-Host "[OK] 매일 03:00 백업 예약 (작업 스케줄러: OpenWebUI-Backup)"; exit 0
}
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
$stamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$useDocker = $false
if (Get-Command docker -ErrorAction SilentlyContinue) {
  docker volume inspect open-webui *> $null
  if ($LASTEXITCODE -eq 0) { $useDocker = $true }
}
if ($useDocker) {
  docker run --rm -v open-webui:/data:ro -v "${Dest}:/backup" alpine tar czf "/backup/owui-$stamp.tar.gz" -C /data .
  $file = Join-Path $Dest "owui-$stamp.tar.gz"
} else {
  # Python 방식: 쓰기 중 손상을 막기 위해 잠시 중지 후 압축
  Stop-ScheduledTask -TaskName "OpenWebUI" -ErrorAction SilentlyContinue
  Get-Process -Name "open-webui" -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep 2
  $file = Join-Path $Dest "owui-$stamp.zip"
  Compress-Archive -Path "$DataDir\*" -DestinationPath $file -Force
  Start-ScheduledTask -TaskName "OpenWebUI" -ErrorAction SilentlyContinue
}
Get-ChildItem $Dest -Filter "owui-*" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$Keep) } | Remove-Item -Force
if (Test-Path $file) { Write-Host "[OK] 백업 완료: $file ($([math]::Round((Get-Item $file).Length/1MB,1)) MB)" -ForegroundColor Green }
else { Write-Host "[XX] 백업 실패" -ForegroundColor Red; exit 1 }
