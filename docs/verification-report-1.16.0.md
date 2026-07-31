# Sprache 1.16.0 검증 보고서

검증일: 2026-07-28

## 기능 범위

- Excel 템플릿 저장 및 `.xlsx` 가져오기
- 같은 언어·종류·표현·품사의 뜻, 허용 정답, 태그와 그룹 병합
- 단어와 문장의 예문·예문 번역 가져오기
- 학습 그룹 생성, 복사, 이동, 그룹 암기와 그룹 퀴즈
- 사용자가 고른 표현만 포함하는 퀴즈
- 학습 계획 제목과 예정 날짜·시간 저장
- Windows Google OAuth 경로 없는 loopback redirect 적용
- Android 네이티브 Google Sign-In 유지

## 자동 검증

| 검사 | 결과 |
| --- | --- |
| API TypeScript lint | 통과 |
| API Vitest | 4개 통과 |
| API production build | 통과 |
| Flutter analyze | 이슈 0개 |
| Flutter 전체 테스트 | 188개 통과 |
| Flutter 시각 회귀 테스트 | 21개 통과 |
| Excel 템플릿 앱 파서 테스트 | 영어·일본어·독일어·프랑스어·스페인어·중국어 행 통과 |
| Excel 템플릿 수식 오류 검사 | 오류 0개 |
| Railway `/health` | HTTP 200, `{"status":"ok","service":"sprache-api"}` |

## 산출물 검증

### Android

- 파일: `artifacts/Sprache-Android-1.16.0-google-debug-signed.apk`
- 크기: 74,234,322 bytes
- 패키지: `com.youkdonghun.sprache`
- 버전: `1.16.0` (`versionCode` 18)
- 최소 SDK: 24
- 대상 SDK: 36
- APK Signature Scheme v2: 통과
- SHA-256: `45ef2a8ac6196210eb881268d8b275f881dbfdfe27398ec6c1650cd9f0d0c6c7`

현재 APK는 실제 기기 설치 테스트용 debug 인증서로 서명했다. Play Store 배포 전에는 release keystore와 Play App Signing SHA-1/SHA-256을 Google Android OAuth 클라이언트에 등록해야 한다.

### Windows

- 파일: `artifacts/Sprache-Windows-1.16.0-google-x64.zip`
- 크기: 20,662,821 bytes
- ZIP에 `sprache.exe`, 필수 DLL, Flutter 데이터와 Excel 템플릿 포함
- 릴리스 EXE 숨김 실행 후 5초 이상 정상 유지 확인
- SHA-256: `53640e9f068baacdbece3397819fad97670f0d1b004f3260980e9ddba2819c60`

두 파일의 재계산 SHA-256은 `artifacts/SHA256SUMS-1.16.0-google.txt`와 일치했다.

## 남은 실제 계정 검증

Google 로그인은 사용자 브라우저 동의가 필요한 외부 동작이므로 자동 검증하지 않았다. 새 Windows 빌드는 Google 설치형 앱 규격에 맞게 `http://127.0.0.1:<임시 포트>`를 사용하고, Google 오류 코드와 설명을 화면에 보존한다. 사용자가 새 빌드에서 한 번 연결하면 실제 토큰 교환과 Drive 폴더 선택까지 최종 확인할 수 있다.

## 유지보수 경고

현재 Flutter 버전에서는 빌드가 통과하지만 `file_picker`, `flutter_tts`, `speech_to_text`가 Kotlin Gradle Plugin을 직접 적용한다는 향후 호환성 경고가 발생한다. 다음 Flutter 주요 버전 업그레이드 전에 Built-in Kotlin을 지원하는 플러그인 버전으로 갱신해야 한다.
