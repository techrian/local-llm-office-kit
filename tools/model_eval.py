"""후보 모델 10문항 비교 테스트 → CSV로 저장 (엑셀에서 점수 매기기)

사용 예:
  python model_eval.py --models qwen3:32b gpt-oss:20b
  python model_eval.py --models qwen3:32b --questions my_questions.txt
    (my_questions.txt : 한 줄에 질문 하나. 우리 회사 실제 업무로 바꿔 쓰세요)
결과: eval_YYYYMMDD_HHMM.csv (모델, 질문, 답변, 소요초, tok/s, 점수(빈칸))
"""
import argparse, csv, time, datetime
from common import client

DEFAULT_Q = [
    "다음 회의 내용을 3줄로 요약해 줘: 다음 달 신제품 출시 일정을 2주 미루기로 했다. 원인은 부품 수급 지연이다. 마케팅팀은 보도자료 일정을 조정하고, 영업팀은 주요 고객 3곳에 먼저 알린다.",
    "배송이 일주일 늦어져 화가 난 고객에게 보낼 정중한 사과 메일 초안을 써 줘.",
    "1월 매출 1,200만 원, 2월 1,380만 원, 3월 1,150만 원이다. 월별 증감률을 계산해 줘.",
    "다음 문장을 자연스러운 영어로 번역해 줘: 본 제품은 정격 전압 DC 48V에서 최대 효율 97%를 달성합니다.",
    "엑셀에서 =VLOOKUP(A2,B:C,3,FALSE) 가 #REF! 오류를 내는 이유는?",
    "연차는 입사 1년 미만일 때 1개월 개근 시 1일씩 발생한다. 입사 5개월 차 개근자의 연차는 며칠인가? 근거를 들어 설명해 줘.",
    "다음 파이썬 코드의 버그를 찾아 줘: def avg(xs): return sum(xs)/len(xs) if xs else sum(xs)/len(xs)",
    "우리 회사가 사내 AI 서버를 도입했다는 짧은 사내 공지문을 써 줘.",
    "2031년 우리 회사 매출은 얼마였어?",
    "계약서에서 위약금 조항을 찾을 때 확인해야 할 핵심 요소 5가지를 알려 줘.",
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", nargs="+", required=True)
    ap.add_argument("--questions")
    a = ap.parse_args()
    qs = DEFAULT_Q
    if a.questions:
        qs = [l.strip() for l in open(a.questions, encoding="utf-8") if l.strip()]
    cli = client()
    out = f"eval_{datetime.datetime.now():%Y%m%d_%H%M}.csv"
    with open(out, "w", newline="", encoding="utf-8-sig") as fp:
        w = csv.writer(fp)
        w.writerow(["모델", "번호", "질문", "답변", "소요(초)", "tok/s", "점수(1~5)"])
        for m in a.models:
            print(f"\n=== {m} ===")
            for i, q in enumerate(qs, 1):
                t = time.perf_counter()
                try:
                    r = cli.chat.completions.create(model=m, messages=[{"role": "user", "content": q}], temperature=0.3)
                    ans = r.choices[0].message.content.strip()
                    toks = r.usage.completion_tokens if r.usage else 0
                except Exception as e:  # 모델 이름 오류 등
                    ans, toks = f"[오류] {e}", 0
                dt = time.perf_counter() - t
                w.writerow([m, i, q, ans, f"{dt:.1f}", f"{toks / dt:.1f}" if dt else "", ""])
                fp.flush()
                print(f"  Q{i:>2} {dt:5.1f}초  {ans[:60].replace(chr(10), ' ')}...")
    print(f"\n[OK] 저장: {out}  (9번은 '모른다'고 답해야 정답입니다)")


if __name__ == "__main__":
    main()
