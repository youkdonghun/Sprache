# Sprache 시험팩

`catalog.json`은 앱이 내려받을 수 있는 시험팩 목록이고 `packs/`에는 실제 문제가
있다. 첫 규격은 영어 Part 1~7 객관식, 공통 지문, 듣기 대본, 정답, 정답 근거,
선택지별 풀이를 지원한다.

- 공식 시험 문제나 출판물 문장을 복제하지 않는다.
- 모든 문제는 독자 제작하고 출처·라이선스·상표 고지를 기록한다.
- `node tool/build-exam-pack.mjs`로 스타터 팩과 SHA-256 카탈로그를 갱신한다.
- `node --test tool/test/exam-pack.test.mjs`로 200문제 구성과 풀이를 검증한다.

TOEIC® is a registered trademark of ETS. This product is not endorsed or
approved by ETS.
