# Sprache 1.19.8 검증 보고서

검증일: 2026-07-29

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| Flutter 전체 테스트 | 321개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| Google·Railway 준비도 | `ApiHealthy=True`, `desktopOAuthBroker=ready`, `WindowsGoogleLoginReady=True` |
| OAuth 토큰 route | 빈 JSON HTTP 400 입력 검증, `Cache-Control: no-store` |
| Windows 실계정 E2E | Google 동의·loopback·Railway 토큰 교환·BOM 폴더 선택·Drive pull/merge/push 통과 |
| 중국어 주제 ID 회귀 | `language:zh-hans` 원격 설정 허용, `ko-zh-Hans` 코스 ID 복원 테스트 통과 |
| Drive revision 회귀 | metadata-only revision 증가 + 동일 SHA 허용, revision + 내용 변경 충돌 차단 테스트 통과 |
| Android 배포물 | APK 생성, `adb install -r`, `versionName=1.19.8`, `versionCode=30`, visible task·프로세스 유지 |
| Windows 배포물 | release ZIP·설치 EXE 생성, 설치·실행·제거 통과 |
| 릴리스 통합 검증 | 버전·해시·APK v2 서명·3개 ABI·Windows AOT·ZIP 33개 항목 통과 |

## 실계정 Google·Drive 검증

Railway `sprache-api`에 `GOOGLE_DESKTOP_CLIENT_ID`와
`GOOGLE_DESKTOP_CLIENT_SECRET`을 sealed variable로 등록했다. 변수 적용 중
GitHub `main`의 이전 이미지가 재배포되어 OAuth route가 빠진 문제를 발견했고,
현재 로컬의 검증된 API를 CLI 배포
`de1fcd7d-c65c-4bab-80ef-9aaa464bc2f7`로 복구했다.

Windows E2E에서 다음 순서를 실제 계정으로 완료했다.

1. Google 계정 동의와 동적 `http://127.0.0.1:<port>` callback
2. Railway를 통한 PKCE authorization code 교환
3. Google Picker에서 `BOM` 폴더 선택
4. 기존 `BOM/WordStudyData`의 segmented snapshot pull
5. 원격·로컬 안전 병합
6. `Windows and Android stay in sync.` 문장과 테스트 주제·그룹 push

새 secret으로 전체 흐름이 성공한 뒤 2026-07-28 생성 이전 secret은
비활성화·삭제했다. 재확인 시 2026-07-29 생성 secret 1개만 활성 상태였고
다중 secret 경고는 사라졌다. 실제 secret 값은 저장소와 문서에 기록하지 않았다.

## 실전에서 발견하고 수정한 문제

### 중국어 주제 ID

Drive의 정상 설정은 `language:zh-hans`를 저장했지만 기본 주제 목록은
`language:zh-Hans`를 비교해 snapshot을 거부했다. 내부 ID는 소문자로 통일하고
BCP 47·코스 표시는 `zh-Hans`, `ko-zh-Hans`로 복원하도록 수정했다.

### Google Drive revision

`state/meta.json`의 manifest revision은 `3`, Drive metadata revision은 `4`였지만
실제 JSON의 SHA-256은 manifest의
`bdbe12c48c91c9697afcf96fc73ad8ba231dff097684ef3695588723fcf9a046`과
일치했다. 공유·권한 metadata 변경으로 revision만 증가한 정상 파일이었다.

pull과 push 모두 revision이 다르면 실제 바이트를 내려받아 SHA-256을 다시
확인하도록 수정했다. SHA가 같으면 계속하고, SHA까지 다르면 기존과 같이
quarantine 사본을 만들거나 업로드 충돌로 중단한다.

## 산출물

### Android

- 파일: `artifacts/Sprache-Android-1.19.8-google-debug-signed.apk`
- 크기: 77,378,015 bytes
- SHA-256:
  `333336d568bc69f212760de7248e690f1bd129a74e4d78ff2bdb0d51ccc32e32`
- 버전: `1.19.8` (`versionCode` 30)
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- 서명: APK Signature Scheme v2, Android Debug 인증서

연결된 에뮬레이터에 `adb install -r`로 업그레이드 설치했다.
`com.youkdonghun.sprache/.MainActivity`가 visible task로 유지됐고 앱 PID가
존재했다. 현재 파일은 직접 설치 검증용이며 Play 배포용 서명본은 아니다.

### Windows

- 포터블: `artifacts/Sprache-Windows-1.19.8-google-x64.zip`
- 크기: 21,133,813 bytes
- SHA-256:
  `236b6cb0a900e9cb7ba360dc6f459088a1bbb968b8347b3dcc2b31405f6c1507`
- 설치 파일: `artifacts/Sprache-Windows-Setup-1.19.8-google-x64.exe`
- 설치 파일 크기: 17,478,391 bytes
- 설치 파일 SHA-256:
  `9f8b4904a6a8ba6165b0782cc88c128977204c59280af65d5d5a5df4764678bb`
- 앱 버전: `1.19.8+30`
- 설치 실행: exit code 0, `작업 보드`, `Responding=True`
- 제거: exit code 0, 설치 폴더 제거, HKCU 제거 항목 0개

세 산출물의 해시는 `artifacts/SHA256SUMS-1.19.8-google.txt`와 일치한다.

## 공개 배포 전에 남은 작업

- Android 물리 기기에서 같은 Google 계정·BOM 폴더를 선택해 Windows 마커 복원
- Play release signing과 Play App Signing SHA용 Android OAuth client
- Windows Authenticode 코드 서명
- 공개 HTTPS 앱 홈페이지·개인정보처리방침·승인 도메인 등록
- Google OAuth 테스트 상태에서 게시·검증 전환
