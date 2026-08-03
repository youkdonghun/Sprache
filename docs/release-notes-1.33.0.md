# Sprache 1.33.0 릴리스 노트

버전: `1.33.0+57`

상태: **릴리스 후보**. 코드·버전·Windows·Android 검증은 완료했다. Apple
preview와 4플랫폼 manifest는 Codemagic macOS 호스트 검증 뒤에 최종 승격한다.

## 핵심 변화

1. 등록 중 선택한 주제와 그룹이 빠른 등록, 파일 가져오기, 전체 편집기에서 같은
   기준으로 유지된다.
2. 빠른 등록 바구니와 전체 편집기 초안을 저장해 화면 이동이나 앱 재시작 뒤에도
   작업을 이어갈 수 있다.
3. 붙여넣기와 Excel·CSV·JSON·JSONL 가져오기를 같은 검토 절차로 통합하고,
   저장 전에 신규·변경·중복·차단 항목을 확인하도록 정리했다.
4. 입력 중 뜻·중복·그룹 후보를 바로 보여 주고, 좁은 화면에서는 빠른 등록과
   자료실 필터를 더 짧고 읽기 쉽게 배치했다.
5. 홈, 코스, 미션 화면의 중복 안내와 경쟁하는 주요 버튼을 줄여 다음 행동이
   하나씩 명확하게 보이도록 했다.
6. 설정을 목적별 범주로 나누고 `Google Drive 폴더`와 `로컬 저장 위치`를 서로
   다른 상태·경로·변경 동작으로 표시한다. 폴더 재선택이 취소되거나 검증에
   실패하면 기존 연결을 보존한다.
7. 학습 허브를 추천·전체 게임·미션 중심으로 정리하고, 분기 미션, 시험 모드, 실제
   진행량 기반 일일 퀘스트, 실시간 난이도 조절을 추가했다.
8. 듣기 구별, 숙련도 체크포인트, 순차적·접근 가능한 매칭 게임을 보강했다.
9. Windows의 `Ctrl+K` 명령 팔레트에서 검색 결과 확인에 그치지 않고 선택한
   게임이나 퀴즈를 바로 시작할 수 있다.
10. Practice Hub 추천 카드에 이전·다음 버튼과 상시 가로 스크롤바를 배치했다.
    마우스 드래그, 세로 휠, 트랙패드, `←/→`, `PgUp/PgDn`, `Home/End`로 카드
    끝까지 이동할 수 있으며 320px 소형 창에서도 조작부가 넘치지 않는다.

세부 1~22 항목과 검증 경계는
[`ux-upgrade-1-21-verification-1.33.0.md`](ux-upgrade-1-21-verification-1.33.0.md)에
정리했다.

## 야구·아이돌 예문 데이터 교정

야구 5개 단어(`WHIP`, `ERA`, `RBI`, `OPS`, `퀄리티 스타트`)와 아이돌 팬덤
7개 단어(`최애`, `공카`, `응원봉`, `총공`, `출근길`, `퇴근길`, `생얼`)의
단어–뜻–예문–예문 뜻을 다시 맞췄다.

- 통계 용어는 계산 또는 기록 조건을 뜻과 예문에서 같은 기준으로 설명한다.
- 팬덤 용어는 사람, 장소, 도구, 공동 행동, 현장 장면이 서로 섞이지 않도록
  정의와 예문을 구분했다.
- 12개 단어와 자동 생성 예문에 기존 UUID를 명시해 v1 자료를 먼저 가져온
  사용자의 항목과 진도를 새 문장으로 안전하게 갱신한다.
- 번들 JSON의 12개 단어는 품사, 추가 정답, 토큰, 출처와
  `content_version: 2`를 명시한다. CSV·XLSX에도 반복되는 표본은 번들 값과
  맞췄다.

## 데이터 보존

- 기존 단어와 예문을 다른 개념으로 교체하지 않고, 같은 학습 개념의 고정 ID를
  유지한 채 정의와 문장을 교정했다.
- 사용자 학습 콘텐츠와 상세 진도는 계속 로컬 SQLite와 사용자 Google Drive에
  저장하며 Railway PostgreSQL에 저장하지 않는다.
- 손상되거나 검증되지 않은 원격 데이터로 정상 로컬 데이터를 덮어쓰지 않는
  Local-First 원칙과 tombstone 삭제 동기화는 유지한다.

## 플랫폼 산출물 상태

| 플랫폼 | 예정 산출물 | 모드 | 현재 상태 |
| --- | --- | --- | --- |
| Windows | `Sprache-Windows-Setup-1.33.0-google-x64.exe` | 실제 Google/Railway | `PASS` — 설치 EXE·포터블 ZIP·SHA-256 생성, Practice Hub 오른쪽 끝 이동 직접 검증, 1.32 제거 후 1.33 설치·실행 검증 |
| Android | `Sprache-Android-1.33.0-google-debug-signed.apk` | 실제 Google/Railway | `PASS` — APK·SHA-256 생성, 패키지명·`1.33.0+57`·target SDK 36 확인 |
| iOS | `Sprache-iOS-Simulator-1.33.0-mock.zip` | Mock Simulator | `NOT RUN (HOST LIMIT)` — Codemagic macOS 호스트 빌드·실행 필요 |
| macOS | `Sprache-macOS-1.33.0-mock.zip` | Mock ad-hoc | `NOT RUN (HOST LIMIT)` — Codemagic macOS 호스트 빌드·실행 필요 |

iOS ZIP은 설치형 IPA나 App Store 배포본이 아니며, macOS ZIP은 공증된 배포본이
아니다. Apple 산출물은 Codemagic의 `apple-preview`가 실제로 성공하고 런타임
증거와 SHA-256이 생성되기 전까지 만들어졌다고 간주하지 않는다.

## 최종 승격 조건

- [x] Flutter 정적 분석과 전체 테스트 통과
- [x] API와 릴리스 번들 테스트 통과
- [x] Windows·Android 실제 빌드 결과와 검증 증거 생성
- [x] Practice Hub 위젯 19/19·변경 화면 골든 3/3 및 Windows 실제 조작 통과
- [x] 기존 1.31·1.32 산출물 제거 및 Windows 1.33.0 설치 교체
- [ ] Codemagic의 iOS Simulator·macOS preview 런타임 증거 생성
- [ ] 네 플랫폼 파일과 증거를 묶은 `release-manifest-1.33.0.json` 검증 통과
