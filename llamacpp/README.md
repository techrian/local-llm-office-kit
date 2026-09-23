# llama.cpp 고급 구성 (전자책 11장)

RTX 3090(24GB) + V100(32GB)처럼 **세대가 다른 GPU 두 장**으로 27B 모델을 **Q8 · 256K 문맥**으로 돌린 구성을 재현하는 스크립트입니다.
저자 환경 실측: 생성 속도 초당 48~55토큰 (내장 MTP 사용).

| 파일 | 용도 |
|---|---|
| `build.sh` | GPU 아키텍처 자동 감지 + NCCL/FA/CUDA Graph 빌드 |
| `run-server.sh` | 환경 변수로 모델·GPU·분할·문맥·MTP를 바꿔 실행 |
| `llama-server.service` | systemd 상시 서비스 예시 |

## 순서

```bash
sudo apt install -y build-essential cmake git libnccl2 libnccl-dev
bash build.sh
# 1) 최소 구성으로 먼저 확인 (문제 원인 좁히기)
MODEL=~/llm/gguf/qwen3.8/Qwen3.8-27B-UD-Q8_K_XL.gguf CTX=8192 MTP=0 bash run-server.sh
# 2) 정상이면 256K + MTP
MODEL=~/llm/gguf/qwen3.8/Qwen3.8-27B-UD-Q8_K_XL.gguf bash run-server.sh
```

## 자주 만나는 문제

| 증상 | 해결 |
|---|---|
| "Loading model"에서 멈춤, GPU 사용률 100%인데 전력 40~50W | 동기화 대기(busy-wait). 최소 구성으로 재현 → GPU 조합 변경 또는 `SPLIT=layer` |
| 대기 중 CPU 한 코어 100% | `--poll 0`, `GGML_CUDA_BLOCKING_SYNC=1` (run-server.sh 기본 적용) |
| HTTP 500 `Unexpected reasoning effort max` | 클라이언트 설정을 `xhigh`로 (Qwen3.8 템플릿은 low/medium/xhigh만 허용) |
| 별도 MTP 모델 사용 시 `GGML_ASSERT ... SPLIT_AXIS_1` 크래시 | 텐서 분할에서는 별도 draft 모델 대신 내장 MTP(`--spec-type draft-mtp`)만 사용 |
| `CORS ... no API key` 경고 | `HOST=127.0.0.1` 유지, 외부 접속 시 `API_KEY` 필수 |

> V100(sm_70)을 쓴다면 CUDA 12.x에 머무르세요. PyTorch 도구를 함께 쓸 경우 2.10 + cu128이 V100을 지원하는 마지막 조합입니다(2026년 9월 기준).
> 검열 해제(uncensored) 파생 모델은 사내 서비스에 쓰지 말고, 공식 또는 원본 기반 양자화본(예: Unsloth UD)을 쓰세요.
