"""폴더 안 문서(.txt, .md)를 일괄 요약·분류해 CSV로 저장

사용 예:
  python summarize_folder.py ./inbox
  python summarize_folder.py "C:\\업무\\고객문의" --out 요약.csv
"""
import argparse, csv, pathlib
from common import client, MODEL

SYSTEM = ("당신은 사내 문서 요약 담당입니다. 다음 형식으로만 답하세요.\n"
          "요약: (3줄 이내)\n분류: 견적/불만/기술문의/기타 중 하나\n긴급도: 상/중/하")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--out", default="summary.csv")
    ap.add_argument("--max-chars", type=int, default=12000)
    a = ap.parse_args()
    cli = client()
    files = sorted([p for p in pathlib.Path(a.folder).rglob("*") if p.suffix.lower() in (".txt", ".md")])
    if not files:
        print("요약할 .txt/.md 파일이 없습니다."); return
    with open(a.out, "w", newline="", encoding="utf-8-sig") as fp:  # 엑셀 한글 호환
        w = csv.writer(fp)
        w.writerow(["파일", "AI 요약"])
        for f in files:
            text = f.read_text(encoding="utf-8", errors="ignore")[: a.max_chars]
            r = cli.chat.completions.create(
                model=MODEL, temperature=0.2,
                messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": text}])
            w.writerow([f.name, r.choices[0].message.content.strip()])
            print("완료:", f.name)
    print(f"[OK] {len(files)}건 → {a.out}")


if __name__ == "__main__":
    main()
