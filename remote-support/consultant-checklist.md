# 컨설턴트용 진행 체크리스트 (60분)

| 시간 | 할 일 |
|---|---|
| 0~5분 | 접속, 인사, 작업 범위·종료 방법 재확인, 고객 참관 확인 |
| 5~15분 | 환경 점검: GPU·드라이버(`nvidia-smi`), 디스크, 기존 설치(Ollama/Docker) |
| 15~35분 | 설치: `linux/install.sh` 또는 `windows/install.ps1` 실행, 모델 선정·다운로드 |
| 35~45분 | 테스트: `tools/model_eval.py`로 10문항 테스트, `tools/bench.py` 속도 측정 |
| 45~55분 | Open WebUI 관리자 가입, 기본 역할 pending, 맞춤 모델 1개 생성 시연 |
| 55~60분 | 결과 설명, 정리 스크립트 실행 안내, 종료 |

## 종료 후
- [ ] 고객이 정리 스크립트를 실행했는지 확인 (RustDesk cleanup / ssh-revoke / tailscale down)
- [ ] 컨설턴트 PC의 RustDesk 최근 연결 목록에서 고객 ID 삭제
- [ ] 작업 보고서 전달: 설치 버전, 모델, 속도(토큰/초), 접속 주소, 다음 할 일
- [ ] 고객 정보(ID, IP, 화면 캡처)는 보고서 전달 후 삭제
