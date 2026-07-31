# Google Cloud 연결 설정

> 가져오기 연동: Excel·CSV·JSON·JSONL 가져오기를 `반영`하면 검증·정돈한
> 학습 데이터가 앱 전용 SQLite에 먼저 병합된다. Google 연결 상태에서는 기존
> Drive snapshot을 pull·병합·push하며 원본 업로드 파일은 별도로 복제하지 않는다.
> `distribution_key`로 기억한 주제·그룹 라우팅 규칙과 정돈된 항목은 Drive로
> 기기 간 공유하지만 Railway에는 OAuth 토큰, 원본 파일, 학습 내용, 분배 규칙을
> 저장하지 않는다.

앱은 로그인과 Drive 권한을 분리하고 Drive에는 `drive.file`만 요청한다. Google Drive API와 Google Picker API의 현재 설정 방식은 [Drive 범위 가이드](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)와 [데스크톱·모바일 Picker 가이드](https://developers.google.com/workspace/drive/picker/guides/desktop-mobile-picker)를 따른다.

## 연결 전후 데이터 흐름

앱 전용 SQLite는 연결 상태와 관계없이 유일한 작업 원본이다.

1. Google 미연결 상태에서는 Windows 파일시스템 또는 Android SAF로 사용자가
   고른 `Sprache` 폴더에 `segmented-v1`과 전체 복원 archive를 자동 미러한다.
   Google Drive 연결 뒤에는 `canonical-v1` 단일 snapshot 파일 ID를 갱신한다.
2. Google 연결이 성공해 첫 pull·검증·병합·push를 마치면 Drive가 활성
   동기화 대상이 된다. 기존 로컬 폴더 설정과 파일은 삭제하지 않고 이 기기의
   fallback으로 유지한다.
3. 네트워크 단절, Drive API 오류, 토큰 갱신 실패처럼 일시적인 장애는 로컬
   폴더로 자동 failover하지 않는다. SQLite의 `pending_syncs`와 import staging을
   유지하고 Drive 재시도 또는 재연결을 안내한다.
4. 사용자가 `연결 해제`를 선택하면 이 기기의 Google 인증만 정리하고 설정된
   로컬 자동 미러를 다시 활성화한다. Railway 바인딩, Drive 폴더·파일,
   사용자 지정 로컬 폴더·파일은 삭제하지 않는다.

Railway PostgreSQL에 영속하는 값은 HMAC 처리한 `account_key`, Drive 앱 루트
Folder ID·표시 이름·schema version과 생성·수정 시각뿐이다. Windows OAuth
broker는 인증 코드 또는 refresh token을 Google에 전달하고 응답을 즉시
클라이언트로 반환하며 요청·응답 토큰을 DB나 로그에 저장하지 않는다. 클라이언트
토큰은 OS 보안 저장소에만 둔다.

로컬 폴더 형식, current/previous manifest, SHA-256 검증과 복원 충돌 선택은
[로컬 저장과 저장 대상 전환](local-storage.md)을 참고한다.

## 1. Google Cloud 프로젝트

- 프로젝트 이름: `Sprache`
- 프로젝트 ID: `keen-answer-503804-d2`
- OAuth 게시 상태: `테스트 중`, 사용자 유형 `외부`
- 테스트 사용자: 프로젝트 소유자 계정 1명 등록 완료
- Google Drive API: 활성화 완료
- Google Picker API: 활성화 완료
- 데이터 액세스: `openid`, `userinfo.email`, `userinfo.profile`, `drive.file`

## 2. OAuth 클라이언트 3개

### Android 클라이언트

- 애플리케이션 ID: `com.youkdonghun.sprache`
- 현재 로컬 debug SHA-1: `AB:64:24:D5:FC:BA:3F:76:2C:27:C2:BE:61:3D:1A:A9:C8:4F:1F:AE`
- OAuth client ID: `1054343487948-v3u90fo5nmbrk4hn7ss2gnrg601phkuv.apps.googleusercontent.com`
- Play 배포 때는 Play App Signing SHA-1로 별도 Android 클라이언트를 추가한다.

로컬 인증서 재확인:

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -list -v `
  -alias androiddebugkey `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -storepass android -keypass android
```

Android는 로그인에서 받은 ID Token으로 Railway
`GET /v1/me/drive-root`를 먼저 조회한다. 같은 계정으로 Windows에서 이미
`WordStudyData`를 연결했다면 Android는 해당 ID의 Drive metadata를 직접 읽어
폴더이고 휴지통에 있지 않은지 검증한 뒤 그대로 사용한다. Railway에는 HMAC 처리한
계정 키와 폴더 ID·표시 이름·스키마 버전만 남고 OAuth 토큰이나 학습 내용은 저장하지
않는다.

저장된 연결이 없거나 ID가 삭제·변경된 경우에만 Google Play services의
`AuthorizationRequest`에 `drive.file`, `PICKER_OAUTH_TRIGGER`,
`PICKER_ALLOW_FOLDER_SELECTION`을 넣어 네이티브 Picker를 연다. MIME 필터는
일부 Android Picker에서 폴더 선택 화면을 비정상적으로 축소하는 실측 문제가 있어
지정하지 않는다.

### Web application 클라이언트

Android Credential Manager가 ID Token을 서버 대상으로 발급할 때 쓰는 클라이언트다. JavaScript origin과 redirect URI는 비워도 된다. 이 ID를 `GOOGLE_SERVER_CLIENT_ID`에 넣는다.

- OAuth client ID: `1054343487948-g6b3fp20ooq86agro7nsb129oqr9df82.apps.googleusercontent.com`

### Desktop app 클라이언트

Windows 시스템 브라우저 PKCE + loopback 콜백에 쓴다. Client ID는 Windows 빌드와
Railway에 동일하게 넣고, Client Secret은 Railway sealed variable에만 넣는다.

- OAuth client ID: `1054343487948-791d7jh7m90rt4cs1ncgkf6l5eecehut.apps.googleusercontent.com`
- 콜백 형식: `http://127.0.0.1:<임의 포트>` (경로 없음)
- 이 주소는 인터넷 서버가 아니라 로그인 중인 Windows PC의 Sprache 프로세스로만 돌아오는 Google 공식 설치형 앱 방식이다.
- Cloudflare·Railway 콜백은 사용하지 않는다. Android는 아래 값과 네이티브 Google Sign-In을 사용하므로 이 루프백 주소를 사용하지 않는다.
- Railway는 콜백 서버가 아니라 Google 토큰 교환 중계다. 인증 코드와 PKCE verifier를
  HTTPS로 받아 Google에 전달하고, 토큰 응답을 저장하지 않고 Windows 앱에 즉시 반환한다.
- 앱은 Google 브라우저를 열기 전에 Railway `/health`의
  `desktopOAuthBroker=ready`를 확인한다.

Windows 토큰 교환이 400이면 앱에 표시된 상세 코드를 확인한다.

- `invalid_grant`: 기존 브라우저 창을 닫고 앱에서 다시 연결한다.
- `redirect_uri_mismatch`: OAuth 클라이언트 유형이 `데스크톱 앱`인지 확인한다.
- `invalid_client`: 빌드의 `GOOGLE_DESKTOP_CLIENT_ID`가 삭제되지 않은 현재 클라이언트와 같은지 확인한다.
- `oauth_broker_not_configured`: Railway 코드 배포와 아래 두 sealed variable을 확인한다.
- `oauth_broker_unreachable`: Railway 서비스 상태를 확인하고 로컬 학습을 계속한 뒤 재시도한다.

## 3. Railway API 환경변수

```text
DATABASE_URL=${{Postgres.DATABASE_URL}}
GOOGLE_ALLOWED_CLIENT_IDS=<desktop-client-id>,<web-server-client-id>
GOOGLE_DESKTOP_CLIENT_ID=<desktop-client-id>
GOOGLE_DESKTOP_CLIENT_SECRET=<Google Cloud 데스크톱 클라이언트의 secret>
USER_KEY_HMAC_SECRET=<32바이트 이상의 무작위 비밀값>
NODE_ENV=production
LOG_LEVEL=info
```

비밀값 생성 예:

```powershell
$bytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
[Convert]::ToBase64String($bytes)
```

`GOOGLE_DESKTOP_CLIENT_SECRET`과 생성된 HMAC 비밀값은 저장소·채팅·빌드 명령에
붙이지 말고 Railway의 sealed variable로만 저장한다. Desktop Client Secret은
Windows `--dart-define`에 전달하지 않는다.

배포 뒤 확인:

```powershell
npm run check:google
```

`WindowsGoogleLoginReady`가 `True`여야 한다. `not_configured`이거나
`api_update_required`이면 Google 로그인보다 Railway 배포·환경변수 설정을
먼저 완료한다. 실계정 Windows E2E 명령은 이 점검을 자동으로 통과한 뒤에만
브라우저를 연다.

## 4. 실제 연결 빌드

```powershell
flutter build apk --release `
  --dart-define=APP_ENV=production `
  --dart-define=ENABLE_MOCK_MODE=false `
  --dart-define=API_BASE_URL=https://sprache-api-production.up.railway.app `
  --dart-define=GOOGLE_ANDROID_CLIENT_ID=1054343487948-v3u90fo5nmbrk4hn7ss2gnrg601phkuv.apps.googleusercontent.com `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=1054343487948-g6b3fp20ooq86agro7nsb129oqr9df82.apps.googleusercontent.com

flutter build windows --release `
  --dart-define=APP_ENV=production `
  --dart-define=ENABLE_MOCK_MODE=false `
  --dart-define=API_BASE_URL=https://sprache-api-production.up.railway.app `
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID=1054343487948-791d7jh7m90rt4cs1ncgkf6l5eecehut.apps.googleusercontent.com
```

저장소 루트에서는 같은 설정을 고정한 `npm run build:real`로 두 플랫폼을 한 번에 빌드할 수 있다. OAuth client ID는 공개 식별자이며, Client Secret은 앱 빌드나 저장소에 넣지 않는다.

## 5. 연결 검증

1. 로그인 전 샘플 학습이 되는지 확인한다.
2. Google 미연결 상태에서 로컬 폴더를 선택하고 그 아래 `Sprache/manifest.json`,
   `state/`, `content/`, `backups/`가 생성되는지 확인한다. 데이터를 한 번 더
   변경·저장한 뒤 `manifest.previous.json`과 그 참조 파일도 남는지 확인한다.
   Android는 앱 재시작 뒤에도 SAF 권한으로 같은 폴더에 저장되는지 확인한다.
3. Railway `/health`가 `desktopOAuthBroker=ready`인지 확인한다.
4. 설정에서 Google 연결을 누른다.
5. 인증 후 Drive 권한 요청이 별도로 나타나는지 확인한다.
6. 기존 폴더 하나를 선택한다.
7. 선택 폴더 아래 `WordStudyData/manifest.json`과
   `state/snapshot.json`이 생겼는지 확인한다. 두 번째 동기화와 Excel
   재가져오기 뒤에도 snapshot의 Drive 파일 ID가 바뀌지 않아야 한다.
8. Drive 연결 중 로컬 `Sprache` 폴더의 마지막 저장 시각이 갱신되지 않고,
   설정에는 연결 해제 시 사용할 fallback으로 남는지 확인한다.
9. 다른 기기에서 같은 계정·폴더를 선택하고 XP와 진도가 합쳐지는지 확인한다.
10. 네트워크 또는 Drive 권한 오류가 나도 로컬 폴더로 자동 우회하지 않고
    업로드 대기 상태를 유지하는지 확인한다.
11. `연결 해제` 뒤 로컬 자동 저장이 재개되고 Railway 바인딩·Drive 파일·
    로컬 파일이 모두 남는지 확인한다.

## 6. OAuth 공개 전환

Google의 현재 검증 안내는 앱 홈페이지와 개인정보처리방침을 로그인 없이 볼 수
있는 별도 HTML 페이지로 제공하고, 소유권을 확인한 도메인에 호스팅하며, 홈페이지가
개인정보처리방침으로 연결되도록 요구한다.

- 공개 앱 홈페이지: `https://sprache-api-production.up.railway.app/`
- 공개 개인정보처리방침: `https://sprache-api-production.up.railway.app/privacy`
- 공개 서비스 이용약관: `https://sprache-api-production.up.railway.app/terms`
- 저장소 초안: `docs/app-homepage.html`, `docs/privacy-policy.html`
- 앱 내부 고지: 설정 → 데이터와 개인정보 → `개인정보 처리 안내 자세히 보기`

공개 전환 순서:

1. 두 HTML의 문의처, 운영 주체, 실제 배포 주소를 최종 검토한다.
2. 소유권을 확인할 수 있는 동일 도메인에 서로 다른 URL로 공개한다.
3. Google Search Console 또는 Google이 안내하는 방식으로 도메인 소유권을 확인한다.
4. OAuth 동의 화면에 홈페이지 URL과 개인정보처리방침 URL을 등록한다.
5. 앱 화면에서 같은 개인정보처리방침 URL을 열 수 있게 최종 공개 URL을 빌드에 반영한다.
6. 요청 범위가 `openid`, `email`, `profile`, `drive.file`뿐인지 다시 확인한다.
7. 테스트 모드에서 실계정 왕복을 마친 뒤 게시·검증 여부를 결정한다.

공식 기준:

- [Google 앱 개인정보처리방침 안내](https://support.google.com/cloud/answer/13806988)
- [Google 앱 홈페이지 안내](https://support.google.com/cloud/answer/13807376)
- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)

## 7. 2026-07-30 Google Auth Platform 실측

Google Cloud `Sprache` 프로젝트를 읽기 전용으로 다시 확인한 결과다.

- 클라이언트: Desktop `Sprache Windows`, Web `Sprache Server Audience`,
  Android `Sprache Android Debug`가 존재한다.
- Android 클라이언트의 패키지는 `com.youkdonghun.sprache`, SHA-1은 현재
  직접 설치용 Debug 인증서와 일치한다.
- 대상은 `외부`, 게시 상태는 `테스트 중`, 테스트 사용자는 프로젝트 소유자
  계정 1명이다.
- 비민감 범위는 `openid`, `userinfo.email`, `userinfo.profile`,
  `drive.file` 네 개다. 민감 범위와 제한된 범위는 없다.
- 브랜딩의 앱 이름·지원 이메일·개발자 연락처는 설정되어 있다.
- 애플리케이션 홈페이지, 개인정보처리방침, 승인된 도메인은 아직 비어 있다.
  Railway 공개 페이지는 앱에서 사용 중이지만 `railway.app`은 사용자 소유
  도메인이 아니므로 Google 운영 브랜드 인증 URL로 등록하지 않았다.
- 프로젝트 진단은 `Sprache Android Debug` 앱 소유권이 확인되지 않았다고
  표시한다. 직접 설치용 Debug 클라이언트는 기능 검증에 사용하고, Play 배포
  시 Play App Signing SHA-1로 별도 Android OAuth 클라이언트를 만든 뒤
  Play Console 연결로 앱 소유권을 확인한다.

공개 전 순서는 다음과 같다.

1. 소유권을 확인할 도메인을 정하고 Search Console에 등록한다.
2. Railway의 `/`, `/privacy`, `/terms`를 소유 custom domain에 연결한다.
3. 브랜딩에 두 URL과 승인된 도메인을 저장한다.
4. 앱 빌드의 `PRIVACY_POLICY_URL`을 같은 custom domain 주소로 교체한다.
5. 실제 계정·Drive 연속성 검증 뒤 게시·인증 필요 여부를 인증 센터에서 확인한다.
6. Play 배포용 클라이언트를 앱 소유권 확인하고 나서 공개 범위를 확대한다.

## 8. 2026-07-29 Windows 실계정 검증

- Railway에 Desktop client ID와 secret을 sealed variable로 등록했고
  `/health`의 `desktopOAuthBroker=ready`와 `WindowsGoogleLoginReady=True`를
  확인했다.
- Windows에서 Google 계정 동의, 동적 `127.0.0.1` loopback, Railway 토큰
  교환, Drive `BOM` 폴더 선택을 순서대로 완료했다.
- 선택 폴더의 기존 `WordStudyData`를 재사용해 원격 설정을 pull·검증·병합하고
  테스트 주제·문장·그룹을 push하는 E2E가 통과했다.
- 중국어 주제 ID `language:zh-hans`를 기본 주제 목록이 대소문자 차이로
  거부하던 문제를 수정했다. BCP 47 표시값 `zh-Hans`는 유지하고 내부 주제
  ID만 소문자 정규형을 사용한다.
- Google Drive가 공유 메타데이터 변경으로 파일 `version`만 올린 경우,
  manifest SHA-256과 실제 바이트가 같으면 정상 데이터로 처리한다. SHA까지
  달라졌을 때만 격리하거나 업로드 충돌로 중단한다.
- 새 secret으로 E2E 성공 후 2026-07-28에 생성한 이전 secret을 비활성화·
  삭제했다. 2026-07-29에 생성한 현재 secret 1개만 활성 상태다.
- OAuth 앱이 `테스트 중`이므로 `Google에서 확인하지 않은 앱` 경고는 현재
  테스트 사용자에게 나타날 수 있다. 공개 도메인과 정책 URL을 등록하고 게시·
  검증을 마치기 전까지는 등록된 테스트 계정만 사용한다.

## 9. 2026-07-29 Android 실계정 교차 기기 검증

- Android 16 에뮬레이터의 Google Play services에서 계정 선택과 동의를 완료했다.
- Railway의 기존 계정별 `WordStudyData` 연결을 조회한 뒤 Drive API로 실제 폴더를
  검증해 Picker 재선택 없이 연결했다.
- Windows에서 올린 사용자 콘텐츠
  `live-e2e-windows-android-marker-v1`을 Android에서 다운로드했다.
- Android 설정 화면에서 `연결됨`, 폴더 이름, 마지막 동기화 시각과
  업로드·다운로드·충돌 결정을 확인했다.
- 재연결과 `adb install -r` 업그레이드 뒤에도 같은 계정 연결·복원 흐름이
  다시 완료됐다.
- 물리 Android 기기의 최초 Picker 폴더 반환, 마이크·TTS·알림 권한은 공개 배포
  전에 별도로 반복한다.

## 10. 1.20.0 저장된 연결 자동 복구

앱 상태가 로드된 뒤 `driveConnected=true`이면 사용자가 설정 화면에서 다시
누르지 않아도 런타임 Drive 클라이언트를 복구한다.

- Android는 `attemptLightweightAuthentication()`으로 저장된 Google 계정을
  확인하고 ID Token으로 Railway의 기존 Drive 폴더 바인딩을 조회한다.
  `google_sign_in` 7.x에서 이 호출은 이름과 달리 완전한 무표시 복구를
  보장하지 않으며 Android Credential Manager가 One Tap 계정 확인 시트를
  표시할 수 있다.
- `drive.file` 권한이 이미 있으면 별도 Picker 없이 폴더 ID를 Drive API로
  검증하고 pull·merge·push를 진행한다.
- Windows는 OS 보안 저장소에 identity와 Drive 토큰이 모두 있을 때만 자동
  복구를 시도한다. 만료된 identity token은 Railway 무저장 OAuth broker로
  갱신하고 기존 폴더 ID를 다시 검증한다.
- 저장된 인증이 없거나 경량 인증이 완료되지 않으면 연결 기록과 정상 로컬
  데이터, 업로드 대기 작업을 지우지 않는다. 설정에는 `Google 다시 연결`과
  재시도 상태가 남는다.
- 일시적인 네트워크·Drive 장애는 안전한 백오프로 다시 시도하며, 손상 원격
  데이터가 정상 로컬 데이터를 덮어쓰지 않는 기존 검증·격리 규칙을 유지한다.

Android 16 에뮬레이터에서 1.20.0 APK를 `adb install -r`로 덮어 설치한 뒤
사용자 입력 없이 앱으로 복귀해 `연결됨`, `WordStudyData`, 마지막 동기화와
Windows 콘텐츠 마커가 유지되는 것을 확인했다. Google Play services의 보조
로그인 Activity가 일시적으로 활성화된 실행도 있었지만 계정 선택이나 동의
조작 없이 자동으로 앱으로 돌아왔다. 물리 기기에서는 제조사별 Credential
Manager 동작을 공개 배포 전에 다시 확인한다.

1.20.3 업그레이드 검증에서는 One Tap 계정 확인 시트가 실제로 한 번 표시됐다.
계정을 확인한 뒤 기존 `WordStudyData` 폴더를 새로 고르지 않고 재사용해
동기화를 완료했다. 이 시트를 취소해도 로컬 학습 데이터와 연결 기록은
유지되며 설정의 재연결 동작으로 다시 시도할 수 있다.
