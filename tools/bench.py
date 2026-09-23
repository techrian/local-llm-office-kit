"""동시 요청 부하 테스트: 동시 사용자 수별 평균 응답 시간과 초당 토큰 수 측정.

사용 예:
  python bench.py                        # 1, 5, 10명
  python bench.py --users 1 4 8 16 --max-tokens 300
  LLM_MODEL=gpt-oss:20b python bench.py
"""
import argparse, asyncio, time
from common import aclient, MODEL, BASE_URL

PROMPT = "신입 사원에게 회사 보안 수칙 5가지를 한국어로 설명해 줘."


async def one(cli, max_tokens):
    t = time.perf_counter()
    r = await cli.chat.completions.create(
        model=MODEL, messages=[{"role": "user", "content": PROMPT}], max_tokens=max_tokens)
    dt = time.perf_counter() - t
    toks = (r.usage.completion_tokens if r.usage else 0) or 0
    return dt, toks


async def run(n, max_tokens):
    cli = aclient()
    t = time.perf_counter()
    res = await asyncio.gather(*[one(cli, max_tokens) for _ in range(n)])
    wall = time.perf_counter() - t
    avg = sum(r[0] for r in res) / n
    toks = sum(r[1] for r in res)
    per_user = sum(r[1] / r[0] for r in res if r[0] > 0) / n
    print(f"동시 {n:>3}명 | 평균 응답 {avg:6.1f}초 | 사용자당 {per_user:5.1f} tok/s | 전체 처리량 {toks / wall:6.1f} tok/s")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--users", type=int, nargs="+", default=[1, 5, 10])
    ap.add_argument("--max-tokens", type=int, default=300)
    a = ap.parse_args()
    print(f"서버: {BASE_URL} / 모델: {MODEL}")
    print("※ 사용자당 10 tok/s 이상이면 쾌적, 5 미만이면 모델을 줄이거나 vLLM 검토")
    for n in a.users:
        asyncio.run(run(n, a.max_tokens))


if __name__ == "__main__":
    main()
