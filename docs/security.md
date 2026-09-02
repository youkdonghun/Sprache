# 보안 기준

- Google 인증과 Drive 권한 요청은 별도 사용자 동작으로 수행한다.
- Drive는 `drive.file`로 사용자가 선택했거나 Sprache가 만든 파일만 다루고,
  `drive.appdata`로 `WordStudyData` 폴더 포인터만 관리한다.
- Windows는 시스템 브라우저, Authorization Code + PKCE, loopback callback, `state` 검증을 사용한다.
- Android는 Credential Manager로 인증하고 AuthorizationClient로 Drive 권한을 요청한다.
- Windows refresh/access/ID token은 OS 보안 저장소에 둔다. Android 토큰은 Google Identity 계층과 현재 연결 세션 메모리에서만 다룬다.
- Windows는 공개 Desktop Client ID와 PKCE 인증 코드를 Google 토큰
  엔드포인트에 직접 보낸다. 설치형 앱은 client secret을 보관할 수 없는 공개
  클라이언트이므로 별도 secret을 빌드나 배포 파일에 포함하지 않는다.
- iOS·macOS configured preview는 REAL 모드와 OAuth metadata를 검사하지만,
  실계정 로그인을 자동 검증하지 않은 상태를 evidence에 명시한다.
- 인증 코드, access/refresh token과 PKCE verifier를 진단·로그에 남기지 않는다.
- `이 기기에서 연결 해제`는 이 기기의 토큰만 제거하고 Drive 폴더와 숨김 연결
  포인터는 다른 기기와 재연결할 수 있도록 유지한다.
- `Drive 연결 기록 삭제`는 숨김 포인터와 이 기기 인증을 제거하되
  `WordStudyData`와 로컬 파일은 삭제하지 않는다.
