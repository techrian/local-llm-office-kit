#!/usr/bin/env bash
# 사내망 전용 방화벽 설정 (ufw)
#   사용법: sudo bash firewall.sh 192.168.0.0/24
#   - SSH(22), HTTPS(443)만 사내 대역에 허용
#   - Ollama(11434)는 도커 컨테이너 대역에서만 허용
set -euo pipefail
LAN_CIDR="${1:-}"
if [[ -z "$LAN_CIDR" ]]; then
  echo "사내 대역을 입력하세요. 예: sudo bash $0 192.168.0.0/24"
  echo "현재 서버 주소: $(hostname -I)"
  exit 1
fi
[[ $EUID -eq 0 ]] || { echo "sudo로 실행하세요"; exit 1; }
apt-get install -y ufw >/dev/null

# 22번 허용 규칙을 먼저 넣고 활성화해야 SSH가 끊기지 않습니다
ufw allow from "$LAN_CIDR" to any port 22 proto tcp comment 'SSH (LAN)'
ufw allow from "$LAN_CIDR" to any port 443 proto tcp comment 'HTTPS (LAN)'
ufw allow from "$LAN_CIDR" to any port 80 proto tcp comment 'HTTP->HTTPS redirect (LAN)'
ufw allow from 172.16.0.0/12 to any port 11434 proto tcp comment 'Docker -> Ollama'
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
ufw status verbose

echo
echo "[주의] 도커의 -p 로 공개한 포트는 ufw를 우회합니다."
echo "       Open WebUI는 127.0.0.1 에만 바인딩하고(install.sh 기본값) Caddy(443)로만 접속하세요."
docker ps --format 'table {{.Names}}\t{{.Ports}}' 2>/dev/null | grep -v '127.0.0.1' | grep -- '->' \
  && echo "[경고] 위 컨테이너는 외부 인터페이스에 포트가 열려 있습니다." || echo "[OK] 외부에 직접 열린 컨테이너 포트 없음"
