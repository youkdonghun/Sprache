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
