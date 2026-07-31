# 검증용 가져오기 샘플

이 폴더는 사용자 콘텐츠 가져오기 형식과 메타데이터 보존을 검증하기 위한 작은 예시만 둔다. 앱에 내장된 720개 다국어 입문 카탈로그와 검토 후 가져오는 범용 주제 팩은 `apps/client/lib/src/data` 및 `apps/client/assets/content`에 있으며 출처는 루트 `ATTRIBUTIONS.md`에서 관리한다.

지원 메타데이터:

- `korean_pronunciation`: 목표 표현을 한국어로 읽는 표기. 예: `헬로우`,
  `곤니치와`, `니 하오`
- `example_pronunciation`: 단어 행에서 함께 만드는 예문을 한국어로 읽는 표기
- `part_of_speech`: `noun`, `verb`, `adjective`, `adverb`, `pronoun`, `determiner`, `preposition`, `conjunction`, `interjection`, `auxiliary`, `particle`, `classifier`, `numeral`, `phrase`, `other`
- `source`: 출처 이름
- `license`: 이용 조건 또는 SPDX 식별자. 개인 직접 작성 자료는 `private`
- `source_version`: 원본의 판·쇄·데이터셋 버전
- `source_id`: 원문과 번역을 다시 찾을 수 있는 레코드 ID
- `source_url`: 브라우저에서 확인할 수 있는 `http` 또는 `https` 원문 주소
- `author`: 원문·번역 작성자
- `attribution`: 내보내기와 공유 때 함께 표시할 저자·출처·라이선스 문구
- `content_version`: Sprache 안에서 해당 항목이 변경된 정수 버전
- `subject_id`: 선택 사항. `general:baseball`처럼 사용자 주제를 지정하며, 비워 두면 현재 앱에서 선택한 주제로 가져온다.

같은 철자와 뜻이라도 품사가 다르면 안정적 ID가 다르게 생성된다.

가져오기 한도와 실패 시 원자적 저장·재시도 동작은
[`docs/content-import.md`](../docs/content-import.md)에 정리되어 있다.
