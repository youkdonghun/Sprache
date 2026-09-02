# 언어팩 원본과 재현 방법

`tufs-core-alignment.json`은 도쿄외국어대 TUFS Open Language Resources의
24개 언어 기초 어휘 모듈 중 `ko`, `en`, `de`, `fr`, `es`, `ja`, `zh`를
같은 `classified_id`로 연결한 자료다.

- 원본: https://www.coelang.tufs.ac.jp/mt/vmod/
- 라이선스: CC BY 4.0
- 인용: Kawaguchi, Yuji. 2007. *Foundations of Center of Usage-Based
  Linguistic Informatics (UBLI).*
- 가공: 일곱 모듈에 모두 존재하고 표현이 비어 있지 않은 444개 개념만 보존,
  공백 NFKC 정규화, 중국어 표기와 병음 분리

`bundled-word-terms.json`은 Flutter 내장 어휘에서 생성한다. 아래 명령으로
내장 자료와 GitHub 팩의 중복 제외 기준을 갱신한다.

```powershell
cd apps/client
dart run tool/export_bundled_word_index.dart
```

두 원본을 반영해 실제 팩을 다시 만들고 카탈로그를 갱신하려면 저장소 루트에서
다음을 실행한다.

```powershell
node tool/refresh-language-packs.mjs --refresh
node tool/build-language-pack-catalog.mjs
```
