# 보안 기준

- Google 인증과 Drive 권한 요청은 별도 사용자 동작으로 수행한다.
- Drive는 `drive.file`만 요청하고 사용자가 Picker에서 선택한 폴더만 사용한다.
- Windows는 시스템 브라우저, Authorization Code + PKCE, loopback callback, `state` 검증을 사용한다.
- Android는 Credential Manager로 인증하고 AuthorizationClient로 Drive 권한을 요청한다.
- Windows refresh/access/ID token은 OS 보안 저장소에 둔다. Android 토큰은 Google Identity 계층과 현재 연결 세션 메모리에서만 다룬다.
- Windows 데스크톱 Client Secret은 EXE·저장소에 넣지 않고 Railway sealed variable에만 둔다.
- Railway 토큰 중계는 HTTPS로 전달받은 PKCE 코드 또는 refresh token을 Google에 즉시 전달하고 응답을 클라이언트에 반환한다. 토큰을 DB·파일·캐시·로그에 저장하지 않으며 응답에는 `no-store`를 적용한다.
- Fastify 로그는 Authorization 헤더, ID/access/refresh token, authorization code, PKCE verifier를 명시적으로 가린다.
- API는 ID Token의 서명, issuer, audience, expiration, subject를 검증한다.
- Google `sub`는 서버 비밀값으로 HMAC-SHA256 처리한 뒤 PostgreSQL 키로 사용한다.
- PostgreSQL에는 학습 콘텐츠, 답안, 상세 진도, 이메일, 프로필, OAuth 토큰을 저장하지 않는다.
- `이 기기에서 연결 해제`는 이 기기의 토큰만 제거하고 계정 단위 Railway
  폴더 매핑은 다른 기기와 재연결을 위해 유지한다.
- `계정–Drive 연결 기록 삭제`를 명시적으로 확인하면 이 기기의 토큰과
  Railway 매핑을 함께 제거하되 Drive 폴더와 로컬 파일은 삭제하지 않는다.
