# Google Cloud와 GitHub Pages 연결 설정

Sprache는 중앙 API 없이 Google OAuth와 Drive API를 클라이언트에서 직접
사용한다. 학습 데이터의 작업 원본은 항상 SQLite이며, Google 연결은 Drive의
`WordStudyData` 폴더를 이용한 선택적 기기 간 동기화다. 사용자가 일반 Drive
위치를 고르고, 숨겨진 `appDataFolder`에는 그 폴더를 다시 찾기 위한 포인터만 둔다.

공식 기준은 [데스크톱 앱 OAuth·PKCE](https://developers.google.com/identity/protocols/oauth2/native-app),
[Drive 앱 전용 데이터](https://developers.google.com/workspace/drive/api/guides/appdata),
[Drive 권한 선택](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)을
따른다.

## 1. 데이터 흐름

1. Google 미연결 상태에서도 SQLite와 사용자가 설정한 로컬 백업 폴더로 모든
   학습 기능을 사용할 수 있다.
2. Google 연결을 선택하면 플랫폼의 OAuth 흐름으로 계정과 권한을 확인한다.
3. Windows 인증 코드는 PKCE와 Google이 발급한 Desktop client 자격정보로
   Google 토큰 엔드포인트에 직접 교환한다. Android와 Apple은 플랫폼용
   Google Sign-In 자격 증명을 사용한다.
4. 사용자가 Drive Picker에서 위치를 고르면 앱이 `WordStudyData`를 만들거나
   기존 앱 폴더를 재사용하고, 그 안의 snapshot을 검증·병합·갱신한다.
5. `appDataFolder`에는 `WordStudyData`의 폴더 ID·이름 포인터만 기록해 다른
   기기에서 같은 폴더를 다시 찾는다.
6. 토큰은 OS 보안 저장소에만 두며, 계정 ID·Drive 파일 ID·학습 자료를 별도
   Sprache 서버에 보내지 않는다.

로컬 폴더와 Google Drive의 차이는 설정 화면에서도 분리한다.

- **로컬 백업 폴더:** 사용자가 경로를 직접 고르고 언제든 `변경`할 수 있다.
- **Google Drive 저장 위치:** 연결할 때 Picker로 위치를 고르고, 이후 설정에서
  현재 폴더 이름을 확인하거나 다시 선택할 수 있다.
- **Drive 숨김 연결 설정:** 사용자가 직접 경로를 정하지 않는다. 앱은 여기에
  학습 자료가 아닌 `WordStudyData` 폴더 포인터만 저장한다.

## 2. Google Cloud 프로젝트

1. Google Cloud Console에서 Sprache 프로젝트를 선택한다.
2. **Google Drive API**를 활성화한다.
3. Google Auth Platform의 대상 사용자를 외부로 설정하고 개발 중에는 필요한
   테스트 사용자를 등록한다.
4. 데이터 액세스에 다음 범위만 등록한다.

```text
openid
email
profile
https://www.googleapis.com/auth/drive.file
https://www.googleapis.com/auth/drive.appdata
```

`drive.file`은 사용자가 선택했거나 Sprache가 만든 파일만 다루는 범위이고,
`drive.appdata`는 숨겨진 연결 포인터용 범위다. 전체 Drive 권한은 요청하지 않는다.
Google Picker API와 Drive API는 모두 활성화해야 한다.

## 3. OAuth 클라이언트

Android, Windows와 Apple 클라이언트를 **같은 Google Cloud 프로젝트**에 만든다.

### Android

- 애플리케이션 ID: `com.youkdonghun.sprache`
- 직접 설치용 debug SHA-1과 Play App Signing SHA-1은 서로 다른 Android OAuth
  클라이언트로 등록한다.
- 공개 배포 전 Play Console 연결로 앱 소유권을 확인한다.
- Android Google Sign-In 초기화에는 같은 프로젝트의 Web client ID를 공개
  audience 값으로 쓴다. ID token을 Sprache 서버로 보내거나 검증하지는 않는다.

인증서 확인 예시:

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -list -v `
  -alias androiddebugkey `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -storepass android -keypass android
```

### Windows

- 애플리케이션 유형은 **Desktop app**으로 만든다.
- `1.34.1`에서 사용하는 Client ID는
  `1054343487948-o7nkfj4qmiilacvbln7alfgqrced6ior.apps.googleusercontent.com`이다.
- 이 credential이 발급한 client secret은
  `SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET` 프로세스 환경변수로만 빌드와 실계정
  E2E에 전달한다. Flutter에는 현재 사용자만 읽을 수 있는 임시
  `--dart-define-from-file`로 넘기고 즉시 0으로 덮어쓴 뒤 삭제한다. 값을
  매개변수, 저장소, 문서, 채팅 또는 로그에 쓰지 않는다.
- callback은 `http://127.0.0.1:<동적 포트>`의 경로 없는 loopback을 사용한다.
- 매 로그인마다 43~128자의 고엔트로피 verifier, `S256` challenge와 무작위
  `state`를 새로 만든다.

이 PC처럼 PowerShell 실행 정책이 제한된 Windows에서 DPAPI 보관값으로 실계정
E2E를 다시 실행할 때는 다음 명령을 사용한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\run-live-google-e2e-local.ps1
```

인가 요청의 핵심 값:

```text
https://accounts.google.com/o/oauth2/v2/auth
response_type=code
client_id=<desktop-client-id>
redirect_uri=http://127.0.0.1:<ephemeral-port>
scope=https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/drive.appdata
state=<random>
code_challenge=<base64url-sha256-verifier>
code_challenge_method=S256
access_type=offline
```

앱은 callback의 정확한 origin, port, 경로, `state`와 오류 응답을 먼저 검증한다.
그 뒤 Google 토큰 엔드포인트에 직접 다음 form을 보낸다.

```text
POST https://oauth2.googleapis.com/token
client_id=<desktop-client-id>
client_secret=<desktop-client-secret>
code=<authorization-code>
code_verifier=<original-verifier>
grant_type=authorization_code
redirect_uri=http://127.0.0.1:<same-port>
```

Google 문서상 설치형 client는 비밀을 안전하게 보관할 수 없는 공개
클라이언트다. 따라서 이 값은 서버 비밀이나 사용자 데이터 보호 경계로 간주하지
않는다. 다만 현재 발급된 Desktop credential의 토큰 교환 조건에 맞춰 전송하며,
빌드 자동화는 값의 존재만 확인하고 출력하지 않는다. refresh도 `client_id`,
`client_secret`, `refresh_token`, `grant_type=refresh_token`을 같은 엔드포인트로
직접 보내고 응답 토큰을 즉시 OS 보안 저장소에 갱신한다.

### iOS·macOS

- iOS 유형의 공용 Client ID는
  `1054343487948-8ueu92l0ov3259rs8psun40c6iu4arel.apps.googleusercontent.com`이다.
- 두 앱의 Bundle ID는 `com.youkdonghun.sprache`이며 Dart define은
  `GOOGLE_APPLE_CLIENT_ID`를 사용한다.
- Google callback scheme은
  `com.googleusercontent.apps.1054343487948-8ueu92l0ov3259rs8psun40c6iu4arel`이다.
- Codemagic의 iOS Simulator와 macOS 앱은 `ENABLE_MOCK_MODE=false`로 빌드해
  Client ID·URL scheme·번들 설정을 검사한다. 계정 선택과 Drive 왕복은 자동화된
  첫 프레임 검사에서 수행하지 않으므로 evidence에
  `googleOAuthRuntimeVerified=false`를 반드시 남긴다.
- iOS ZIP은 Simulator 전용이고 macOS ZIP은 ad-hoc 서명 상태다. 이 산출물을
  기기용 IPA, Developer ID 서명본 또는 공증 배포본으로 표시하지 않는다.

## 4. Drive 저장 폴더와 `appDataFolder`

연결 후의 Drive API 규칙은 다음과 같다.

- Picker: 사용자가 고른 상위 폴더 아래에서 `WordStudyData`를 만들거나 검증된
  기존 폴더를 재사용한다.
- 학습 데이터: `WordStudyData` 안의 manifest와 snapshot 파일 ID를 기준으로
  읽고 쓰며 표시 경로를 식별자로 사용하지 않는다.
- 숨김 포인터: `appDataFolder`의 `sprache-binding-v1.json`에는 폴더 ID·이름,
  포인터 schema와 갱신 시각만 저장한다.
- 자동 복원: 포인터의 폴더를 먼저 검증한다. 포인터가 없으면 접근 가능한
  `WordStudyData` 중 유효한 후보가 정확히 하나일 때만 연결한다.
- 안전: 중복 포인터, 손상된 manifest, 미래 schema는 자동 덮어쓰기하지 않는다.
- 삭제: 연결 포인터 삭제와 Drive 학습 폴더 삭제는 서로 다른 동작이다. 포인터를
  지워도 `WordStudyData`와 로컬 자료는 남는다.

구버전 사용자는 기존 `drive.file` 권한으로 `WordStudyData`를 찾아 학습을
이어갈 수 있다. 다음 명시적 Google 동의에서 `drive.appdata` 권한을 받은 뒤
포인터를 추가한다. 검증이 끝나기 전에는 기존 Drive 폴더나 로컬 백업을 지우지
않는다.

## 5. 정적 공개 페이지

공개 앱 문서는 저장소의 `docs` 폴더에서 GitHub Pages로 제공한다.

| 용도 | URL |
| --- | --- |
| 앱 홈페이지 | `https://sprache6.github.io/` |
| 개인정보처리방침 | `https://sprache6.github.io/privacy/` |
| 서비스 이용약관 | `https://sprache6.github.io/terms/` |

GitHub 저장소의 **Settings → Pages**에서 다음처럼 설정한다.

1. Source: **Deploy from a branch**
2. Branch: 공개할 기본 branch
3. Folder: **`/docs`**
4. 저장 후 위 세 URL이 로그인 없이 열리는지 확인

Actions workflow는 만들지 않는다. HTML 내부 링크는 `/privacy/` 같은 도메인
루트 경로가 아니라 `./privacy/`, `../terms/` 같은 상대 경로를 사용해야 프로젝트
경로 `/Sprache/`가 유지된다.

Google Auth Platform 브랜딩에는 위 홈페이지·개인정보처리방침·약관 URL과
개발자 연락처를 등록한다. Google이 요구하는 방식으로
`sprache6.github.io`의 사이트 소유권을 확인하고 승인된 도메인과 공개 범위를
최종 검토한다.

## 6. 빌드 설정

실연결 빌드에는 플랫폼 client ID, 공개 정책 URL과 Windows Desktop credential의
빌드 환경값이 필요하다.

```text
GOOGLE_ANDROID_CLIENT_ID=<android-client-id>
GOOGLE_DESKTOP_CLIENT_ID=<desktop-client-id>
GOOGLE_APPLE_CLIENT_ID=<ios-client-id>
GOOGLE_SERVER_CLIENT_ID=<android-google-sign-in-audience>
PRIVACY_POLICY_URL=https://sprache6.github.io/privacy/
SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET=<local-or-ci-secret>
```

`SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET`은 스크립트가 읽는 환경변수이고 앱에는
`GOOGLE_DESKTOP_CLIENT_SECRET` Dart define으로 전달된다. 실제 값은 설정 파일이나
manifest에 복사하지 않는다. `API_BASE_URL`과 Railway 변수는 사용하지 않는다.
`GOOGLE_SERVER_CLIENT_ID`는 Android Google Sign-In 초기화에 쓰는 공개 audience
ID이며 서버 배포를 뜻하지 않는다. 토큰, 인증 코드, verifier, client secret과
사용자의 계정 정보는 빌드·진단 로그에 출력하지 않는다.

## 7. 연결 검증

1. Google 미연결 상태에서 샘플 학습, 사용자 자료 등록과 재시작 복원이 된다.
2. 설정에서 로컬 백업 폴더 주소가 보이고 `변경`으로 다른 경로를 고를 수 있다.
3. Windows 로그인 시 시스템 브라우저와 동적 loopback이 열리고 callback의
   `state`가 일치한다. token 요청에는 필요한 Desktop credential이 포함되지만
   그 값이나 OAuth 토큰이 네트워크·앱 진단 로그에 노출되지 않고 Railway 요청도
   발생하지 않는다.
4. Android에서 등록된 패키지·SHA의 계정 선택과 `drive.file`·`drive.appdata`
   동의가 된다.
5. 연결 후 선택한 위치의 `WordStudyData`에 manifest와 snapshot이 생성되고,
   `appDataFolder`에는 연결 포인터 하나만 생성된다.
6. Apple configured preview는 Client ID, callback scheme, REAL 모드와 첫 프레임을
   검사하되 실계정 OAuth를 완료했다고 기록하지 않는다.
7. 다른 플랫폼에서 같은 계정으로 연결하면 포인터로 기존 폴더를 찾아
   XP·진도·사용자 자료를 안전하게 병합한다.
8. 손상 checksum, 미래 schema, 네트워크 단절과 토큰 만료가 정상 로컬 자료를
   덮어쓰거나 삭제하지 않는다.
9. 이 기기 연결 해제 뒤 토큰은 제거되지만 로컬 자료, Drive 학습 폴더와 연결
   포인터는 보존된다.
10. 연결 기록 삭제는 숨김 포인터만 지우고, Drive 학습 폴더 삭제는 별도 확인을
   거친다.
11. Pages의 홈페이지에서 개인정보처리방침과 약관으로, 각 문서에서 홈으로
    이동하는 링크가 모두 `/Sprache/` 아래에서 열린다.
