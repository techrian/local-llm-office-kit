#!/usr/bin/env bash
# Ollama + Open WebUI 업데이트 (백업 후 진행)
#   사용법: sudo bash update.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$DIR/backup.sh"
echo "[..] Ollama 업데이트"; curl -fsSL https://ollama.com/install.sh | sh
systemctl restart ollama
if [[ -f /opt/ai/docker-compose.yml ]]; then
  echo "[..] compose 구성 업데이트 (/opt/ai)"
  (cd /opt/ai && docker compose pull && docker compose up -d)
else
  echo "[..] Open WebUI 업데이트 (기존 실행 옵션 유지)"
  docker pull ghcr.io/open-webui/open-webui:main
  PORT_BIND=$(docker inspect -f '{{range $p, $c := .HostConfig.PortBindings}}{{(index $c 0).HostIp}}:{{(index $c 0).HostPort}}{{end}}' open-webui)
  NAME_ENV=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' open-webui | grep '^WEBUI_NAME=' | cut -d= -f2- || true)
  docker rm -f open-webui >/dev/null
  PORT_BIND="${PORT_BIND#:}"
  docker run -d --name open-webui --network ai-net --restart always \
    -p "${PORT_BIND}:8080" --add-host=host.docker.internal:host-gateway \
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
    -e WEBUI_NAME="${NAME_ENV:-우리회사 AI}" \
    -v open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main >/dev/null
fi
docker image prune -f >/dev/null
echo "[OK] 업데이트 완료"; ollama --version
