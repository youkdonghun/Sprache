# Sprache 1.32.0 릴리스 준비 감사

이 문서는 `1.32.0+56`의 정적 준비 상태와 안전한 실행 순서를 기록한다. 실제
빌드·기동 결과와 SHA-256은 최종 `release-manifest-1.32.0.json` 및 그 manifest가
결속한 evidence가 우선한다.

## 정적 준비 상태

| 항목 | 기준 | 상태 |
|---|---|---|
| 앱 버전 | `apps/client/pubspec.yaml`의 `1.32.0+56` | 준비 |
| CI 버전 | 네 플랫폼 빌드 이름 `1.32.0`, build `56` | 준비 |
| 번들 명세 | `packaging/release-bundle-spec-1.32.0.json` | 준비 |
| Android·Apple 식별자 | `com.youkdonghun.sprache` | 유지 |
| Windows 실행 파일 | `sprache.exe`, 제품명 `Sprache` | 유지 |
| 1.31 설정 호환 | 과거 `curtainDelay`를 오류 없이 무시 | 회귀 테스트 대상 |
| 80개 개선 | 목표별 코드·테스트·실행 화면 근거 | 최종 검증 대상 |

정적 준비는 실제 빌드나 실행 성공을 뜻하지 않는다. 각 플랫폼의 검증 수준은
Windows·iOS·macOS `RUNTIME`, Android `BUILD_ONLY`로 분리한다.

## 필수 검증 순서

1. `dart analyze lib test` 또는 정상 동작하는 Flutter 분석기로 정적 분석을
   통과시킨다.
2. 전체 Flutter 테스트와 루트 `npm test`를 통과시킨다.
3. 잠금 커튼 런타임 심볼이 0건인지 확인하고 과거 설정 JSON 호환 테스트를
   통과시킨다.
4. Windows 실제 실행 화면에서 홈, 빠른 등록, 자료실, 연습 허브와 설정을
   확인한다.
5. Windows 설치 EXE·포터블 ZIP과 Android APK를 만들고
   `npm run verify:release`로 내부 버전·서명·ABI·운영 설정을 검증한다.
6. Windows 설치본을 격리 설치해 `runtime-windows.json`을 생성한다. Android는
   빌드·v2 서명·패키지·ABI 결과를 `build-android.json`에 APK 해시와 결속한다.
7. 변경을 푸시한 뒤 Codemagic `apple-preview` 또는 GitHub Actions의 macOS
   작업에서 실제 첫 프레임 evidence와 대응 PNG 및 `MOCK` ZIP을 받는다.
8. 네 플랫폼 파일을 최종 폴더에 모아 번들 manifest를 만들고 다시 검증한다.
9. manifest 재검증까지 통과한 뒤에만 승격 명령으로 저장소의 낡은 릴리스
   산출물을 정리한다. 학습 DB와 복구 백업은 삭제 대상이 아니다.

## 플랫폼별 정직한 판정

- Windows `REAL/RUNTIME`: 최종 설치 EXE의 격리 설치, 응답 가능한 실제 창,
  비어 있지 않은 첫 프레임과 제거를 모두 확인한다.
- Android `REAL/BUILD_ONLY`: `google-debug-signed`를 Play 서명본이라고 부르지
  않는다. 에뮬레이터 실행 evidence가 추가돼도 기본 번들의 판정을 임의로
  바꾸지 않는다.
- iOS `MOCK/RUNTIME`: GitHub macOS runner에서 Simulator 앱을 실행한다. ZIP은
  기기 설치용 IPA가 아니다.
- macOS `MOCK/RUNTIME`: unsigned/ad-hoc 앱을 실행한다. Developer ID 서명·공증
  배포본으로 표시하지 않는다.

## 보안과 정리 조건

- OAuth client secret, 토큰, keystore, 인증서 비밀번호를 저장소·로그·산출물에
  넣지 않는다.
- 운영 Google·Railway 연결 상태는 비밀값 없이 공개 식별자와 `/health` 결과로
  검증한다.
- 손상되거나 지원하지 않는 원격 데이터로 정상 로컬 데이터를 덮어쓰지 않는다.
- `verify:release:promote`는 검증된 네 플랫폼 manifest 경로가 없으면 중단해야
  한다.
