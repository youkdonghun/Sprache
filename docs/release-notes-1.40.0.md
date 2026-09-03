# Sprache 1.40.0

## 핵심 변경

- 영어 코스에 Part 1~7 비즈니스 영어 실전 학습을 추가했다.
- 빠른 10문제와 파트별 연습은 시간 제한 없이 진행하고, 120분 200문제
  실전과 최근 오답 재도전을 선택할 수 있다.
- 연습에서는 답을 고른 즉시 정답 근거와 A~D 선택지 풀이를 보여 준다.
  실전에서는 채점 전까지 풀이를 숨긴다.
- 영어 TTS 듣기, 듣기 원문 확인, 답안지, 플래그, 미응답 경고, 자동 재개,
  정확도와 파트별 최근 기록을 추가했다. 미응답도 오답 재도전에 포함한다.
- 결과 화면에서 오답만 간단히 보거나 전체 문제의 지문·선택지·선택지별
  풀이를 다시 볼 수 있다.
- 문제팩 갱신과 상세 정보는 접힌 관리 영역으로 모아 기본 화면을 단순화했다.
- 최초 실행 시 GitHub 문제팩을 파일 크기와 SHA-256으로 검증해 로컬 DB에
  저장하며, 그 다음부터는 오프라인에서도 풀 수 있다.

## 문제팩

- Sprache에서 독자적으로 작성한 200문제와 73개 공통 지문을 포함한다.
- 구성은 Part 1 6문제, Part 2 25문제, Part 3 39문제, Part 4 30문제,
  Part 5 30문제, Part 6 16문제, Part 7 54문제다.
- `exam-packs/catalog.json`이 버전·크기·해시를 고정하고,
  `exam-packs/schema/exam-pack.schema.json`이 형식을 정의한다.
- `node tool/build-exam-pack.mjs`가 스타터 팩을 재생성하고,
  `npm run test:exam-pack`이 문항 수·풀이·정답·음성 순서·해시를 검증한다.

## 콘텐츠 및 상표

이 문제팩은 공식 또는 기출문제를 복제하지 않고, 공개된 시험 구성만 참고해
작성한 비공식 학습 자료다.

TOEIC® is a registered trademark of ETS. This product is not endorsed or
approved by ETS.

## 검증

- Flutter 정적 분석: 통과
- Flutter 전체 테스트: 1,158개 통과
- 문제팩 Node 테스트: 4개 통과
- Windows, Android, Web release build: 배포 전 검증
