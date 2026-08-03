# Sprache 1.19.9 검증 보고서

검증일: 2026-07-29

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| API 테스트 | Vitest 12개 통과 |
| Flutter 전체 테스트 | 324개 통과 |
| 시각 회귀 | Android·Windows 골든 43개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| Google·Railway 준비도 | `ApiHealthy=True`, `desktopOAuthBroker=ready`, `WindowsGoogleLoginReady=True` |
| Windows 실계정 E2E | Google 동의·loopback·Railway 토큰 교환·Drive pull/merge/push 통과 |
| Android 실계정 E2E | 계정 선택·동의·Railway 폴더 연결 조회·Drive 폴더 검증·동기화 통과 |
| 교차 기기 복원 | Windows 사용자 콘텐츠 마커를 Android에서 다운로드 |
| Android UI | 좁은 설정 화면의 Drive 제목 줄바꿈 정리, 실제 APK 화면 확인 |
| Android 배포물 | APK 생성, `adb install -r`, `versionName=1.19.9`, `versionCode=31`, 프로세스 유지 |
| Windows 배포물 | release ZIP·설치 EXE 생성, 설치·실행·제거 통과 |
| 릴리스 통합 검증 | 체크섬 3개, APK v2 서명, ABI 3개, Windows AOT·ZIP 33개 항목 통과 |

## Android의 기존 Drive 연결 재사용

Android는 Google 로그인 직후 ID Token으로 Railway
`GET /v1/me/drive-root`를 조회한다. 바인딩이 있으면 `drive.file` 권한을 받은 뒤
해당 ID를 Drive API에서 조회하고 다음 조건을 모두 확인한다.

1. 파일이 실제로 존재한다.
2. MIME type이 Google Drive 폴더다.
3. 휴지통에 있지 않다.
4. 폴더 아래 manifest와 segmented snapshot 디렉터리를 준비할 수 있다.

검증이 끝난 폴더만 재사용한다. 바인딩이 없거나 오래돼 유효하지 않으면 네이티브
Picker로 돌아가며, 이 실패 때문에 정상 로컬 데이터를 삭제하지 않는다.

## Windows에서 Android로 실제 복원

Windows 실계정 E2E에서 `BOM/WordStudyData`에 올린 사용자 콘텐츠
`live-e2e-windows-android-marker-v1`을 Android 16 에뮬레이터가 같은 계정으로
다운로드했다. Android 설정 화면에서 다음을 확인했다.

- 연결 상태 `연결됨`
- `WordStudyData` 폴더와 마지막 동기화 시각
- 업로드·다운로드·충돌 병합 결정
- Windows에서 만든 사용자 콘텐츠 마커
- 계정 누적 XP 50

검증 화면은
`artifacts/verification/android-1.19.9-drive-sync-success-compact.png`에 남겼다.
계정과 Drive 파일 목록이 나타난 중간 인증 캡처 21개는 검증 뒤 삭제했다.

## 산출물

### Android

- 파일: `artifacts/Sprache-Android-1.19.9-google-debug-signed.apk`
- 크기: 77,410,779 bytes
- SHA-256:
  `c05957bb0a7111da7b7aa3696698123a183e9fff6a3a763303d2281f7846d50e`
- 버전: `1.19.9` (`versionCode` 31)
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- 서명: APK Signature Scheme v2, Android Debug 인증서

현재 APK는 실제 Google·Railway 연결이 켜진 직접 설치 검증용이다. Play 배포용
서명본은 아니다.

### Windows

- 포터블: `artifacts/Sprache-Windows-1.19.9-google-x64.zip`
- 크기: 21,138,130 bytes
- SHA-256:
  `412eebd1c42eb47e2bb4fca3760584087cff44a23b0a78a5e3ebae20b0237d8b`
- 설치 파일: `artifacts/Sprache-Windows-Setup-1.19.9-google-x64.exe`
- 설치 파일 크기: 17,480,622 bytes
- 설치 파일 SHA-256:
  `d1aa9c4534f6fc256e8cfb03c6eb72c2d42f23e899f77bee64fb6b7f66bf6396`
- 앱 버전: `1.19.9+31`
- 설치 실행: exit code 0, `작업 보드`, `Responding=True`
- 제거: exit code 0, 설치 폴더 제거, HKCU 제거 항목 0개
- Authenticode: `NotSigned`

세 산출물의 해시는 `artifacts/SHA256SUMS-1.19.9-google.txt`와 일치한다.

## 공개 배포 전에 남은 작업

- Android 물리 기기에서 동일 계정 자동 연결과 최초 Picker 폴더 선택 반복
- 물리 기기 마이크·TTS·알림·장시간 오프라인 충돌 실측
- Play release signing과 Play App Signing SHA용 Android OAuth client
- Windows Authenticode 코드 서명
- 공개 HTTPS 앱 홈페이지·개인정보처리방침·승인 도메인 등록
- Google OAuth 테스트 상태에서 게시·검증 전환
