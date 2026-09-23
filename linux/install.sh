#!/usr/bin/env bash
# =============================================================================
# local-llm-office-kit : Linux(Ubuntu 22.04/24.04) 원클릭 설치 스크립트
#   - NVIDIA 드라이버 확인(없으면 설치 안내/자동 설치)
#   - Ollama 설치 및 서비스 설정
#   - Docker 설치, ai-net 네트워크, Open WebUI 실행
#   - 첫 모델 내려받기
#
# 사용법:
#   sudo bash install.sh                      # 기본값(서버 내부 전용, qwen3:32b)
#   sudo bash install.sh --model gpt-oss:20b  # 첫 모델 지정
#   sudo bash install.sh --lan                # Open WebUI를 사내망에 바로 공개(시범용)
#   sudo bash install.sh --no-webui           # Ollama만 설치
#   sudo bash install.sh --install-driver     # NVIDIA 드라이버 자동 설치 포함
# =============================================================================
set -euo pipefail

MODEL="qwen3:32b"
LAN=0
WEBUI=1
INSTALL_DRIVER=0
WEBUI_NAME="${WEBUI_NAME:-우리회사 AI}"
WEBUI_PORT="${WEBUI_PORT:-3000}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --lan) LAN=1; shift ;;
    --no-webui) WEBUI=0; shift ;;
    --install-driver) INSTALL_DRIVER=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

c_ok()   { echo -e "\e[32m[OK]\e[0m $*"; }
c_info() { echo -e "\e[36m[..]\e[0m $*"; }
c_warn() { echo -e "\e[33m[!!]\e[0m $*"; }
c_err()  { echo -e "\e[31m[XX]\e[0m $*"; }

if [[ $EUID -ne 0 ]]; then c_err "sudo로 실행하세요: sudo bash $0"; exit 1; fi
REAL_USER="${SUDO_USER:-root}"

# --- 0. OS 확인 --------------------------------------------------------------
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  c_warn "Ubuntu가 아닙니다(${PRETTY_NAME}). 계속 진행하지만 일부 단계가 실패할 수 있습니다."
fi
c_info "OS: ${PRETTY_NAME}"

apt-get update -y
apt-get install -y curl ca-certificates git htop jq >/dev/null
apt-get install -y nvtop >/dev/null 2>&1 || true

# --- 1. NVIDIA 드라이버 --------------------------------------------------------
if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
  c_ok "NVIDIA 드라이버 확인됨"
  nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader
else
  if [[ $INSTALL_DRIVER -eq 1 ]]; then
    c_info "NVIDIA 드라이버 설치 중 (ubuntu-drivers autoinstall)"
    apt-get install -y ubuntu-drivers-common >/dev/null
    ubuntu-drivers autoinstall
    c_warn "드라이버 설치 완료. 재부팅 후 이 스크립트를 다시 실행하세요: sudo reboot"
    exit 0
  else
    c_warn "nvidia-smi가 동작하지 않습니다. GPU 없이(CPU) 진행하면 매우 느립니다."
    c_warn "드라이버를 설치하려면: sudo bash $0 --install-driver"
  fi
fi

# --- 2. Ollama ---------------------------------------------------------------
if command -v ollama >/dev/null; then
  c_ok "Ollama 이미 설치됨: $(ollama --version 2>/dev/null | head -1)"
else
  c_info "Ollama 설치 중"
  curl -fsSL https://ollama.com/install.sh | sh
fi

mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf <<'EOF'
[Service]
# 도커 컨테이너(Open WebUI)가 접속할 수 있도록 모든 인터페이스에서 대기
# (외부 차단은 firewall.sh 로 처리)
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_KEEP_ALIVE=30m"
Environment="OLLAMA_NUM_PARALLEL=4"
EOF
systemctl daemon-reload
systemctl enable --now ollama
systemctl restart ollama
sleep 3
curl -fsS http://127.0.0.1:11434/api/tags >/dev/null && c_ok "Ollama API 응답 확인 (포트 11434)"

# --- 3. 첫 모델 --------------------------------------------------------------
c_info "모델 내려받는 중: ${MODEL} (수 GB~수십 GB, 시간이 걸립니다)"
if ollama pull "${MODEL}"; then
  c_ok "모델 준비 완료: ${MODEL}"
else
  c_warn "모델 이름을 확인하세요(https://ollama.com/library). 나중에: ollama pull <모델>"
fi
ollama pull bge-m3 >/dev/null 2>&1 && c_ok "임베딩 모델(bge-m3) 준비 완료" || true

[[ $WEBUI -eq 0 ]] && { c_ok "Ollama 설치 완료 (--no-webui)"; exit 0; }

# --- 4. Docker ---------------------------------------------------------------
if command -v docker >/dev/null; then
  c_ok "Docker 이미 설치됨"
else
  c_info "Docker 설치 중"
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker
if [[ "$REAL_USER" != "root" ]]; then usermod -aG docker "$REAL_USER" || true; fi

docker network inspect ai-net >/dev/null 2>&1 || docker network create ai-net >/dev/null
c_ok "도커 네트워크 ai-net 준비"

# --- 5. Open WebUI -----------------------------------------------------------
BIND="127.0.0.1:${WEBUI_PORT}"
[[ $LAN -eq 1 ]] && BIND="${WEBUI_PORT}"

if docker ps -a --format '{{.Names}}' | grep -qx open-webui; then
  c_info "기존 open-webui 컨테이너를 새 설정으로 교체합니다(데이터 볼륨은 유지)"
  docker rm -f open-webui >/dev/null
fi

docker run -d \
  --name open-webui \
  --network ai-net \
  --restart always \
  -p "${BIND}:8080" \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -e WEBUI_NAME="${WEBUI_NAME}" \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main >/dev/null

c_info "Open WebUI 시작 대기 중 (최초 1~2분)"
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${WEBUI_PORT}" >/dev/null 2>&1; then break; fi
  sleep 3
done

IP=$(hostname -I | awk '{print $1}')
echo
c_ok "설치 완료!"
if [[ $LAN -eq 1 ]]; then
  echo "  브라우저 접속: http://${IP}:${WEBUI_PORT}"
  c_warn "시범용 공개 상태입니다. 운영 전 firewall.sh 와 caddy-setup.sh 를 실행하세요."
else
  echo "  서버 내부 전용: http://127.0.0.1:${WEBUI_PORT}"
  echo "  사내 공개(HTTPS): sudo bash caddy-setup.sh ai.company.local"
  echo "  임시 확인(SSH 터널): ssh -L ${WEBUI_PORT}:127.0.0.1:${WEBUI_PORT} ${REAL_USER}@${IP}"
fi
echo "  첫 번째로 가입하는 계정이 관리자가 됩니다. 지금 바로 가입하세요."
echo "  상태 점검: sudo bash healthcheck.sh"
