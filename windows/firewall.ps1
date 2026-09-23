<#
 Windows 방화벽 정리 (관리자 PowerShell)
   .\firewall.ps1                # Ollama(11434)는 Docker/WSL 대역만 허용, 다른 PC 차단
   .\firewall.ps1 -AllowWebUI    # Open WebUI(3000)를 같은 서브넷에 허용
#>
param([switch]$AllowWebUI, [int]$Port = 3000)
$ErrorActionPreference = "Continue"
# Ollama 첫 실행 때 "허용"을 눌러 생긴 자동 규칙 제거 (전체 공개 방지)
Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
  Where-Object { $_.Program -like "*ollama*" } |
  Get-NetFirewallRule | Where-Object { $_.Direction -eq "Inbound" } |
  ForEach-Object { Write-Host "[..] 자동 생성 규칙 제거: $($_.DisplayName)"; Remove-NetFirewallRule -Name $_.Name }

Remove-NetFirewallRule -DisplayName "Ollama (Docker/WSL only)" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Ollama (Docker/WSL only)" -Direction Inbound -Protocol TCP -LocalPort 11434 `
  -RemoteAddress 172.16.0.0/12 -Action Allow | Out-Null
Write-Host "[OK] 11434: Docker/WSL(172.16.0.0/12)에서만 허용, 다른 PC는 기본 차단" -ForegroundColor Green

if ($AllowWebUI) {
  Remove-NetFirewallRule -DisplayName "Open WebUI (LAN)" -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName "Open WebUI (LAN)" -Direction Inbound -Protocol TCP -LocalPort $Port `
    -RemoteAddress LocalSubnet -Action Allow -Profile Private,Domain | Out-Null
  Write-Host "[OK] $Port : 같은 서브넷(개인/도메인 네트워크)에서만 허용" -ForegroundColor Green
  $prof = Get-NetConnectionProfile | Select-Object -First 1
  if ($prof.NetworkCategory -eq "Public") {
    Write-Host "[!!] 현재 네트워크가 '공용'입니다. 사내망이면 '개인'으로 바꾸세요:" -ForegroundColor Yellow
    Write-Host "     Set-NetConnectionProfile -InterfaceIndex $($prof.InterfaceIndex) -NetworkCategory Private"
  }
}
Get-NetFirewallRule -DisplayName "Ollama*","Open WebUI*" | Format-Table DisplayName, Enabled, Action, Profile -AutoSize
