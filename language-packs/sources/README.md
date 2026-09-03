# 언어팩 원본과 재현 방법

`tufs-core-alignment.json`은 도쿄외국어대 TUFS Open Language Resources의
24개 언어 기초 어휘 모듈 중 한국어와 `en`, `de`, `fr`, `es`, `ja`,
`zh`를 각각 같은 `classified_id`로 연결한 자료다.

- 원본: https://www.coelang.tufs.ac.jp/mt/vmod/
- 라이선스: CC BY 4.0
- 인용: Kawaguchi, Yuji. 2007. *Foundations of Center of Usage-Based
  Linguistic Informatics (UBLI).*
- 가공: 모든 언어의 교집합이 아니라 한국어–학습 언어 짝별 교집합을
  보존, 표준 표제어 우선, 공백 NFKC 정규화, 일본어의 안전하게
  대응되는 가나와 중국어 병음 분리

TUFS zip을 풀어 얻은 PostgreSQL dump에서 원본 정렬 파일을 다시
만들려면 `pgdumplib`을 설치한 후 아래 명령을 사용한다.

```powershell
python tool/extract-tufs-pairwise.py --input-root <풀어 둔 목록> `
  --output language-packs/sources/tufs-core-alignment.json
```

정렬 원본을 반영해 실제 팩을 다시 만들고 카탈로그를 갱신하려면 저장소 루트에서
다음을 실행한다.

```powershell
node tool/refresh-language-packs.mjs --refresh
node tool/build-language-pack-catalog.mjs
```

## 영어 시험 어휘

- `ngsl-spoken-1.2.txt`: NGSL-Spoken 1.2의 721개 표제어. 일상 말하기
  빈도가 높은 공개 목록이라 TOSS 대비 팩의 기준으로 사용한다.
  원본은 https://www.newgeneralservicelist.com/ngsl-spoken 이며
  CC BY-SA 4.0이다.
- `toeic-service-list-1.2.txt`: TOEIC Service List 1.2의 1,250개 표제어.
  원본은 https://charliebrownecompany.squarespace.com/toeic-service-list 이며
  CC BY-SA 4.0이다.
- 한국어 뜻은 TUFS 대응어와 한국어 위키낱말사전의 영어 표제어를 우선
  참고하고, 시험 문맥과 맞지 않거나 빠진 뜻은 별도 검수 파일로 교정한다.
  한글 발음은 영어 철자만 보고 추측하지 않으며 앱의 `en-US` 음성으로
  원문을 듣는다.

두 팩을 다시 만들 때는 아래 명령을 추가로 실행한다.

```powershell
node tool/refresh-english-exam-packs.mjs --refresh
node tool/build-language-pack-catalog.mjs
```
