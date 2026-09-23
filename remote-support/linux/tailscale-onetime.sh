#!/usr/bin/env bash
# =============================================================================
# 공유기 뒤(사설 IP)에 있는 Linux 서버를 1회성으로 원격 지원받을 때
#   Tailscale(무료 개인 요금제)로 암호화 터널을 만든 뒤, 컨설턴트에게 이 서버만 "공유"합니다.
#   포트포워딩 없이, 작업이 끝나면 로그아웃·삭제로 완전히 끊을 수 있습니다.
#
# 사용법:
#   sudo bash tailscale-onetime.sh up      # 설치 + 로그인(화면에 나오는 주소를 브라우저로 열어 승인)
#   sudo bash tailscale-onetime.sh down    # 작업 종료: 연결 해제 + 로그아웃
#   sudo bash tailscale-onetime.sh purge   # 프로그램까지 삭제
# =============================================================================
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "sudo로 실행하세요"; exit 1; }
case "${1:-}" in
  up)
    command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
    systemctl enable --now tailscaled
    tailscale up --hostname "llm-server-support"
    echo
    echo "[OK] Tailscale 연결됨. 이 서버의 Tailscale 주소: $(tailscale ip -4 | head -1)"
    echo "다음 단계 (고객):"
    echo "  1) https://login.tailscale.com/admin/machines 접속"
    echo "  2) 'llm-server-support' 옆 [...] → Share → 컨설턴트 이메일 입력"
    echo "  3) 그다음 ssh-temp-access.sh 로 임시 계정을 발급하세요."
    echo "작업 종료 후: sudo bash $0 down  (공유도 관리 화면에서 해제)"
    ;;
  down)
    tailscale down || true
    tailscale logout || true
    systemctl disable --now tailscaled || true
    echo "[OK] Tailscale 연결 해제 및 로그아웃. 관리 화면에서 기기 공유도 삭제하세요." ;;
  purge)
    tailscale logout 2>/dev/null || true
    apt-get remove -y --purge tailscale && rm -rf /var/lib/tailscale
    echo "[OK] Tailscale 삭제 완료" ;;
  *) sed -n '2,12p' "$0" ;;
esac
