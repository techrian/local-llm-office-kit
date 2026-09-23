#!/usr/bin/env bash
# =============================================================================
# 1회성 원격 지원 : 임시 SSH 계정 발급 (고객 Linux 서버에서 실행)
#   - 컨설턴트의 "공개키"로만 로그인 가능 (비밀번호 로그인 불가)
#   - 지정한 시간(기본 4시간)이 지나면 계정이 자동 삭제됩니다
#
# 사용법:
#   sudo bash ssh-temp-access.sh "ssh-ed25519 AAAA... consultant"   [유효시간(시간)=4]
#   sudo bash ssh-temp-access.sh ./consultant.pub 6
# 즉시 회수: sudo bash ssh-revoke.sh
#
# ※ 서버가 공유기 뒤(사설 IP)에 있으면 외부에서 바로 접속할 수 없습니다.
#   → 같은 사내망 PC의 RustDesk 세션 안에서 SSH 하거나, tailscale-onetime.sh 를 사용하세요.
#   ※ 공유기 포트포워딩으로 22번을 인터넷에 여는 방식은 권장하지 않습니다.
# =============================================================================
set -euo pipefail
USER_NAME="llm-support"
KEY="${1:-}"; HOURS="${2:-4}"
[[ $EUID -eq 0 ]] || { echo "sudo로 실행하세요"; exit 1; }
[[ -n "$KEY" ]] || { sed -n '2,16p' "$0"; exit 1; }
[[ -f "$KEY" ]] && KEY="$(cat "$KEY")"
if ! [[ "$KEY" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256)\  ]]; then
  echo "공개키 형식이 아닙니다 (ssh-ed25519 로 시작해야 함). 개인키를 받으면 절대 안 됩니다."; exit 1
fi
[[ "$HOURS" =~ ^[0-9]+$ ]] && [[ "$HOURS" -ge 1 && "$HOURS" -le 72 ]] || { echo "유효시간은 1~72 시간"; exit 1; }

command -v sshd >/dev/null || { apt-get update -y && apt-get install -y openssh-server; }
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd

id "$USER_NAME" >/dev/null 2>&1 || useradd -m -s /bin/bash -c "Temporary LLM support" "$USER_NAME"
passwd -l "$USER_NAME" >/dev/null                       # 비밀번호 로그인 잠금
install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
echo "$KEY" > "/home/$USER_NAME/.ssh/authorized_keys"
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.ssh/authorized_keys"
chmod 600 "/home/$USER_NAME/.ssh/authorized_keys"

# 설치 작업용 sudo 권한 (회수 시 함께 삭제)
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USER_NAME"
chmod 440 "/etc/sudoers.d/$USER_NAME"
visudo -cf "/etc/sudoers.d/$USER_NAME" >/dev/null

# 계정 만료일(이중 안전장치) + 자동 회수 타이머
chage -E "$(date -d "+$((HOURS/24+1)) days" +%F)" "$USER_NAME"
REVOKE="$(cd "$(dirname "$0")" && pwd)/ssh-revoke.sh"
install -m 700 "$REVOKE" /usr/local/sbin/llm-support-revoke
systemctl stop llm-support-revoke.timer 2>/dev/null || true
systemd-run --unit=llm-support-revoke --on-active="${HOURS}h" /usr/local/sbin/llm-support-revoke >/dev/null

# 작업 기록 남기기 (고객이 나중에 확인 가능)
echo "$(date '+%F %T') 임시 계정 발급, ${HOURS}시간 후 자동 회수" >> /var/log/llm-support.log

IP=$(hostname -I | awk '{print $1}')
echo
echo "[OK] 임시 계정 발급 완료"
echo "  계정     : $USER_NAME  (공개키 로그인만 허용)"
echo "  접속     : ssh $USER_NAME@$IP"
echo "  자동 회수: $(date -d "+${HOURS} hours" '+%F %H:%M') (지금부터 ${HOURS}시간 후)"
echo "  즉시 회수: sudo bash $(dirname "$0")/ssh-revoke.sh"
echo "  접속 기록: sudo journalctl -u ssh --since today | grep $USER_NAME"
