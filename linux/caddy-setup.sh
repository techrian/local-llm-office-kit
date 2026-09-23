#!/usr/bin/env bash
# Caddy 리버스 프록시로 Open WebUI에 HTTPS 적용 (사내 자체 인증서)
#   사용법: sudo bash caddy-setup.sh ai.company.local [api.company.local]
#   두 번째 인자를 주면 LiteLLM(4000) 관문도 HTTPS로 공개합니다.
set -euo pipefail
HOST="${1:-}"; API_HOST="${2:-}"
[[ -n "$HOST" ]] || { echo "사용법: sudo bash $0 ai.company.local [api.company.local]"; exit 1; }
[[ $EUID -eq 0 ]] || { echo "sudo로 실행하세요"; exit 1; }
apt-get install -y caddy >/dev/null
[[ -f /etc/caddy/Caddyfile ]] && cp /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.bak.$(date +%s)"
{
  echo "$HOST {"
  echo "    tls internal"
  echo "    reverse_proxy 127.0.0.1:${WEBUI_PORT:-3000}"
  echo "}"
  if [[ -n "$API_HOST" ]]; then
    echo
    echo "$API_HOST {"
    echo "    tls internal"
    echo "    reverse_proxy 127.0.0.1:4000"
    echo "}"
  fi
} > /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl enable --now caddy
systemctl reload caddy
IP=$(hostname -I | awk '{print $1}')
ROOT=/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt
echo
echo "[OK] https://$HOST 로 접속하세요."
echo "  1) 각 PC hosts 파일 또는 사내 DNS에 추가:  $IP  $HOST ${API_HOST}"
echo "     - Windows: C:\\Windows\\System32\\drivers\\etc\\hosts (관리자 메모장)"
echo "  2) 브라우저 경고를 없애려면 루트 인증서를 PC에 설치:"
echo "     $ROOT"
echo "     (Windows: 파일 더블클릭 → 인증서 설치 → 로컬 컴퓨터 → '신뢰할 수 있는 루트 인증 기관')"
[[ -f "$ROOT" ]] && cp "$ROOT" "/home/${SUDO_USER:-root}/caddy-root.crt" 2>/dev/null && echo "     사본: ~/caddy-root.crt" || true
