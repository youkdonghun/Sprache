# Sprache 1.22.4 검증 보고서

검증일: 2026-07-30

## 변경 범위

- 카드·퀴즈·암기·발음·단어 상세에서 한국어 읽기 앞에 반복되던
  `한국어 발음` 접두어를 제거했다.
- 실제 발음 내용과 가나·로마자·병음 라벨은 유지한다.
- 사용자가 값을 입력하는 편집 화면과 Excel 열 이름은 구분을 위해 유지한다.

## 검증

| 검사 | 결과 |
| --- | --- |
| 관련 도메인·위젯 테스트 | 7개 통과 |
| `npm run analyze:client` | 이슈 0개 |
| 시각 회귀 테스트 | 라이트·다크 19개 통과 |
| `npm run test:client` | 359개 통과 |
| `npm run verify:release` | 통과 |

반응형 테스트는 320×640, 360×800, 375×812, 390×844, 412×915,
430×932 화면을 포함한다. 카드와 퀴즈의 갱신된 골든을 직접 확인했으며
발음 내용만 표시되고 오버플로가 없었다.

## 실행·설치

- Windows `1.22.4+42` release 앱을 다시 실행했다.
- 프로세스 ID 33600, 창 제목 `작업 보드`, `Responding=True`를 확인했다.
- Android Emulator에 APK를 덮어쓰기 설치해
  `versionName=1.22.4`, `versionCode=42`를 확인했다.
- 사용자 테스트 중인 Windows 창을 유지하기 위해 설치→실행→제거 스모크는
  이번 변경에서 다시 실행하지 않았다.

## 산출물

| 파일 | SHA-256 |
| --- | --- |
| `Sprache-Android-1.22.4-google-debug-signed.apk` | `5033E588FF4F05DE606179676CCDAB9DFF47AAC8A11BB95BC7C164C506102AEC` |
| `Sprache-Windows-1.22.4-google-x64.zip` | `D864D3C36F5747810F01E049A3426C8F4CDA643AB1D057ABEAEC87B52AEC0C14` |
| `Sprache-Windows-Setup-1.22.4-google-x64.exe` | `072BC9510AC03BF0E363288D388DEBCCB2E52F74B95B9231279C6586579EF024` |

통합 검증은 Android ABI 3개, Windows ZIP 34개 항목, 체크섬 3개,
운영 API와 개인정보처리방침 포함을 확인했다. Android는 Debug 서명,
Windows 설치본은 Authenticode 무서명이므로 공개 스토어 배포 조건은
이전 버전과 동일하게 남아 있다.

현재 바탕 화면의 Android 설치 파일:
`C:\Users\youk\Desktop\Sprache-Android-1.22.4.apk`
