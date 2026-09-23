<#
 Ollama + Open WebUI 업데이트 (백업 후 진행)
   .\update.ps1
#>
$ErrorActionPreference = "Continue"
& "$PSScriptRoot\backup.ps1"
Write-Host "[..] Ollama 업데이트"
winget upgrade --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements
$docker = $false
if (Get-Command docker -ErrorAction SilentlyContinue) { docker inspect open-webui *> $null; if ($LASTEXITCODE -eq 0) { $docker = $true } }
if ($docker) {
  Write-Host "[..] Open WebUI(Docker) 업데이트 - 기존 포트 설정 유지"
  $bind = docker inspect -f '{{range $p, $c := .HostConfig.PortBindings}}{{(index $c 0).HostIp}}:{{(index $c 0).HostPort}}{{end}}' open-webui
  $name = (docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' open-webui | Select-String '^WEBUI_NAME=') -replace '^WEBUI_NAME=',''
  docker pull ghcr.io/open-webui/open-webui:main
  docker rm -f open-webui | Out-Null
  $bind = $bind.TrimStart(':')
  docker run -d --name open-webui --network ai-net --restart always -p "${bind}:8080" `
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 -e "WEBUI_NAME=$name" `
    -v open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main | Out-Null
} else {
  Write-Host "[..] Open WebUI(Python) 업데이트"
  Stop-ScheduledTask -TaskName "OpenWebUI" -ErrorAction SilentlyContinue
  Get-Process -Name "open-webui" -ErrorAction SilentlyContinue | Stop-Process -Force
  uv tool upgrade open-webui
  Start-ScheduledTask -TaskName "OpenWebUI"
}
Write-Host "[OK] 업데이트 완료" -ForegroundColor Green
