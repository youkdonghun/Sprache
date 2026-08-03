# Railway 제거와 GitHub Pages 배포

이 문서는 과거 링크 호환을 위해 파일 이름을 유지하지만, Sprache의 현재 목표
구조에는 Railway 배포가 없다. OAuth 인증 코드는 클라이언트가 PKCE로 Google에
직접 교환한다. 학습 자료는 사용자가 고른 `WordStudyData`에 저장하고,
`appDataFolder`에는 이 폴더를 다시 찾기 위한 연결 포인터만 둔다.
공개 홈페이지·개인정보처리방침·약관만 GitHub Pages가 정적으로 제공한다.

## 제거 완료 조건

Railway 서비스를 중단하기 전에 다음 조건을 모두 확인한다.

1. Windows가 client secret 없이 PKCE 직접 토큰 교환과 refresh를 완료한다.
2. Android가 중앙 ID token 검증 없이 Drive 권한과 동기화를 완료한다.
3. 새 기기가 같은 계정의 `appDataFolder` 포인터로 `WordStudyData`를 찾아
   복원한다.
4. 기존 Picker 폴더 자료를 그대로 검증·병합하고 snapshot을 재다운로드해 checksum을
   확인한다. 기존 폴더와 로컬 백업은 자동 삭제하지 않는다.
5. 앱과 빌드 스크립트에서 `API_BASE_URL`, Railway health check와 토큰 broker
   의존성이 제거된다. Android 인증용 공개 Web client ID는 서버 의존성이 아니다.
6. 저장소·CI·배포 설정에 Railway 비밀 변수 이름이나 실제 값이 남지 않는다.
7. GitHub Pages 공개 문서 세 개와 앱 내부 개인정보처리방침 링크가 정상이다.

## Railway 종료 순서

1. 새 버전으로 Windows·Android 실계정 교차 기기 복원과 오프라인 재시도를
   검증한다.
2. 구버전에서 새 버전으로 덮어 설치해 로컬 DB, 토큰 교체, 기존 Drive 폴더
   재발견과 `appDataFolder` 포인터 생성을 검증한다.
3. Railway API로 향하는 새 클라이언트 요청이 없음을 로그의 요청 수와 로컬
   네트워크 검사로 확인한다.
4. Google Cloud에서 서버 audience 전용 Web client와 desktop client secret이
   더는 쓰이지 않는지 확인한 뒤 폐기한다.
5. Railway의 `GOOGLE_DESKTOP_CLIENT_SECRET`, `USER_KEY_HMAC_SECRET`,
   `DATABASE_URL`과 기타 변수를 폐기하고 API·PostgreSQL 서비스를 중단한다.
6. 필요한 감사 기록만 비밀값 없이 보존한 뒤 프로젝트 삭제 여부를 결정한다.

서비스 중단은 기존 학습 파일 삭제 권한을 의미하지 않는다. 사용자 SQLite,
로컬 백업, 기존 Drive 폴더와 새 `appDataFolder` 포인터는 각각 검증된 마이그레이션 또는
사용자의 명시적 삭제 전까지 보존한다.

## GitHub Pages 배포

Sprache 소스 저장소는 비공개로 유지한다. 무료 Pages를 위해 소스 저장소의
visibility를 바꾸지 않고, 공개 문서만 담는 `youkdonghun/youkdonghun.github.io`
저장소를 사용한다. 이 저장소의 `main` root가 Pages 원본이다.

현재 저장소의 `docs/index.html`, `docs/privacy/index.html`,
`docs/terms/index.html`과 `.nojekyll`을 공개 저장소의 `Sprache/` 아래에 같은
구조로 복사한다. 공개 저장소 root에도 같은 문서를 두어 사용자 사이트의 루트
주소가 404가 되지 않게 한다. 앱 소스, 빌드 로그, 토큰과 과거 Railway 문서는
공개 저장소에 복사하지 않는다.

배포 URL:

- 홈페이지: `https://youkdonghun.github.io/Sprache/`
- 개인정보처리방침: `https://youkdonghun.github.io/Sprache/privacy/`
- 서비스 이용약관: `https://youkdonghun.github.io/Sprache/terms/`

기존 `app-homepage.html`과 `privacy-policy.html`은 오래된 링크를 새 canonical
URL로 보내는 호환 페이지다. 새 링크와 OAuth 브랜딩에는 directory URL을 쓴다.

## 정적 페이지 검증

로컬에서는 저장소 루트를 HTTP로 열고 `/docs/`를 Pages base로 간주해 검사한다.
게시 후에는 공개 저장소의 `Sprache/` 경로와 아래 canonical URL을 다시 검사한다.
`file://`로만 열면 directory index와 project base 동작을 충분히 검증할 수 없다.

확인 항목:

- 세 canonical URL이 HTTP 200이고 로그인·JavaScript 없이 본문이 보인다.
- 홈페이지 → 개인정보처리방침·약관 → 홈페이지 링크가 `/Sprache/` 밖으로
  벗어나지 않는다.
- 새 앱 빌드와 공개 정적 페이지에 운영 Railway endpoint, client secret 또는 실제
  토큰이 없다. 과거 검증 기록의 endpoint는 이관 이력으로만 남긴다.
- 정적 페이지에 폼, 쿠키, 분석 스크립트와 OAuth callback 처리 코드가 없다.
- 모바일 폭, 큰 글자와 라이트·다크 모드에서 읽을 수 있다.

## 롤백 원칙

Pages 장애는 앱의 로컬 학습이나 Drive 동기화 경로와 분리한다. OAuth 공개 문서
문제를 고치기 위해 client secret을 앱에 넣거나 Railway broker를 임시 복원하지
않는다. 직접 OAuth 또는 Drive migration에 문제가 있으면 Google 연결만 안전하게
중지하고 SQLite와 업로드 대기열을 보존한 채 수정 버전을 배포한다.
