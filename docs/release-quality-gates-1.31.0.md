# Sprache 1.31.0 품질·릴리스 게이트

이 문서는 개선 목표 196~200의 재현 가능한 검증 입력과 합격 조건을 고정한다.
검증기는 사용자 학습 데이터나 절대 경로를 결과물에 기록하지 않는다.

## 196. 고정 fuzz corpus

`apps/client/test/fixtures/qa/fuzz-corpus-v1.json`은 seed `131055`로 버전을
고정한다. snapshot, CSV·TSV·JSON·JSONL 가져오기, 전역 검색, 알림 action,
기기 전용 설정의 정상·경계·거부 입력을 포함한다. 테스트는 예외가 앱 전체로
전파되지 않는지, 수락/거부 결과와 검색 순서가 매번 같은지 확인한다.

```powershell
cd apps/client
flutter test test/qa/fixed_fuzz_corpus_test.dart
```

## 197. golden·semantics 행렬

`visual-semantics-matrix-v1.json`은 Android, iOS, Windows, macOS 각각에 대해
밝은/어두운 테마, 표준/큰 글자, 좁은/넓은 화면을 짝지은 8개 조합을 고정한다.
각 조합은 실제 홈 화면을 그려 golden과 비교하고 기본 학습 및 설정 진입점의
레이블과 tap semantics를 함께 확인한다. 렌더러 차이를 피하기 위해 CI golden은
Windows runner에서 실행하고 Noto Sans KR과 Material Icons를 고정 로드한다.

```powershell
cd apps/client
flutter test test/qa/release_visual_semantics_matrix_test.dart
```

의도한 디자인 변경 때만 `--update-goldens`를 사용하고 새 PNG를 리뷰한다.

## 198. 대용량 성능 예산

디버그 테스트 빌드와 일반 CI runner에서도 지킬 수 있는 상한이다. fixture 생성
시간은 제외하고 실제 파싱·검색·집계 시간만 잰다.

| 작업 | 데이터 크기 | 예산 |
|---|---:|---:|
| CSV 가져오기 | 20,000행 | 20초 |
| 전역 검색 | 50,000항목 | 15초 |
| 통계 집계 | 10,000세션 | 5초 |

```powershell
cd apps/client
flutter test test/qa/performance_budget_test.dart
```

## 199. 1.30 → 1.31 업그레이드 E2E

테스트는 임시 SQLite에 1.30 형식의 설정·사용자 단어·진도·세션을 기록하고 schema
1로 만든 다음 실제 bootstrap과 migration을 실행한다. 완료 후 모든 데이터,
schema 2, 마이그레이션 전 SHA-256 원본을 확인한다. 별도 시나리오는 손상 header와
미래 schema를 열기 전에 차단하고 원본과 보존본의 SHA-256이 같은지 확인한다.

```powershell
cd apps/client
flutter test test/qa/upgrade_130_to_131_e2e_test.dart
```

## 200. 네 플랫폼 산출물 manifest

정책은 Windows·Android `REAL`, iOS Simulator·macOS unsigned/ad-hoc `MOCK`으로
고정한다. `release-bundle.mjs`는 다음을 모두 검증한 뒤에만 manifest를 만든다.

- Windows EXE, Android APK, iOS ZIP, macOS ZIP 네 플랫폼이 정확히 한 개씩 존재
- pubspec과 일치하는 `1.31.0`, build `55`, 파일명 버전, 플랫폼별 REAL/MOCK 표시
- 각 산출물의 바이트 길이와 SHA-256
- Windows·iOS·macOS의 실행 및 첫 프레임 성공 runtime evidence, Android APK의
  빌드·서명·패키지·ABI 검증 evidence와 각 evidence 자체의 SHA-256
- 절대 경로, `..` 경로 탈출, 심볼릭 링크, 중복 플랫폼, 변조 파일 차단

`packaging/release-bundle-spec-1.31.0.json`에 적힌 정확한 이름으로 네 산출물을
최종 폴더에 모으고, 각 플랫폼의 검증 evidence JSON을 같은 폴더에 준비한 뒤
실행한다. v2 spec은 Windows·iOS·macOS를 `RUNTIME`, Android를 `BUILD_ONLY`로
명시한다. 검증기는 evidence를 대신 만들거나 Android 빌드 성공을 첫 프레임
성공으로 바꾸지 않는다.

저장소의 기본 spec은 현재 로컬 설치 시험용 `google-debug-signed.apk`를 정확히
표시한다. 외부 release keystore로 빌드한 경우 APK를 debug 이름으로 바꾸지 말고,
spec을 최종 폴더에 복사해 Android `artifact`만 실제
`google-release-signed.apk` 이름으로 수정한 사본을 `--spec`에 전달한다.

```powershell
npm run create:release-bundle -- `
  --spec packaging/release-bundle-spec-1.31.0.json `
  --root <최종-산출물-폴더> `
  --out <최종-산출물-폴더>\release-manifest-1.31.0.json

npm run verify:release-bundle -- `
  --manifest <최종-산출물-폴더>\release-manifest-1.31.0.json `
  --root <최종-산출물-폴더>

# REAL Windows/Android 내부 metadata·서명까지 이어서 확인
npm run verify:release
```

기존 `artifacts`의 구버전 정리는 이 네 플랫폼 manifest를 다시 검증한 승격
명령에서만 허용한다.

```powershell
npm run verify:release:promote -- `
  -ReleaseBundleManifest <최종-산출물-폴더>\release-manifest-1.31.0.json
```

runtime evidence 형식은 아래와 같다. `launched` 또는 `firstFrameRendered`를 실제
검증 없이 `true`로 기록해서는 안 된다. Windows는 native runtime 캡처, iOS는
simulator, macOS는 native 실행을 우선하며, 환경상 불가능한 경우
`flutter-first-frame`임을 숨기지 않고 명시한다.

Apple CI 빌드는 `ENABLE_RELEASE_PROBE=true`일 때만 활성화되는 앱 내부 probe를
사용한다. `main()`이 `WidgetsBinding.endOfFrame`을 통과한 뒤 앱 지원 폴더에
evidence를 atomic write하고, 워크플로가 iOS Simulator에 설치·실행하거나 macOS
앱 실행 후 해당 파일을 회수·검증한다. 일반 빌드의 기본값은 `false`이므로 이
진단 파일을 만들지 않는다. Apple Actions 산출물에는 각각 `runtime-ios.json`,
`runtime-macos.json`이 ZIP 및 SHA-256과 함께 포함된다.

Windows `REAL` evidence는 최종 설치 EXE를 격리 폴더에 설치한 뒤 실제 창의
응답·제목·비어 있지 않은 픽셀을 확인하고 생성한다. 이번 Android `REAL` APK는
사용자의 Windows EXE 실행 요청과 현재 검증 환경에 맞춰 `BUILD_ONLY`로 표시한다.
전용 evidence는 `launched=false`, `firstFrameRendered=false`,
`firstFrameMillis=null`을 유지하면서 빌드·v2 서명·패키지명/버전·3개 ABI 성공과
APK의 실제 SHA-256·바이트 길이를 결속한다. 고정 limitation은
`ANDROID_RUNTIME_UNAVAILABLE_CI_BILLING_AND_LOCAL_HYPERVISOR`이며 다른 플랫폼은
이 예외를 사용할 수 없다. Android 에뮬레이터가 준비된 환경에서는 아래 명령으로
별도 runtime evidence를 추가할 수 있다. 물리 Android 기기는 명시적인
`-AllowPhysicalDevice` 없이는 건드리지 않는다.

```powershell
npm run capture:runtime:windows -- `
  -InstallerPath <최종-Windows-설치-EXE> `
  -RuntimeEvidencePath <최종-산출물-폴더>\runtime-windows.json

npm run capture:runtime:android -- `
  -ApkPath <최종-Android-APK> `
  -OutputPath <최종-산출물-폴더>\runtime-android.json `
  -ScreenshotPath <최종-산출물-폴더>\runtime-android-first-frame.png
```

```json
{
  "format": "sprache-runtime-evidence-v1",
  "platform": "windows",
  "mode": "REAL",
  "version": "1.31.0",
  "buildNumber": 55,
  "launched": true,
  "firstFrameRendered": true,
  "firstFrameMillis": 731,
  "probe": "native-runtime",
  "checkedAt": "2026-08-03T06:00:00.000Z"
}
```

검증기 자체의 정상 생성, 파일 변조, 경로 탈출, 거짓 첫 프레임 차단은 다음 명령으로
확인한다.

```powershell
npm run test:release-bundle
```
