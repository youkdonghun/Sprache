# Google·Railway 연동 입력 정보

최종 수정: 2026-07-28  
현재 상태: Railway API 운영 배포 완료, Google OAuth 입력 대기

이 문서는 실제 연동에 필요한 항목과 수신 상태만 기록한다. **클라이언트 시크릿, 데이터베이스 URL, HMAC 시크릿, 개인 키의 실제 값은 저장소나 채팅에 기록하지 않는다.** 비밀값은 Google Cloud 또는 Railway의 비밀 변수 저장소에 직접 입력하고, 여기에는 `등록 완료`와 저장 위치만 남긴다.

사용자가 “연동 정보 불러와”, “Google/Railway 값 보여줘”라고 말하면 Codex는 이 파일을 먼저 읽고 미입력 항목과 다음 작업을 알려 준다.

## Google Cloud 공개 설정

| 항목 | 필요한 값 | 상태 | 적용 위치 |
| --- | --- | --- | --- |
| 프로젝트 ID | Google Cloud project ID | 미입력 | 운영 기록 |
| 앱 표시 이름 | OAuth 동의 화면 앱 이름 | 미입력 | Google Cloud |
| 지원 이메일 | OAuth 동의 화면 지원 이메일 | 미입력 | Google Cloud |
| 개인정보처리방침 URL | 운영 공개 URL | 미입력 | OAuth 동의 화면 |
| Android OAuth client ID | 패키지 `com.youkdonghun.sprache`용 client ID | 미입력 | `GOOGLE_ANDROID_CLIENT_ID` |
| Web/서버 OAuth client ID | ID token의 서버 audience용 client ID | 미입력 | `GOOGLE_SERVER_CLIENT_ID` |
| Desktop OAuth client ID | Windows OAuth용 client ID | 미입력 | `GOOGLE_DESKTOP_CLIENT_ID` |
| OAuth 테스트 사용자 | 테스트 계정 이메일 목록 | 미입력 | OAuth 동의 화면 |
| Drive API | 활성화 여부 | 미확인 | Google Cloud API |
| Google Picker API | 활성화 여부 | 미확인 | Google Cloud API |

### Android 인증서 지문

| 용도 | 상태 | 값 또는 위치 |
| --- | --- | --- |
| 현재 로컬 debug SHA-1 | 확인됨 | `AB:64:24:D5:FC:BA:3F:76:2C:27:C2:BE:61:3D:1A:A9:C8:4F:1F:AE` |
| 현재 로컬 debug SHA-256 | 확인됨 | `50:F4:24:78:D5:25:4A:C6:92:18:11:E2:53:17:83:3E:F2:DB:18:C4:11:DC:92:C7:B8:EF:7D:8B:0A:B2:A0:D2` |
| Play App Signing SHA-1 | 미입력 | Play Console에서 발급 후 등록 |
| Play App Signing SHA-256 | 미입력 | Play Console에서 발급 후 등록 |

## Railway 공개 설정

| 항목 | 필요한 값 | 상태 | 적용 위치 |
| --- | --- | --- | --- |
| Railway 프로젝트 이름 | 프로젝트 식별용 이름 | `Sprache` (`cfb13a72-2f18-42a9-bfaa-9437079a752d`) | Railway |
| API 서비스 이름 | Node API 서비스 이름 | `sprache-api` 운영 배포 완료 (`main` / `b8c7f65`) | Railway |
| PostgreSQL 서비스 이름 | DB 서비스 이름 | `Postgres` 생성 완료·Online | Railway |
| Railway 공개 API URL | `https://...up.railway.app` 또는 커스텀 도메인 | `https://sprache-api-production.up.railway.app` | Flutter `API_BASE_URL` |
| 커스텀 도메인 | 사용할 경우 도메인 | 미입력 | Railway/Flutter |
| 배포 리전 | Railway 서비스 리전 | API `US East` | Railway |

### Railway 배포 확인

| 확인 항목 | 결과 |
| --- | --- |
| GitHub 소스 | `youkdonghun/Sprache`, `main`, commit `b8c7f65` |
| Prisma migration | `20260727000000_init` 적용 완료 |
| 런타임 포트 | Railway 주입 `PORT=8080` |
| 공개 health check | `GET /health` → HTTP 200, `{"status":"ok","service":"sprache-api"}` |

## Railway 비밀 변수

실제 값은 Railway Variables에 직접 넣는다.

| 변수 | 요구사항 | 상태 | 비밀값 저장 위치 |
| --- | --- | --- | --- |
| `DATABASE_URL` | Railway PostgreSQL 연결 문자열 | 등록 완료 (`Postgres.DATABASE_URL` 참조) | Railway Variables |
| `GOOGLE_ALLOWED_CLIENT_IDS` | 허용할 Android·Desktop·Web client ID의 쉼표 목록 | 임시 fail-closed 값 등록, 실제 OAuth ID로 교체 필요 | Railway Variables |
| `USER_KEY_HMAC_SECRET` | 32바이트 이상 무작위 비밀값 | 등록 완료 | Railway Variables |
| `NODE_ENV` | `production` | 등록 완료 | Railway Variables |
| `LOG_LEVEL` | `info` | 등록 완료 | Railway Variables |
| `PORT` | Railway가 주입하므로 보통 수동 입력 불필요 | 자동 | Railway |

## 빌드 시 공개 입력

Mock 빌드는 이 값 없이 실행된다. 실연동 빌드는 아래 `--dart-define` 값을 사용한다.

| 변수 | 현재 상태 | 출처 |
| --- | --- | --- |
| `ENABLE_MOCK_MODE=false` | 준비됨 | 고정 |
| `API_BASE_URL` | `https://sprache-api-production.up.railway.app` | Railway 공개 API URL |
| `GOOGLE_ANDROID_CLIENT_ID` | 미입력 | Google Cloud |
| `GOOGLE_DESKTOP_CLIENT_ID` | 미입력 | Google Cloud |
| `GOOGLE_SERVER_CLIENT_ID` | 미입력 | Google Cloud |

```powershell
Push-Location apps/client
flutter build apk --release `
  --dart-define=ENABLE_MOCK_MODE=false `
  --dart-define=API_BASE_URL=https://YOUR-API `
  --dart-define=GOOGLE_ANDROID_CLIENT_ID=YOUR-ANDROID-ID `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR-WEB-ID
Pop-Location
```

```powershell
Push-Location apps/client
flutter build windows --release `
  --dart-define=ENABLE_MOCK_MODE=false `
  --dart-define=API_BASE_URL=https://YOUR-API `
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR-DESKTOP-ID `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR-WEB-ID
Pop-Location
```

## 입력을 받은 뒤 실행할 순서

1. 이 문서의 공개값과 상태를 갱신한다.
2. Google API 활성화, OAuth 유형, 패키지명, 인증서 지문을 대조한다.
3. Railway 환경 변수는 값 자체를 읽거나 출력하지 않고 등록 여부만 확인한다.
4. Railway `/health`와 인증이 필요한 API의 성공·거부 경계를 확인한다.
5. Android와 Windows 실연동 빌드를 각각 만든다.
6. 같은 Google 계정으로 두 기기에서 Drive 폴더 선택·업로드·다운로드·충돌 복구를 검증한다.
