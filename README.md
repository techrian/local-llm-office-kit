# local-llm-office-kit

**회사 데이터를 밖으로 내보내지 않는 사내 AI** — 중소기업용 로컬 LLM 구축 스크립트 모음

Ollama + Open WebUI 기반의 "사내 ChatGPT"를 **Linux(Ubuntu)** 와 **Windows** 에서 명령 한 줄로 설치하고,
방화벽·HTTPS·백업·점검·부하 테스트까지 바로 쓸 수 있게 정리했습니다.

> 이 저장소는 전자책 『중고 GPU 두 장으로 Qwen3.8-27B 사내 AI 구축 실전기』(RTX 3090 + V100 · Q8 · 256K)의 실습 자료입니다.
> 스크립트만으로도 동작하지만, 장비 선택·모델 라이선스·RAG 문서 준비·운영 지침 같은 "왜 이렇게 하는지"는 전자책에 자세히 설명돼 있습니다.

---

## 빠른 시작

### Linux (Ubuntu 22.04 / 24.04, NVIDIA GPU)

```bash
git clone https://github.com/techrian/local-llm-office-kit.git
cd local-llm-office-kit/linux
sudo bash install.sh                    # Ollama + Docker + Open WebUI + 첫 모델
sudo bash firewall.sh 192.168.0.0/24    # 사내 대역만 허용
sudo bash caddy-setup.sh ai.company.local   # HTTPS 적용
sudo bash backup.sh --install-cron      # 매일 03:00 백업
bash healthcheck.sh                     # 상태 점검
```

드라이버가 없다면 `sudo bash install.sh --install-driver` → 재부팅 → 다시 `sudo bash install.sh`

### Windows 10 / 11

PowerShell을 **관리자 권한으로 실행**한 뒤:

```powershell
git clone https://github.com/techrian/local-llm-office-kit.git   # 또는 ZIP 다운로드 후 압축 해제
cd local-llm-office-kit\windows
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install.ps1                  # 이 PC 전용 설치
.\install.ps1 -Lan             # 사내 다른 PC에서도 접속 (시범 5~10명)
.\firewall.ps1                 # Ollama 외부 노출 차단
.\backup.ps1 -InstallTask      # 매일 03:00 백업
.\healthcheck.ps1
```

Docker Desktop이 실행 중이면 Docker 방식, 없으면 Python(uv) 방식으로 Open WebUI를 설치합니다.

설치가 끝나면 브라우저에서 `http://127.0.0.1:3000` → **첫 번째로 가입한 계정이 관리자**가 됩니다.

---

## 구성

```
linux/            Ubuntu 설치·방화벽·HTTPS·백업·복원·업데이트·점검 스크립트
windows/          Windows PowerShell 설치·방화벽·백업·업데이트·점검 스크립트
llamacpp/         이기종 GPU(3090+V100) llama.cpp 빌드·실행·systemd (27B Q8 · 256K 구성)
compose/          docker-compose (Open WebUI + LiteLLM + 선택 vLLM), Caddyfile 예시
tools/            모델 비교 테스트, 부하 테스트, 문서 일괄 요약, JSON 추출 (Python)
tools/prompts/    업무용 시스템 프롬프트 프리셋
remote-support/   1회성 원격 지원 (RustDesk 포터블, 임시 SSH 계정, Tailscale) 및 회수 스크립트
docs/             명령어 모음, 문제 해결, 원격 컨설팅 사전 점검표
```

## 고급: 중고 GPU 두 장으로 Qwen3.8-27B · Q8 · 256K (llama.cpp)

저자 서버(RTX 3090 24GB + V100 32GB, 텐서 분할)에서 Qwen3.8-27B Q8을 256K 문맥으로 띄워 **초당 48~55토큰**을 낸 구성입니다.

```bash
cd llamacpp
bash build.sh                                   # GPU 세대 자동 감지 빌드 (sm_70 + sm_86 등)
MODEL=~/llm/gguf/qwen3.8/Qwen3.8-27B-UD-Q8_K_XL.gguf CTX=8192 MTP=0 bash run-server.sh   # 최소 구성 확인
MODEL=~/llm/gguf/qwen3.8/Qwen3.8-27B-UD-Q8_K_XL.gguf bash run-server.sh                  # 256K + 내장 MTP
```

자세한 설명과 삽질 기록은 [`llamacpp/README.md`](llamacpp/README.md)와 전자책 11장에 있습니다.

## Linux vs Windows 어떤 걸 쓸까

| | Linux (Ubuntu) | Windows |
|---|---|---|
| 추천 용도 | 부서·전사 서버 (10명 이상, 상시 운영) | 개인·소규모 시범 (1~10명), 기존 PC 활용 |
| 설치 난이도 | 스크립트 한 줄 | 스크립트 한 줄 |
| 성능 | 최상 (vLLM 사용 가능) | 좋음 (Ollama), vLLM은 WSL2 필요 |
| 원격 관리 | SSH | RustDesk / 원격 데스크톱 |
| HTTPS·방화벽 | Caddy + ufw 스크립트 제공 | Windows 방화벽 스크립트 제공 |

## 도구 사용법 (Python 3.10+)

```bash
cd tools
pip install -r requirements.txt

# 후보 모델 10문항 비교 → CSV (엑셀에서 점수 입력)
python model_eval.py --models qwen3:32b gpt-oss:20b

# 동시 사용자 부하 테스트
python bench.py --users 1 5 10

# 폴더 문서 일괄 요약
python summarize_folder.py ./inbox --out summary.csv

# 메일에서 항목 추출(JSON)
python extract_json.py mail.txt
```

서버 주소·모델은 환경 변수로 바꿉니다: `LLM_BASE_URL`(기본 Ollama `http://127.0.0.1:11434/v1`), `LLM_API_KEY`, `LLM_MODEL`
Windows PowerShell에서는 `$env:LLM_MODEL="gpt-oss:20b"` 처럼 지정합니다.

## 보안 원칙 (반드시 읽어 주세요)

- Ollama API(11434)에는 **인증이 없습니다.** 공유기 포트포워딩으로 인터넷에 열지 마세요.
- Linux에서 도커 `-p` 포트는 ufw를 우회합니다. 이 킷은 Open WebUI를 기본으로 `127.0.0.1`에만 열고 Caddy(443)로 공개합니다.
- 원격 지원은 **1회성**으로만: 작업 후 `remote-support/` 의 정리·회수 스크립트를 실행하세요.
- 모델을 내려받기 전에 **라이선스 원문**(상업 이용 가능 여부)을 확인하세요.

## 원격 설치 컨설팅

직접 설치가 어렵다면 크몽 상품의 **프리미엄(60분 원격 컨설팅)** 에서 RustDesk 또는 임시 SSH로 접속해 설치·테스트까지 진행해 드립니다.
절차와 보안 원칙은 [`remote-support/README.md`](remote-support/README.md) 를 참고하세요.

## 라이선스

스크립트와 도구는 MIT 라이선스입니다. 설치되는 각 소프트웨어(Ollama, Open WebUI, LiteLLM, vLLM, Caddy, RustDesk, Tailscale)와 모델은 각자의 라이선스를 따릅니다.
이 스크립트는 "있는 그대로" 제공되며, 운영 환경 적용 전 테스트 환경에서 먼저 확인하세요.
