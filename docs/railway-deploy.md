# Railway 배포

저장소 루트의 `railway.toml`은 `services/api/Dockerfile`을 사용하고 `/health`를 확인한다. 컨테이너 시작 시 Prisma migration이 먼저 실행된다.

## 대시보드 방식

1. Railway에서 새 프로젝트를 만들고 GitHub 저장소 `youkdonghun/Sprache`를 연결한다.
2. PostgreSQL 서비스를 추가한다.
3. API 서비스 Variables에 아래 값을 넣는다.

```text
DATABASE_URL=${{Postgres.DATABASE_URL}}
GOOGLE_ALLOWED_CLIENT_IDS=<desktop-id>,<web-server-id>
GOOGLE_DESKTOP_CLIENT_ID=<desktop-id>
GOOGLE_DESKTOP_CLIENT_SECRET=<Google Cloud 데스크톱 클라이언트 secret>
USER_KEY_HMAC_SECRET=<비밀값>
NODE_ENV=production
LOG_LEVEL=info
```

4. Networking에서 public domain을 생성한다.
5. `https://<domain>/health`가 `status=ok`와
   `desktopOAuthBroker=ready`를 반환하는지 확인한다.

`GOOGLE_DESKTOP_CLIENT_SECRET`은 Google Cloud에서 확인한 값을 Railway sealed
variable에 직접 입력한다. 저장소, 채팅, Flutter `--dart-define`, 빌드 로그에는
복사하지 않는다. Fastify API는 이 값을 Google 토큰 요청에만 사용하며 코드,
refresh token, access token, ID token을 PostgreSQL에 저장하지 않는다.

## CLI 방식

현재 Railway CLI 기준으로 사용자 코드는 `railway up`, PostgreSQL 템플릿은 `railway add -d postgres`를 사용한다. 자세한 옵션은 [Railway up](https://docs.railway.com/cli/up), [서비스 추가](https://docs.railway.com/cli/add), [변수 관리](https://docs.railway.com/cli/variable)를 참고한다.

```powershell
railway login
railway init
railway add -d postgres
railway add -s sprache-api
railway up --service sprache-api
railway domain --service sprache-api
railway logs --service sprache-api
```

실제 프로젝트 생성과 비밀값 등록은 Railway 계정 소유자가 수행해야 한다. 배포 후
public domain을 Flutter의 `API_BASE_URL`로 사용한다. Windows 앱은 Google 로그인
전에 `/health`를 확인하고 중계가 준비되지 않았으면 브라우저를 열지 않는다.
