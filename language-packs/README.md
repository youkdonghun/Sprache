# Sprache GitHub 언어팩

이 폴더는 앱을 다시 배포하지 않고 단어·문장 팩을 추가하는 공개 공간이다.
`packs/`에 규격을 지킨 JSON 파일을 올리면 GitHub 워크플로가 크기, 항목 수와
SHA-256을 계산해 `catalog.json`을 갱신한다. 앱의 `자료실 → 추가 → 언어팩 받기`는
이 카탈로그를 읽는다.

## 새 팩 등록

1. `templates/example-language-pack.json`을 복사해
   `packs/<pack-id>.json`으로 저장한다.
2. `id`, 언어, 버전, 라이선스, 출처 표시와 `items`를 채운다.
3. 같은 학습 항목은 다음 버전에서도 같은 `id`를 유지하고, 교정할 때
   `version`과 `revision`을 올린다.
4. `node tool/build-language-pack-catalog.mjs`로 로컬 검증할 수 있다.
5. pack JSON만 `main`에 올리면 `Update language-pack catalog`가
   `catalog.json`을 자동 갱신한다.

카탈로그를 직접 손으로 편집하지 않는다. 앱은 다운로드한 바이트가 카탈로그의
크기와 SHA-256에 정확히 일치할 때만 기존 가져오기 검토 화면으로 넘긴다.

## 필수 규칙

- 파일당 하나의 언어만 사용한다: `ko`, `en`, `ja`, `de`, `fr`, `es`, `zh-Hans`.
- 최대 20MB, 20,000행이다.
- 모든 항목에 안정적인 `id`, `type`, `term`, `meaning`이 필요하다.
- 문장은 `sentence_tokens`를 `|`로 구분해 명시한다.
- 일본어는 `kana`·`romaji`, 중국어는 `pinyin`을 권장한다.
- 타인의 자료는 재배포 가능한 라이선스와 정확한 attribution을 기록한다.
- 비밀값, 개인정보, OAuth 토큰, 유료 교재 원문을 넣지 않는다.

설치된 팩은 사용자 자료로 SQLite에 저장되고 Google Drive 동기화 대상에
포함된다. 팩 원본 JSON 자체는 Drive에 복제하지 않는다. 새 버전을 받을 때에도
사용자가 검토 화면에서 변경점을 확인하고 `반영`해야 데이터가 바뀐다.

세부 형식은 `schema/language-pack.schema.json`과
`schema/catalog.schema.json`을 기준으로 한다.
