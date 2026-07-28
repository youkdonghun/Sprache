# 보안 기준

- Google 인증과 Drive 권한 요청은 별도 사용자 동작으로 수행한다.
- Drive는 `drive.file`만 요청하고 사용자가 Picker에서 선택한 폴더만 사용한다.
- Windows는 시스템 브라우저, Authorization Code + PKCE, loopback callback, `state` 검증을 사용한다.
- Android는 Credential Manager로 인증하고 AuthorizationClient로 Drive 권한을 요청한다.
- Windows refresh/access/ID token은 OS 보안 저장소에 둔다. Android 토큰은 Google Identity 계층과 현재 연결 세션 메모리에서만 다룬다.
- 토큰은 로그에 남기지 않으며 API에는 계정 검증용 ID Token만 Authorization 헤더로 보낸다.
- API는 ID Token의 서명, issuer, audience, expiration, subject를 검증한다.
- Google `sub`는 서버 비밀값으로 HMAC-SHA256 처리한 뒤 PostgreSQL 키로 사용한다.
- PostgreSQL에는 학습 콘텐츠, 답안, 상세 진도, 이메일, 프로필, OAuth 토큰을 저장하지 않는다.
- 계정 연결 해제는 서버 매핑과 로컬 토큰을 제거하되 Drive 폴더는 별도 확인 없이는 삭제하지 않는다.
