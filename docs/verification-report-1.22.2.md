# Sprache 1.22.2 검증 보고서

검증일: 2026-07-30

## 구현 범위

- 버전 `1.22.2+40`
- Railway API 공개 경로 `/`, `/privacy`, `/terms` 추가
- 공개 페이지에 앱 기능, Google 데이터 사용 목적, `drive.file` 최소 범위,
  Railway 저장 범위, 연결 해제·삭제 방법과 문의 경로 표시
- Android·Windows 실서비스 빌드에 공개 개인정보처리방침 URL 포함
- 앱 내부 개인정보 고지의 오래된 1.19.3 표기를 현재 빌드 버전으로 교체

## Railway·Google 실측

- GitHub 커밋 `a2bdd34`를 `main`에 푸시하고 Railway 자동 배포 성공
- 배포 `Publish OAuth branding pages from Railway API`가 `Active`
- `https://sprache-api-production.up.railway.app/` HTTP 200
- `https://sprache-api-production.up.railway.app/privacy` HTTP 200
- `https://sprache-api-production.up.railway.app/terms` HTTP 200
- `/health` HTTP 200, `desktopOAuthBroker=ready`
- Google Auth Platform은 외부·테스트 중, 테스트 사용자 1명
- `openid`, `userinfo.email`, `userinfo.profile`, `drive.file` 모두 비민감 범위
- 민감·제한 범위 0개
- 브랜딩의 앱 이름·지원 이메일·개발자 연락처 정상
- 홈페이지·개인정보처리방침·승인 도메인은 비어 있음

Railway 공개 페이지는 사용자가 읽는 고지에는 유효하지만 `railway.app`은 프로젝트
소유 도메인이 아니다. Google 운영 브랜드 인증에는 소유권 확인이 가능한 custom
domain을 Railway에 연결한 뒤 같은 페이지를 등록해야 한다.

## 자동 검증

| 검사 | 결과 |
| --- | --- |
| Flutter 전체 테스트 | 354개 통과 |
| API Vitest | 14개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| API TypeScript lint·build | 통과 |
| 릴리스 무결성 | 체크섬 3개, APK ABI 3개, Windows ZIP 34개 통과 |
| 개인정보 URL 바이너리 포함 | Android·Windows 모두 통과 |
| Windows 네이티브 창 | 380×520, 420×640, 1040×760 응답 통과 |
| Windows 설치 수명주기 | 설치 0, 실행 응답, 제거 0, 설치 폴더 제거 |

## Android 업그레이드·실화면 검증

- `adb install -r`로 1.22.1에서 1.22.2 업데이트 성공
- `versionCode 39 → 40`, `versionName 1.22.1 → 1.22.2`
- `firstInstallTime 2026-07-29 00:46:20` 유지
- 기존 사용자 콘텐츠 1개, 최근 세션 1개, 영어 50 XP와 0/10 활성 세션 유지
- 설정에 `웹 개인정보처리방침 열기`와 앱 버전 1.22.2 표시
- 내부 고지에 `시행일 2026년 7월 30일 · 앱 버전 1.22.2` 표시
- 외부 Chrome이 정확한 `/privacy` URL로 열리고 공개 문서 렌더링
- 치명 예외·미처리 예외·AndroidRuntime 오류·RenderFlex overflow 0건

증거:

- `artifacts/verification/android-1.22.2-privacy/privacy-card.png`
- `artifacts/verification/android-1.22.2-privacy/privacy-dialog.png`
- `artifacts/verification/android-1.22.2-privacy/privacy-opened-2.png`

## 산출물

| 파일 | 바이트 | SHA-256 |
| --- | ---: | --- |
| `Sprache-Android-1.22.2-google-debug-signed.apk` | 77,763,661 | `403942185FC7EAD85EE8BAAC58FE44CE17F44F9A7FB9FF10F60345C1851B2B73` |
| `Sprache-Windows-1.22.2-google-x64.zip` | 21,188,475 | `9AD0E1FC2B3DAC152B3329A6CC6EA2A6389A0F84AD1E5DB961BB396CA17C2A7A` |
| `Sprache-Windows-Setup-1.22.2-google-x64.exe` | 17,517,564 | `6D20943C53BEF4B4BDF18267C9705CEDE2714C2C7D6208D6EEBEC7F38BD590B8` |

## 남은 배포 조건

- 소유 custom domain을 Railway에 연결하고 Google Search Console에서 Domain Property로 소유권 확인
- Google 브랜딩에 custom domain의 홈페이지·개인정보처리방침·약관 URL 등록
- Android Play release upload key와 Play App Signing OAuth 지문 등록
- Windows Authenticode 인증서 적용
- Android 물리 기기에서 마이크·TTS·시스템 파일 선택기·접근성 반복 확인
