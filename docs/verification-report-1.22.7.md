# Sprache 1.22.7 검증 보고서

검증일: 2026-07-30

## 변경 범위

- 단어장에 `추가·가져오기 → 그룹 정리 → 암기·퀴즈` 자료 흐름 안내를 추가했다.
- 안내 상세에서 앱 기본 자료, 로컬 SQLite, Google Drive, Railway의
  데이터 보관 범위를 구분해 설명한다.
- Windows 그룹 작업판은 왼쪽 자료를 오른쪽 그룹으로 끌어 놓아 정리한다.
- 모바일은 자료를 선택한 뒤 하단 시트에서 그룹을 고르는 흐름을 사용한다.
- 그룹 추가·이동·해제, 생성·이름 변경·삭제와 다른 학습 주제로 이동을
  지원하며 원본 자료와 학습 진도를 보존한다.

## 검증

| 검사 | 결과 |
| --- | --- |
| `npm run analyze:client` | 이슈 0개 |
| `npm run test:client` | 372개 통과 |
| 시각 회귀 테스트 | 30개 통과 |
| 반응형 위젯 검사 | 375×812, 390×844, 412×915, 430×932 라이트·다크 통과 |
| 추가 시각 확인 | 320px 모바일, 1280×800 Windows 통과 |
| Windows 좌우 드래그앤드롭 | 선택 자료의 그룹 저장 확인 |
| 모바일 선택형 그룹 지정 | 하단 시트의 그룹 저장 확인 |
| Android 실연동 release 빌드 | 성공 |
| Windows 실연동 release 빌드 | 성공 |
| `npm run verify:release` | 통과 |

릴리스 검증기는 앱 버전 `1.22.7+45`, Android ABI 3개, Windows ZIP
33개 항목, 체크섬 3개, 개인정보처리방침 URL 포함을 확인했다.

## 실행

- Windows `1.22.7+45` release 앱을 실행했다.
- 프로세스 ID 27080, 창 제목 `작업 보드`, `Responding=True`를 확인했다.

## 산출물

| 파일 | SHA-256 |
| --- | --- |
| `Sprache-Android-1.22.7-google-debug-signed.apk` | `6BAE7F161E163A5FC4064D0E12F01D99A3C60E8AF3D872898C90C0E34DCA7664` |
| `Sprache-Windows-1.22.7-google-x64.zip` | `B77DC1B4196B8B771970026D2A0A987C5DD13AB5A7DE62D8D0133F0D9478FADD` |
| `Sprache-Windows-Setup-1.22.7-google-x64.exe` | `B63EDA7C7DEEEC9628A580EC3DA54BC67B9F02F3E7F8CA339506B82EACEF795F` |

바탕화면 Android 설치 파일:
`C:\Users\youk\Desktop\Sprache-Android-1.22.7.apk`

## 남은 배포 조건

- Android 파일은 실제 연결 구성이지만 Debug 인증서로 서명됐다.
- Windows 실행 파일과 설치본은 Authenticode 서명이 없다.
- 스토어 배포 전 Android release keystore와 Windows 코드 서명이 필요하다.
