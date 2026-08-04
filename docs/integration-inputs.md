# Google·Drive 연동 입력 정보

최종 수정: 2026-08-03

Sprache의 현재 연결에는 별도 API나 데이터베이스가 필요하지 않다. Windows
Desktop credential은 client secret을 요구하므로 값은 로컬 또는 CI의
`SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET` 프로세스 환경에서만 읽는다. 이 문서는
공개 식별자와 Google Cloud 등록 상태만 기록하며 실제 secret, 토큰, 인증 코드,
PKCE verifier, 서명 키와 비밀번호는 저장소·채팅·로그에 남기지 않는다.

## 공개 Google Cloud 설정

| 항목 | 현재 값 또는 상태 | 적용 위치 |
| --- | --- | --- |
| 프로젝트 ID | `keen-answer-503804-d2` | Google Cloud 운영 기록 |
| 앱 표시 이름 | `Sprache` | Google Auth Platform |
| Android client ID | `1054343487948-v3u90fo5nmbrk4hn7ss2gnrg601phkuv.apps.googleusercontent.com` | `GOOGLE_ANDROID_CLIENT_ID` |
| Android용 Web audience ID | `1054343487948-g6b3fp20ooq86agro7nsb129oqr9df82.apps.googleusercontent.com` | `GOOGLE_SERVER_CLIENT_ID` |
| Windows Desktop client ID | `1054343487948-o7nkfj4qmiilacvbln7alfgqrced6ior.apps.googleusercontent.com` | `GOOGLE_DESKTOP_CLIENT_ID` |
| iOS·macOS 공용 iOS client ID | `1054343487948-8ueu92l0ov3259rs8psun40c6iu4arel.apps.googleusercontent.com` | `GOOGLE_APPLE_CLIENT_ID` |
| Drive API | 활성화 | Google Cloud API |
| Google Picker API | 활성화 | Google Cloud API |
| 공개 홈페이지 | `https://sprache6.github.io/` | OAuth 브랜딩 |
| 개인정보처리방침 | `https://sprache6.github.io/privacy/` | 앱·OAuth 브랜딩 |
| 이용약관 | `https://sprache6.github.io/terms/` | OAuth 브랜딩 |

요청 범위는 계정 표시용 기본 identity 범위와 `drive.file`, `drive.appdata`다.
`drive.file`은 사용자가 선택했거나 Sprache가 만든 파일만 다루고,
`drive.appdata`는 `WordStudyData` 폴더 ID·이름 포인터만 저장한다. 전체 Drive
권한은 요청하지 않는다.

## Android 인증서 지문

| 용도 | 상태 | 값 또는 위치 |
| --- | --- | --- |
| 현재 1.34.1 debug SHA-1 | Google Cloud 등록·재조회 확인됨 (2026-08-03) | `EF:1E:2A:C5:22:FC:BF:65:53:DC:35:35:0E:36:04:4F:F3:BC:F3:E2` |
| 현재 1.34.1 debug SHA-256 | APK에서 확인됨 | `0D:9C:FD:91:41:3F:00:14:5A:9E:5D:BF:F6:40:56:A6:47:A5:F0:F5:17:36:32:3A:EB:FE:44:A5:37:8B:4E:68` |
| Play App Signing SHA-1·SHA-256 | Play 배포 전 등록 필요 | Play Console |

## 빌드 시 공개 입력

```text
APP_ENV=production
ENABLE_MOCK_MODE=false
GOOGLE_ANDROID_CLIENT_ID=<android-client-id>
GOOGLE_DESKTOP_CLIENT_ID=<desktop-client-id>
GOOGLE_APPLE_CLIENT_ID=<ios-client-id>
GOOGLE_SERVER_CLIENT_ID=<android-web-audience-id>
PRIVACY_POLICY_URL=https://sprache6.github.io/privacy/
SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET=<local-or-ci-secret>
```

두 플랫폼을 한 번에 만들 때는 저장소 루트에서 `npm run build:real`을 실행한다.
`SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET` 값은 저장소 파일이나 명령 인수에 쓰지
않고 현재 프로세스 환경에만 둔다. 빌드 스크립트는 값을 출력하지 않은 채
`GOOGLE_DESKTOP_CLIENT_SECRET` Dart define으로 전달한다. `API_BASE_URL`,
`DATABASE_URL`, HMAC secret과 Railway 변수는 사용하지 않는다.

## 연결 검증 순서

1. Google API 활성화, OAuth 클라이언트 유형, Android 패키지명·SHA를 대조한다.
2. Windows가 시스템 브라우저·loopback·PKCE로 Google에 직접 토큰을 교환하는지
   확인한다.
3. Android와 Windows에서 Drive 위치를 선택하고 `WordStudyData`가 생성·재사용되는지
   확인한다.
4. Apple configured preview는 iOS client ID와 callback scheme이 들어간 REAL
   빌드인지 검사하고, 실계정 로그인 미검증 상태를 evidence에 남긴다.
5. `appDataFolder`에는 `sprache-binding-v1.json` 포인터만 있고 학습 snapshot이나
   토큰이 없는지 확인한다.
6. 같은 계정의 두 번째 기기에서 포인터로 폴더를 찾고 pull·merge·push가 되는지
   확인한다.
7. 구버전 `drive.file` 토큰은 유효한 `WordStudyData`가 하나일 때 안전하게
   재발견하며, 다음 동의 뒤 포인터를 만드는지 확인한다.
8. Pages의 홈페이지·개인정보처리방침·약관이 로그인 없이 열리는지 확인한다.

## Railway 종료 기록

과거 `sprache-api`와 PostgreSQL은 Windows 토큰 중계와 계정–폴더 매핑에
사용했다. 현재 클라이언트·빌드·테스트에는 이 의존성이 없다. 새 릴리스의
교차 기기 복원과 공개 페이지를 검증한 뒤 Railway 프로젝트를 중단한다.
