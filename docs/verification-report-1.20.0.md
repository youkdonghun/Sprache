# Sprache 1.20.0 검증 보고서

검증일: 2026-07-29

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| API 테스트 | Vitest 12개 통과 |
| Flutter 전체 테스트 | 329개 통과 |
| 시각 회귀 | Android·Windows 골든 이미지 44개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| 모바일 반응형 | 375×812, 390×844, 412×915, 430×932 통과 |
| 글자 확대 | 390px 핵심 작업공간과 412px 연결 화면에서 1.3배 통과 |
| 테마 | 설정·홈·자료함·학습·코스 등 라이트·다크 골든 통과 |
| Google·Railway 준비도 | `ApiHealthy=True`, `desktopOAuthBroker=ready`, `WindowsGoogleLoginReady=True` |
| Android 연결 복구 | `adb install -r` 뒤 사용자 재연결 없이 기존 Drive 폴더와 동기화 상태 복구 |
| Android 실제 UI | 412×915 연결 설정 화면에서 줄바꿈·오버플로 없이 컴팩트 카드 확인 |
| Windows 배포물 | release ZIP·설치 EXE 생성, 설치·실행·제거 통과 |
| 릴리스 통합 검증 | 체크섬 3개, APK v2 서명, ABI 3개, Windows AOT·ZIP 33개 항목 통과 |

## 저장된 Google·Drive 연결 복구

앱 상태가 로드되고 기존 Drive 연결 기록이 있으면 플랫폼별 저장 인증을 이용해
런타임 연결을 다시 만든다.

- Android: 네이티브 경량 인증 → Railway 폴더 바인딩 조회 → `drive.file`
  권한 확인 → 폴더 metadata 검증 → pull·merge·push
- Windows: OS 보안 저장소의 identity·Drive 토큰 확인 → 필요 시 Railway
  무저장 broker로 token refresh → 폴더 metadata 검증 → pull·merge·push
- 복구 불가: `driveConnected` 기록, 정상 로컬 자료와 pending snapshot을
  유지하고 설정에 다시 연결·재시도 동작을 표시
- 일시 장애: 단계별 한국어 진단과 백오프를 유지하고 손상 원격 데이터는 격리

Android 16 에뮬레이터에서 기존 Google 인증과 로컬 DB를 보존한 채 1.20.0을
덮어 설치했다. 한 실행에서는 Google Play services의
`AssistedSignInActivity`가 일시적으로 활성화됐지만 계정 선택·동의 입력 없이
앱으로 복귀했다. 이후 설정에서 다음을 확인했다.

- `연결됨`
- `WordStudyData`
- 마지막 동기화 시각
- 업로드 0·다운로드 0·검토 1 병합 요약
- Windows에서 만든 `live-e2e-windows-android-marker-v1` 자료 유지

실측 화면은
`artifacts/verification/android-1.20.0-mobile-settings-connected.png`에
남겼다. 계정 이메일이나 토큰은 포함하지 않는다.

## 모바일 UI 고도화

실제 연결 데이터가 있는 설정 화면에서 가장 많은 세로 공간과 줄바꿈을 만들던
요소를 모바일 전용 요약형으로 바꿨다.

- `Drive 백업`, 연결 상태와 폴더·마지막 시각을 짧은 헤더에 배치
- 마지막 동기화는 `↑ 업로드 · ↓ 다운로드 · 검토` 한 줄 요약으로 표시
- 충돌 항목 상세는 모바일에서 기본 접힘, 사용자가 눌러 펼침
- `지금 동기화`와 `연결 해제`를 한 행의 주·보조 동작으로 정리
- 하루 목표와 세션 문제 수의 현재 값을 별도 줄이 아닌 같은 행에 배치
- 모바일 카드 여백, 구분선과 슬라이더 사이 간격 축소

연결 카드의 실제 높이가 줄어 첫 화면에서 학습 목표와 세션 설정까지 함께
보인다. 1.3배 글자 크기에서도 연결 카드 높이와 RenderFlex 오버플로를 자동
검사한다.

Windows 실제 프로세스는 `작업 보드`, `Responding=True`로 확인했다. 현재
데스크톱 세션의 일반 화면 캡처와 `PrintWindow`는 Flutter GPU surface를
검은 화면으로 반환해 실제 스크린샷 증거로 사용하지 않았다. Windows 시각
증거는 380·420·1024·1280px 위젯 테스트와 골든 이미지로 검증했다.

## 산출물

### Android

- 파일: `artifacts/Sprache-Android-1.20.0-google-debug-signed.apk`
- 크기: 77,410,783 bytes
- SHA-256:
  `27fc9cf0b19f7c23a29afafe935fae27ca9c8c0088ccd31642a6e4a0d288437e`
- 버전: `1.20.0` (`versionCode` 32)
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- 서명: APK Signature Scheme v2, Android Debug 인증서

이 APK는 실제 Google·Railway 연결이 켜진 직접 설치 검증용이다. Play 배포용
서명본은 아니다.

### Windows

- 포터블: `artifacts/Sprache-Windows-1.20.0-google-x64.zip`
- 크기: 21,147,197 bytes
- SHA-256:
  `bd9d2ec573912a746a6ead23c3dd710beb924784b0d5dd7524bd492909a67b80`
- 설치 파일: `artifacts/Sprache-Windows-Setup-1.20.0-google-x64.exe`
- 설치 파일 크기: 17,486,365 bytes
- 설치 파일 SHA-256:
  `a4f4a3403e80499413385fe8ae47aaceaf5dbea1547914399c6ac322cd7c9922`
- 앱 버전: `1.20.0+32`
- 설치 실행: exit code 0, `작업 보드`, `Responding=True`
- 제거: exit code 0, 설치 폴더 제거, HKCU 제거 항목 0개
- Authenticode: `NotSigned`

세 산출물의 해시는 `artifacts/SHA256SUMS-1.20.0-google.txt`와 일치한다.

## 공개 배포 전에 남은 작업

- Android 물리 기기에서 Credential Manager 자동 연결과 최초 Picker 폴더 선택 반복
- 물리 기기 마이크·TTS·알림·장시간 오프라인 충돌 실측
- Play release signing과 Play App Signing SHA용 Android OAuth client
- Windows Authenticode 코드 서명
- 공개 HTTPS 앱 홈페이지·개인정보처리방침·승인 도메인 등록
- Google OAuth 테스트 상태에서 게시·검증 전환
