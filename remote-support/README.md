# 1회성 원격 지원 가이드

프리미엄 원격 컨설팅(60분)에서 컨설턴트가 고객 PC·서버에 접속해 로컬 LLM 환경을 설치·테스트할 때 쓰는 절차와 스크립트입니다.
**모든 접속은 1회성이며, 작업이 끝나면 고객이 직접 회수합니다.**

## 어떤 방식을 쓰나

| 고객 환경 | 방식 | 스크립트 |
|---|---|---|
| Windows PC (화면 있음) | RustDesk 포터블 (설치 없음, 일회용 비밀번호) | `windows/rustdesk-onetime.ps1` → 종료 후 `windows/rustdesk-cleanup.ps1` |
| Linux 데스크톱 | RustDesk (.deb / AppImage) 또는 아래 SSH | rustdesk.com 에서 받아 실행 |
| Linux 서버 (같은 사내망에 Windows PC 있음) | Windows PC에 RustDesk 접속 → 그 PC에서 서버로 SSH | `linux/ssh-temp-access.sh` → `linux/ssh-revoke.sh` |
| Linux 서버 단독 (공유기 뒤) | Tailscale 기기 공유 + 임시 SSH 계정 | `linux/tailscale-onetime.sh up` + `ssh-temp-access.sh` → `ssh-revoke.sh` + `tailscale-onetime.sh down` |

> 공유기 포트포워딩으로 22번(SSH)이나 원격 데스크톱 포트를 인터넷에 여는 방식은 **사용하지 않습니다.**

## 진행 순서

1. **사전 합의 (크몽 메시지)**: 작업 범위, 일정(60분), 접속 방식, 설치할 소프트웨어 목록 확인
2. **사전 점검 (고객)**: `docs/precheck.md` 항목 확인 (GPU 모델, 디스크 여유, 관리자 권한, 중요 자료 백업)
3. **접속 (고객이 시작)**: 위 표의 스크립트 실행 → ID/일회용 비밀번호 전달 (크몽 메시지로)
4. **작업 (고객 참관)**: 설치 → 모델 테스트 → Open WebUI 접속 확인 → 결과 설명
5. **종료·회수 (고객이 실행)**: 정리 스크립트 실행, 비밀번호 변경 권장
6. **작업 보고서**: 설치 내역·설정값·다음 할 일을 크몽 메시지로 전달

## 보안 원칙

- 고객은 **개인키, 계정 비밀번호, 공인인증서를 절대 전달하지 않습니다.** 컨설턴트는 공개키(ssh-ed25519 …)만 제공합니다.
- 일회용 비밀번호는 세션마다 바뀌며, RustDesk를 닫으면 접속이 즉시 끊깁니다.
- 임시 SSH 계정은 기본 4시간 후 **자동 삭제**되며, `ssh-revoke.sh`로 즉시 회수할 수 있습니다.
- 작업 중 고객 화면의 개인 파일·메일·메신저는 열지 않습니다. 필요 시 고객에게 먼저 요청합니다.
- 접속 기록: RustDesk는 고객 화면에 연결 상태가 표시되고, SSH는 `/var/log/llm-support.log`와 `journalctl -u ssh`에 남습니다.
