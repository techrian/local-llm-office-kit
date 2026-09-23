"""메일·문서에서 정해진 항목을 JSON으로 추출 (견적 요청 예시)

사용 예:
  python extract_json.py mail.txt
  echo "한빛전자 김민수입니다. 미터 200대 견적 부탁드립니다" | python extract_json.py -
"""
import json, sys
from common import client, MODEL

KEYS = ["company", "contact", "item", "quantity", "due"]
SYSTEM = ("메일에서 정보를 추출해 JSON 객체 하나로만 답하세요. 키: " + ", ".join(KEYS) +
          ". 메일에 없는 값은 null. 설명 문장 금지.")


def extract(text: str) -> dict:
    r = client().chat.completions.create(
        model=MODEL, temperature=0,
        response_format={"type": "json_object"},
        messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": text}])
    data = json.loads(r.choices[0].message.content)
    missing = [k for k in KEYS if k not in data]
    if missing:  # 시스템에 넣기 전 반드시 검증
        raise ValueError(f"누락된 키: {missing}")
    return data


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "-"
    text = sys.stdin.read() if src == "-" else open(src, encoding="utf-8").read()
    print(json.dumps(extract(text), ensure_ascii=False, indent=2))
