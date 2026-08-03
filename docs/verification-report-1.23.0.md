# Sprache 1.23.0 검증 보고서

검증일: 2026-07-30

## 반영한 UX 고도화 15개

1. 화면 용어를 `자료실 → 학습 그룹 → 자료`로 통일했다.
2. `자료 추가 → 그룹 정리 → 암기·퀴즈` 안내를 실제 화면 이동 버튼으로 만들었다.
3. 그룹을 자료 태그와 별개의 `LearningGroupDefinition` 모델로 저장한다.
4. Windows는 700px 폭에서도 좌우 드래그앤드롭 작업판을 유지한다.
5. 전체·현재 화면·숨겨진 선택 수를 구분해 표시한다.
6. Windows에서 `Ctrl+A`, `Shift+클릭`, `Esc` 다중 선택을 지원한다.
7. 그룹 생성·이동·해제·편집·삭제·고정·순서 변경 뒤 실행 취소를 제공한다.
8. 대량 추가·이동 전에 선택 수, 기존 연결 수, 결과 그룹을 미리 보여준다.
9. `그룹 연결 해제`를 위험 구역으로 분리하고 자료·진도 보존을 확인시킨다.
10. 그룹 검색, 이름·자료 수 정렬, 상단 고정, 사용자 순서 변경을 제공한다.
11. 각 그룹에서 암기와 퀴즈를 바로 시작한다.
12. 모바일 선택 작업을 하단 한 줄 작업 바로 압축했다.
13. 모바일의 가로 그룹 칩을 드롭다운과 별도 그룹 관리 시트로 교체했다.
14. 로컬 저장, Drive 대기·실패·마지막 동기화 시각을 자료실과 작업판에 표시한다.
15. 자료를 다른 주제로 옮겨도 현재 주제를 유지하고 `대상 주제 열기`를 선택 제공한다.

## 저장·동기화

- 그룹 정의는 기존 `StudyPreferences` JSON에 저장되어 SQLite와 Google Drive
  snapshot을 그대로 사용하므로 DB schema migration이 필요하지 않다.
- 기존 `group:` 태그는 첫 로드 때 독립 그룹 정의로 안전하게 승격한다.
- 그룹 삭제는 tombstone으로 동기화하며, 원본 자료와 학습 진도는 삭제하지 않는다.
- Railway PostgreSQL에는 학습 자료·그룹·진도를 저장하지 않는다.

## 검증 결과

| 검사 | 결과 |
| --- | --- |
| Flutter 전체 테스트 | 379개 통과, 건너뜀 0개 |
| API Vitest | 14개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| 시각 회귀 | 31개 테스트 통과 |
| 그룹 전용 골든 | 데스크톱, 700px Windows, 모바일 기본·선택·관리 시트 라이트·다크 8장 |
| 모바일 반응형 | 375×812, 390×844, 412×915, 430×932 라이트·다크 통과 |
| Windows 키보드·드래그 | 좁은 좌우 작업판, 범위 선택, 숨김 수, 이동·실행 취소 통과 |
| Windows 엔진 E2E | 380×520 홈·학습, 420×640 홈, 1040×760 홈·설정 통과 |
| Windows 릴리스 크기 | 요청·실제 380×520, 420×640, 1040×760 일치 |
| Railway·Google 준비 상태 | API 정상, `desktopOAuthBroker=ready`, Windows 로그인 준비 `True` |
| 릴리스 무결성 | Android ABI 3개, Windows ZIP 34개, 체크섬 3개, 정책 URL 포함 |

## 산출물

| 파일 | SHA-256 |
| --- | --- |
| `Sprache-Android-1.23.0-google-debug-signed.apk` | `eabe550188092cab97cd83361f687f99dbca437f0c28761ac9aa1a8a09054d7c` |
| `Sprache-Windows-1.23.0-google-x64.zip` | `3f234423da2bc078b31985ece290db503cdd524d786bb9283fde3c0e74437b51` |
| `Sprache-Windows-Setup-1.23.0-google-x64.exe` | `80146ac5d5c9ba757f6950327b1af66f93ca8d3b35f849a4a3a56dc32b006874` |

바탕화면 Android 설치 파일:
`C:\Users\youk\Desktop\Sprache-Android-1.23.0.apk`

Windows release 앱은 PID 9336, 창 제목 `작업 보드`,
`Responding=True`로 실행을 확인했다.

## 남은 외부 조건

- Android APK는 실연동 설정이지만 현재 로컬 Debug 인증서로 서명됐다.
- Windows 실행 파일과 설치본은 Authenticode 서명이 없다.
- Tatoeba 공개 API 출처 재조회는 두 차례 연결 시간 초과가 발생했다.
  저장소의 콘텐츠 구조·중복·출처·한국어 발음 로컬 테스트는 통과했다.
- Play 배포용 release keystore, Play App Signing OAuth 지문과 Windows
  코드 서명 인증서는 배포 전에 별도로 설정해야 한다.
