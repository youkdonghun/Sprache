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

```powershell
npm run build:real
```

플랫폼 하나만 다시 만들 때는 `npm run build:real:android` 또는 `npm run build:real:windows`를 사용한다.

출력:

- Android: `artifacts/Sprache-Android-1.15.1-google-debug-signed.apk`
- Windows: `artifacts/Sprache-Windows-1.15.1-google-x64.zip`
- SHA-256: `artifacts/SHA256SUMS-1.15.1-google.txt`

Android 파일은 실제 Google 연결이 켜져 있지만 현재 로컬 debug 인증서로 서명된다. Play 배포본은 release keystore와 Play App Signing 지문용 Android OAuth 클라이언트를 별도로 사용해야 한다.

## 릴리스 전 체크리스트

- Android release keystore와 Play App Signing 설정
- 앱 아이콘·스토어 그래픽·개인정보처리방침 URL 확정
- Google OAuth consent production 전환 및 필요한 검증
- 실제 Android 기기 TTS·Picker·오프라인 복귀 테스트
- 실제 Android 기기에서 여섯 언어 마이크 권한·음성 인식 언어팩·발음 따라하기 테스트
- Windows 최소 크기 `380×520`, 일반·확장 크기 조절 테스트
- Windows 영어 음성 인식과 비영어 코스의 따라 읽기 대체 흐름 테스트
- Railway `/health`, migration, 로그 redaction 확인
- Mock Mode가 production 산출물에서 꺼졌는지 확인
