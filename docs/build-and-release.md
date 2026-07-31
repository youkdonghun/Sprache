# 빌드와 배포 산출물

## 공통 검증

```powershell
npm ci
npm run lint:api
npm run test:api
npm run build:api

cd apps/client
flutter pub get
flutter analyze
flutter test
```

## Mock Mode 릴리스

Google 자격증명 없이 UI·학습·로컬 저장·가상 동기화를 검증한다.

```powershell
flutter build apk --release --dart-define=ENABLE_MOCK_MODE=true
flutter build windows --release --dart-define=ENABLE_MOCK_MODE=true
```

출력:

- Android: `apps/client/build/app/outputs/flutter-apk/app-release.apk`
- Windows: `apps/client/build/windows/x64/runner/Release/`

Windows는 EXE만 복사하면 안 된다. `Release` 폴더 전체를 ZIP으로 배포해야 DLL과 Flutter data가 함께 간다.

현재 검증된 Mock 산출물:

- `artifacts/Sprache-Android-1.15.0-mock-debug-signed.apk`
- `artifacts/Sprache-Windows-1.15.0-mock-x64.zip`
- SHA-256: `artifacts/SHA256SUMS.txt`

## Google·Railway 실제 연결 릴리스

Google OAuth client ID와 Railway 공개 API URL을 적용하고 Mock Mode를 끈다.
Windows 빌드 전 운영 `/health`의 `desktopOAuthBroker`가 `ready`인지 확인한다.
Desktop Client Secret은 빌드에 전달하지 않고 Railway sealed variable에만 둔다.

```powershell
npm run build:real
```

플랫폼 하나만 다시 만들 때는 `npm run build:real:android` 또는 `npm run build:real:windows`를 사용한다.

출력:

- Android: `artifacts/Sprache-Android-1.24.0-google-debug-signed.apk`
- Windows 설치본: `artifacts/Sprache-Windows-Setup-1.24.0-google-x64.exe`
- Windows 포터블: `artifacts/Sprache-Windows-1.24.0-google-x64.zip`
- SHA-256: `artifacts/SHA256SUMS-1.24.0-google.txt`

Android 파일은 실제 Google 연결이 켜져 있지만 현재 로컬 debug 인증서로 서명된다. Play 배포본은 release keystore와 Play App Signing 지문용 Android OAuth 클라이언트를 별도로 사용해야 한다.

Windows 설치본은 Inno Setup 6을 사용하며 관리자 권한 없이
`%LOCALAPPDATA%\Programs\Sprache`에 설치한다. 시작 메뉴 바로가기를 만들고,
바탕 화면 바로가기는 사용자가 선택할 때만 만든다. 빌드 도구가 없으면 다음
명령으로 사용자 범위에 설치한다.

```powershell
winget install --id JRSoftware.InnoSetup --exact --scope user
npm run build:installer
npm run test:installer
```

`npm run build:real`과 `npm run build:real:windows`는 ZIP과 설치 EXE를 함께
만든다. 현재 설치 EXE는 기능 검증용 무서명 산출물이므로 공개 배포 전에
신뢰 가능한 Windows 코드 서명 인증서로 Authenticode 서명해야 한다.

## 외부 키를 저장하지 않는 정식 서명

저장소에는 keystore, PFX, 비밀번호를 넣지 않는다. `.jks`, `.keystore`,
`.pfx`, `.p12`, `.key`, `key.properties`는 Git에서 제외한다.

Android 정식 서명은 다음 네 환경변수가 모두 있을 때만 활성화된다.

```text
SPRACHE_ANDROID_KEYSTORE_PATH=<저장소 밖의 절대 .jks 경로>
SPRACHE_ANDROID_KEYSTORE_PASSWORD=<비밀값>
SPRACHE_ANDROID_KEY_ALIAS=<upload key alias>
SPRACHE_ANDROID_KEY_PASSWORD=<비밀값>
```

일부 값만 들어오면 빌드를 시작하기 전에 누락된 변수 이름만 표시하고
중단한다. 네 값이 없으면 직접 설치 테스트용 Debug 인증서를 사용하며 파일명도
`debug-signed.apk`로 표시한다. 네 값이 모두 있으면 `release-signed.apk`로
구분한다. Android 비밀번호는 채팅·명령 기록·저장소가 아니라 로컬 비밀 저장소
또는 CI secret에서 프로세스 환경으로 주입한다.

Windows는 `CurrentUser\My` 인증서 저장소의 코드서명 인증서를 사용한다.

```text
SPRACHE_WINDOWS_SIGNING_THUMBPRINT=<코드서명 인증서 SHA-1 thumbprint>
```

빌드 도구는 Windows SDK의 x64 SignTool을 찾고, 코드서명 EKU·개인키·유효기간을
검사한 뒤 `sprache.exe`와 설치 EXE를 SHA-256 및 HTTPS RFC 3161 타임스탬프로
서명하고 다시 검증한다. PFX 비밀번호를 빌드 인수로 받지 않는다.

모든 공개 배포 조건을 강제하는 명령:

```powershell
$env:SPRACHE_PRIVACY_POLICY_URL = 'https://소유도메인/privacy'
npm run build:release-gated
```

이 명령은 Railway OAuth broker, 공개 HTTPS 개인정보처리방침, Android 정식
서명 네 값, Windows 코드서명 인증서 중 하나라도 준비되지 않으면 컴파일 전에
중단한다.

## 산출물 통합 검증

```powershell
npm run verify:release
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\tool\verify-release.ps1 `
  -RequireAndroidReleaseSigning `
  -RequireWindowsCodeSigning `
  -RunInstallerSmoke
```

검증기는 다음을 한 번에 확인한다.

- 체크섬 파일의 모든 항목과 실제 SHA-256 일치
- Android 패키지·버전 코드·v2 서명·Debug/Release 파일명 일치
- Android 3개 ABI와 Windows `app.so`의 운영 API·앱 버전
- 개발 API 주소와 Railway Desktop Client Secret 변수명 부재
- Windows ZIP의 EXE·Flutter data·Excel 템플릿
- 설치 EXE 제품 버전과 선택적 Authenticode 강제
- 선택 시 설치→실행→제거와 HKCU 제거 레지스트리 정리

## Windows 실제 크기와 엔진 UI 검증

release EXE가 네이티브 최소·집중·일반 크기를 실제로 받아들이고 계속 응답하는지
검사한다.

```powershell
npm run test:windows:runtime
```

Flutter Windows 엔진에서 홈·연습·설정으로 이동하고 화면 레이어를 PNG로 저장해
실제 렌더링과 오버플로를 검토한다.

```powershell
npm run test:windows:ui-e2e
```

검증 범위는 380×520 최소창 홈·연습, 420×640 집중창 홈, 1040×760 일반
홈·설정이다. 첫 명령은 외곽·클라이언트 크기와 `Responding` 상태를 JSON으로,
두 번째 명령은 실제 Windows 엔진 PNG 다섯 장을 `artifacts/verification`에
남긴다.

## Flutter Built-in Kotlin 전환 상태

현재 기준 Flutter 3.44는 Built-in Kotlin 활성화에 필요한 최소 버전 3.47보다
낮다. 따라서 `android.builtInKotlin=false`를 유지한다. 현재
`file_picker`, `flutter_timezone`, `flutter_tts`, `speech_to_text`도 KGP를
적용하므로 Flutter와 네 플러그인이 모두 전환 가능한 버전이 된 뒤 별도 업그레이드·APK 실기동
검증으로 처리한다. 경고만 숨기기 위해 Gradle 플래그를 먼저 바꾸지 않는다.

1.22.0 산출물에는
`assets/templates/Sprache-easy-import-template.xlsx`,
`assets/templates/Sprache-word-import-template.xlsx`와
`assets/content/tatoeba-korean-sentence-pack-2026-07-28.json`이 함께 포함된다.
Android APK는 이전 버전 위에 업그레이드 설치해 기존 학습 세션·사용자 주제 보존,
웹 예문 검토·가져오기, 그룹 생성과 출처 상세 표시를 반복 확인한다.
1.22.0의 해시·서명·설치·기동, 27열 Excel 내보내기·재가져오기,
여섯 언어 한국어 발음과 예문 발음, 실제 Windows 최소창 엔진 검증 결과는
[`verification-report-1.22.0.md`](verification-report-1.22.0.md)에 기록했다.

1.22.1은 진행 중인 학습이 있는 상태에서 다른 학습을 시작할 때 기존 세션을
조용히 덮어쓰지 않도록 선택 대화상자를 추가했다. Android 에뮬레이터에서
1.22.0 위에 덮어쓰기 설치하고 `firstInstallTime`, 기존 세션과 계정 XP가
유지되는 것을 확인했다. 해시·ABI·Windows 설치 수명주기와 실제 엔진 UI 검증은
[`verification-report-1.22.1.md`](verification-report-1.22.1.md)에 기록했다.

1.22.2부터 일반 실서비스 빌드는
`https://sprache-api-production.up.railway.app/privacy`를 기본 공개
개인정보처리방침으로 포함한다. 소유 custom domain이 준비되면
`SPRACHE_PRIVACY_POLICY_URL`로 최종 URL을 덮어쓴다. 이 Railway 기본 주소는
앱 사용자의 공개 고지 접근에는 유효하지만 Google 운영 브랜드 인증에 필요한
소유 도메인을 대신하지 않는다. 배포·Android 실화면·Windows 설치 검증은
[`verification-report-1.22.2.md`](verification-report-1.22.2.md)에 기록했다.

1.22.3은 내장 단어 480개·문장 240개 전부에 한국어 발음 보조표기를
제공한다. Flutter 전체 테스트·정적 분석, Android 1.22.2 위 업그레이드와
발음 실화면, Windows release 실행, 산출물 해시·ABI·AOT 검증 결과는
[`verification-report-1.22.3.md`](verification-report-1.22.3.md)에 기록했다.

1.22.4는 학습 화면의 한국어 발음 내용 앞에 반복되던 `한국어 발음`
접두어를 제거했다. Android·Windows 산출물, 전체 회귀 테스트와 시각 검증은
[`verification-report-1.22.4.md`](verification-report-1.22.4.md)에 기록했다.

1.22.5는 채점 결과를 현재 문제 위의 컴팩트 모달 팝업으로 통합해
데스크톱에서 피드백 카드가 전체 높이로 늘어나던 문제를 해결했다. 검증 결과는
[`verification-report-1.22.5.md`](verification-report-1.22.5.md)에 기록했다.

1.22.6은 간편 Excel 템플릿의 저장 제안 이름을
`Sprache 업로드 템플릿_YYYYMMDD.xlsx`로 변경했다. 검증 결과는
[`verification-report-1.22.6.md`](verification-report-1.22.6.md)에 기록했다.

1.22.7은 자료가 저장·그룹화·학습으로 이어지는 흐름 안내와 Windows
좌우 드래그앤드롭, 모바일 선택형 그룹 작업판을 추가했다. 검증 결과는
[`verification-report-1.22.7.md`](verification-report-1.22.7.md)에 기록했다.

1.23.0은 독립 그룹 메타데이터, 검색·정렬·고정·순서 변경, 좁은 Windows
작업판, 모바일 그룹 관리 시트, 대량 작업 영향 미리보기와 실행 취소를
추가했다. 검증 결과는
[`verification-report-1.23.0.md`](verification-report-1.23.0.md)에 기록했다.

1.24.0은 Google 미연결 시 사용자 지정 로컬 폴더 미러, Android SAF
영구 권한, Drive 연결·해제에 따른 활성 저장 대상 전환, 가져오기 원본
보관과 current/previous 세대 복구를 추가했다. 검증 결과는
[`verification-report-1.24.0.md`](verification-report-1.24.0.md)에 기록했다.

## 릴리스 전 체크리스트

- Android release keystore와 Play App Signing 설정
- Windows 설치 EXE Authenticode 코드 서명
- 앱 아이콘·스토어 그래픽·개인정보처리방침 URL 확정
- Google OAuth consent production 전환 및 필요한 검증
- 실제 Android 기기 TTS·Picker·오프라인 복귀 테스트
- 실제 Android 기기에서 여섯 언어 마이크 권한·음성 인식 언어팩·발음 따라하기 테스트
- 실제 Google 계정으로 Windows·Android 로그인과 Drive 양방향 복원 테스트
- Windows 최소 크기 `380×520`, 일반·확장 크기 조절 테스트
- Windows 영어 음성 인식과 비영어 코스의 따라 읽기 대체 흐름 테스트
- Railway `/health`의 `desktopOAuthBroker=ready`, migration, 토큰 route `no-store`, 로그 redaction 확인
- Mock Mode가 production 산출물에서 꺼졌는지 확인
- `npm run build:release-gated`와 정식 서명 강제 `verify-release.ps1` 통과
