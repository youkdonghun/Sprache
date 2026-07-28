# Railway 배포

저장소 루트의 `railway.toml`은 `services/api/Dockerfile`을 사용하고 `/health`를 확인한다. 컨테이너 시작 시 Prisma migration이 먼저 실행된다.

## 대시보드 방식

1. Railway에서 새 프로젝트를 만들고 GitHub 저장소 `youkdonghun/Sprache`를 연결한다.
2. PostgreSQL 서비스를 추가한다.
3. API 서비스 Variables에 아래 값을 넣는다.

```text
DATABASE_URL=${{Postgres.DATABASE_URL}}
GOOGLE_ALLOWED_CLIENT_IDS=<desktop-id>,<web-server-id>
USER_KEY_HMAC_SECRET=<비밀값>
NODE_ENV=production
LOG_LEVEL=info
```

4. Networking에서 public domain을 생성한다.
5. `https://<domain>/health`가 `{"status":"ok"}`를 반환하는지 확인한다.

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

실제 프로젝트 생성과 비밀값 등록은 Railway 계정 소유자가 수행해야 한다. 배포 후 public domain을 Flutter의 `API_BASE_URL`로 사용한다.
