# 검증용 가져오기 샘플

이 폴더는 사용자 콘텐츠 가져오기 형식과 메타데이터 보존을 검증하기 위한 작은 예시만 둔다. 앱에 내장된 600개 입문 카탈로그는 `apps/client/lib/src/data/sample_content.dart`에 있으며 출처는 루트 `ATTRIBUTIONS.md`에서 관리한다.

지원 메타데이터:

- `part_of_speech`: `noun`, `verb`, `adjective`, `adverb`, `pronoun`, `determiner`, `preposition`, `conjunction`, `interjection`, `auxiliary`, `particle`, `classifier`, `numeral`, `phrase`, `other`
- `source`: 출처 이름
- `license`: 이용 조건 또는 SPDX 식별자. 개인 직접 작성 자료는 `private`
- `source_version`: 원본의 판·쇄·데이터셋 버전
- `content_version`: Sprache 안에서 해당 항목이 변경된 정수 버전

같은 철자와 뜻이라도 품사가 다르면 안정적 ID가 다르게 생성된다.
