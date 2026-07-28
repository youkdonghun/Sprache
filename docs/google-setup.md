# Google Cloud 연결 설정

앱은 로그인과 Drive 권한을 분리하고 Drive에는 `drive.file`만 요청한다. Google Drive API와 Google Picker API의 현재 설정 방식은 [Drive 범위 가이드](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)와 [데스크톱·모바일 Picker 가이드](https://developers.google.com/workspace/drive/picker/guides/desktop-mobile-picker)를 따른다.

## 1. Google Cloud 프로젝트

1. Google Cloud에서 프로젝트를 만든다.
2. Google Auth Platform의 Branding, Audience, Data Access를 채운다.
3. 테스트 중이면 사용할 Google 계정을 테스트 사용자에 추가한다.
4. Google Drive API와 Google Picker API를 활성화한다.

## 2. OAuth 클라이언트 3개

### Android 클라이언트

- 애플리케이션 ID: `com.youkdonghun.sprache`
- 현재 로컬 debug SHA-1: `AB:64:24:D5:FC:BA:3F:76:2C:27:C2:BE:61:3D:1A:A9:C8:4F:1F:AE`
- Play 배포 때는 Play App Signing SHA-1로 별도 Android 클라이언트를 추가한다.

로컬 인증서 재확인:

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -list -v `
  -alias androiddebugkey `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -storepass android -keypass android
```

### Web application 클라이언트

Android Credential Manager가 ID Token을 서버 대상으로 발급할 때 쓰는 클라이언트다. JavaScript origin과 redirect URI는 비워도 된다. 이 ID를 `GOOGLE_SERVER_CLIENT_ID`에 넣는다.

### Desktop app 클라이언트

Windows 시스템 브라우저 PKCE + loopback 콜백에 쓴다. 이 ID를 `GOOGLE_DESKTOP_CLIENT_ID`에 넣는다.

## 3. Railway API 환경변수

```text
DATABASE_URL=${{Postgres.DATABASE_URL}}
GOOGLE_ALLOWED_CLIENT_IDS=<desktop-client-id>,<web-server-client-id>
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

출력은 저장소나 채팅에 붙이지 말고 Railway의 sealed variable로만 저장한다.

## 4. 실제 연결 빌드

```powershell
flutter build apk --release `
  --dart-define=ENABLE_MOCK_MODE=false `
  --dart-define=API_BASE_URL=https://YOUR-RAILWAY-DOMAIN `
  --dart-define=GOOGLE_ANDROID_CLIENT_ID=YOUR-ANDROID-ID `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR-WEB-ID

flutter build windows --release `
  --dart-define=ENABLE_MOCK_MODE=false `
  --dart-define=API_BASE_URL=https://YOUR-RAILWAY-DOMAIN `
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR-DESKTOP-ID
```

## 5. 연결 검증

1. 로그인 전 샘플 학습이 되는지 확인한다.
2. 설정에서 Google 연결을 누른다.
3. 인증 후 Drive 권한 요청이 별도로 나타나는지 확인한다.
4. 기존 폴더 하나를 선택한다.
5. 선택 폴더 아래 `WordStudyData/state/snapshot.json`과 `manifest.json`이 생겼는지 확인한다.
6. 다른 기기에서 같은 계정·폴더를 선택하고 XP와 진도가 합쳐지는지 확인한다.
7. 권한 취소 후에도 오프라인 학습이 계속되고 재동기화 오류만 표시되는지 확인한다.
