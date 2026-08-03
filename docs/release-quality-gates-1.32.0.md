# Sprache 1.32.0 품질·릴리스 게이트

이 문서는 컴팩트 UX 80개 변경과 `1.32.0+56` 네 플랫폼 산출물의 합격 조건을
고정한다. 검증기는 사용자 학습 데이터, 비밀값이나 로컬 절대 경로를 결과물에
기록하지 않는다.

## 1. 기능·호환성 게이트

- [컴팩트 UX 80개 목표](compact-ux-80-upgrade-plan-1.32.0.md) 각각에 코드와
  회귀 테스트 또는 실제 화면 근거가 있다.
- 앱 생명주기에서 `Sprache 보호 중` 커튼, 타이머와 지연 설정을 참조하지 않는다.
- 과거 백업의 `curtainDelay`는 역직렬화 오류 없이 무시한다.
- 개인정보 가림, 알림 내용 표시, Drive 동기화 일시 중지는 독립적으로 동작한다.
- 컴팩트 밀도에서도 주요 터치·클릭 영역은 최소 44px이며 380px 폭과 큰 글자에서
  오버플로가 없다.

```powershell
cd apps/client
dart analyze lib test
flutter test
```

Flutter wrapper의 분석 서버 자체가 비정상 종료하는 환경에서는 실패 로그를
보존하고 같은 SDK의 `dart analyze lib test` 결과를 함께 기록한다. 분석 오류를
환경 문제로 숨기거나 테스트 성공으로 대체하지 않는다.

## 2. 핵심 회귀 범위

다음 테스트군은 최소 포함 범위다.

- 기기 설정 JSON과 백업 호환
- 개인정보 모드 범위와 앱 생명주기
- 공통 레이아웃 밀도·반응형 셸
- 홈 요약·개인화 회귀
- 빠른 등록 작업대와 저장 흐름
- 자료 흐름·그룹 필터
- 연습 카탈로그·세션 자율성
- 개인화 프리셋과 테마 설정
- 고정 fuzz corpus, visual/semantics 행렬, 성능 예산, 1.30→1.31 데이터 E2E

루트 검증도 별도로 통과시킨다.

```powershell
npm test
npm run test:release-bundle
```

## 3. 실제 화면 게이트

Windows release 앱을 실제로 실행해 다음을 확인한다.

1. 백그라운드 복귀 뒤 보호 커튼이 나타나지 않는다.
2. 홈에서 이어하기, 오늘 지표와 주간 진행이 한 화면에 과도한 빈 공간 없이
   보인다.
3. 빠른 등록에서 표현·뜻이 먼저 보이고 선택 필드는 접혀 있다.
4. 자료실에서 검색·그룹 필터와 결과가 가깝다.
5. 연습 허브에서 최근·즐겨찾기, 3·5·10·15분과 예상 문제 수를 찾기 쉽다.
6. 설정에서 테마·밀도·글자 크기와 `컴팩트 작업 공간`을 적용·복원할 수 있다.

## 4. 플랫폼 산출물 게이트

정책은 Windows·Android `REAL`, iOS Simulator·macOS unsigned/ad-hoc `MOCK`이다.
Windows·iOS·macOS는 `RUNTIME`, Android는 `BUILD_ONLY` evidence를 요구한다.

| 플랫폼 | 필수 evidence |
|---|---|
| Windows | 설치·실행·응답·첫 프레임·제거를 결속한 `runtime-windows.json` |
| Android | APK 해시·길이·v2 서명·패키지·버전·3개 ABI를 결속한 `build-android.json` |
| iOS | Simulator 실제 첫 프레임의 `runtime-ios.json` |
| macOS | native 실제 첫 프레임의 `runtime-macos.json` |

Android build 성공을 실행 성공으로, Simulator ZIP을 IPA로, unsigned macOS ZIP을
공증 배포본으로 바꾸어 표현하지 않는다.

## 5. 네 플랫폼 manifest

`packaging/release-bundle-spec-1.32.0.json`에 적힌 정확한 파일명으로 네 산출물과
evidence를 한 폴더에 준비한다.

```powershell
npm run create:release-bundle -- `
  --spec packaging/release-bundle-spec-1.32.0.json `
  --root <최종-산출물-폴더> `
  --out <최종-산출물-폴더>\release-manifest-1.32.0.json

npm run verify:release-bundle -- `
  --manifest <최종-산출물-폴더>\release-manifest-1.32.0.json `
  --root <최종-산출물-폴더>

npm run verify:release
```

manifest는 다음을 모두 검증해야 한다.

- `version=1.32.0`, `buildNumber=56`과 파일명 버전의 일치
- Windows EXE, Android APK, iOS ZIP, macOS ZIP이 정확히 한 개씩 존재
- 모든 산출물과 evidence의 바이트 길이·SHA-256
- 플랫폼별 `REAL/MOCK`, `RUNTIME/BUILD_ONLY` 정책 일치
- 절대 경로, `..` 경로 탈출, 심볼릭 링크, 중복 플랫폼과 변조 파일 차단

## 6. 승격과 구버전 정리

최종 manifest를 다시 검증한 경우에만 다음 명령을 실행한다.

```powershell
npm run verify:release:promote -- `
  -ReleaseBundleManifest <최종-산출물-폴더>\release-manifest-1.32.0.json
```

명령은 학습 DB, 복구 백업, 로그와 이름을 인식할 수 없는 파일을 삭제해서는 안
된다. 실행 결과, 플랫폼별 limitation과 SHA-256은 최종 검증 보고서에 기록한다.
