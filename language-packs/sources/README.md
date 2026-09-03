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
- `ngsl-1.2-teaching.csv`: NGSL 1.2의 2,809개 교육용 표제어.
  원본은 https://www.newgeneralservicelist.com/new-general-service-list 이며
  CC BY-SA 4.0이다.
- `ngsl-gr-rank.csv`: NGSL-GR의 빈도 순위 표제어. TOSS 확장 단어의
  우선순위를 정하는 데 사용한다. 원본은
  https://www.newgeneralservicelist.com/ngsl-graded-reader 이며 CC BY-SA 4.0이다.
- `bsl-1.2-teaching.csv`: Business Service List 1.2의 1,744개 교육용
  표제어. TOEIC 확장 단어의 업무 우선순위를 정하는 데 사용한다. 원본은
  https://www.newgeneralservicelist.com/business-service-list 이며 CC BY-SA 4.0이다.
- 한국어 뜻은 TUFS 대응어와 한국어 위키낱말사전의 영어 표제어를 우선
  참고하고, 빠진 뜻은 CC BY-SA 4.0인 Open English-Korean Dictionary의
  부분 추출본으로 보완한다. 시험 문맥과 맞지 않거나 낡은 뜻은
  `english-exam-expanded-overrides.json`에서 직접 교정한다.
  `english-exam-phrases.json`의 회화·업무 표현은 Sprache가 직접 정리했다.
  한글 발음은 영어 철자만 보고 추측하지 않으며 앱의 `en-US` 음성으로
  원문을 듣는다.

`english-korean-wiktionary-subset.json`은 Kaikki.org가 추출한 한국어
위키낱말사전 영어 항목의 부분본이다. CC BY-SA 4.0·GFDL 조건과 원 저작자
표시는 https://kaikki.org/kowiktionary/영어/ 와
https://ko.wiktionary.org/ 에서 확인할 수 있다.
`english-korean-open-dictionary-subset.json`은
https://github.com/jhseo1211/open-english-korean-dict 의 2026-09-03
스냅샷(`92cbfe63deee1ccead2c42677027d8b4a305b2c7`)에서 이번 목록에 필요한
표제어만 추출했으며 CC BY-SA 4.0이다.

두 팩을 다시 만들 때는 아래 명령을 추가로 실행한다.

```powershell
node tool/refresh-english-exam-packs.mjs --refresh
node tool/build-language-pack-catalog.mjs
```

원본 사전이 갱신되었을 때 부분 추출본을 재생성하려면 다음 명령을 사용한다.

```powershell
node tool/refresh-english-korean-wiktionary-source.mjs --input <Kaikki JSONL>
node tool/refresh-open-english-korean-source.mjs --input <words.json>
```
