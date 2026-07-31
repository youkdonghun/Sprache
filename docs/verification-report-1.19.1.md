# Sprache 1.19.1 검증 보고서

검증일: 2026-07-28

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| API 테스트 | Vitest 4개 통과 |
| Flutter 전체 테스트 | 237개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| 전체 사용자 흐름 | 가져오기부터 두 번째 기기 복원까지 통과 |
| Android 빌드 | release APK 생성·업그레이드 설치·실행 성공 |
| Android 버전 | `1.19.1` (`versionCode` 23) |
| Android 서명 | APK Signature Scheme v2, 서명자 1명 |
| Windows 빌드 | release ZIP 생성, 실행 8초 후 `Responding=True` |
| Railway 운영 API | `/health`가 `{"status":"ok","service":"sprache-api"}`로 응답 |
| 배포 API 주소 | Android 3개 ABI와 Windows 모두 Railway HTTPS, 로컬 개발 API 없음 |
| 번들 자산 | Excel 템플릿, Tatoeba·야구·아이돌 팩 양쪽 산출물 포함 |

## 1.19.1 연속성 보완

- 완료한 최근 학습 세션을 최대 20개까지 Drive snapshot에 포함한다.
- 같은 `sessionId`는 더 늦은 종료 시각을 우선하고, 같은 시각에는 JSON
  서명 순서로 결정적으로 병합한다.
- 원격 최근 세션의 코스 ID, 시각, 항목·오답 ID를 적용 전에 검증한다.
- 플래시카드와 발음 연습도 사용한 항목과 오답 ID를 완료 세션에 기록한다.
- 동기화 변경 보고서에 `최근 학습 기록` 업로드·다운로드·충돌 결정을
  별도 항목으로 표시한다.

통합 테스트는 Windows 역할의 첫 앱에서 다음 순서를 한 번에 수행한다.

> Excel 형식 CSV 가져오기 → 동일 OPS 뜻·그룹 병합 → 예문을 독립 문장으로
> 저장 → 복습 그룹 복사 → 단어·문장 직접 선택 일정 저장 → 정답·오답 및 XP
> 기록 → snapshot 업로드 → Android 역할의 두 번째 앱에서 주제·자료·일정·
> 진도·XP·최근 세션·오답 ID 복원

## Android 산출물

- 파일: `artifacts/Sprache-Android-1.19.1-google-debug-signed.apk`
- 크기: 74,983,112 bytes
- SHA-256:
  `40e93d5eda72dcab63fa2eb66b63ee580a02c1833d537d4bd40de42608687d98`
- 패키지: `com.youkdonghun.sprache`
- 최소 SDK: 24
- 대상 SDK: 36
- 서명 인증서 SHA-1:
  `ab6424d5fcba3f762c27c2be613d1aa9c84f1fae`
- 서명 인증서 SHA-256:
  `50f42478d5254ac6921811e25317833ef2db18c411dc92c7b8ef7d8b0ab2a0d2`

에뮬레이터에 `adb install -r`로 업그레이드했다. 시작 화면 뒤 홈까지
정상 진입했고 기존 사용자 야구 주제, 영어 1/10 진행 중 세션과 10 XP가
유지됐다. 실제 캡처는
`artifacts/Sprache-Android-1.19.1-home-ready.png`에 있다.

현재 APK는 직접 설치·기능 검증용 Android Debug 인증서 서명본이다.
Play 배포에는 release keystore, Play App Signing과 해당 SHA 지문으로 만든
Android OAuth 클라이언트가 필요하다.

## Windows 산출물

- 파일: `artifacts/Sprache-Windows-1.19.1-google-x64.zip`
- 크기: 20,790,493 bytes
- SHA-256:
  `24c524dd8cdd056afe84e0c633e8e5f63d5214cc49b92f24172ba367aaaf1e5f`
- ZIP 항목 수: 28
- `sprache.exe` 실행 8초 뒤 `HasExited=False`, `Responding=True`

두 산출물의 해시는
`artifacts/SHA256SUMS-1.19.1-google.txt`와 일치한다.

## 네트워크 주소

Android의 `arm64-v8a`, `armeabi-v7a`, `x86_64` `libapp.so`와 Windows
`data/app.so`에서
`https://sprache-api-production.up.railway.app`을 확인했다.
어느 배포 바이너리에도 개발 API `http://127.0.0.1:3000`은 없다.

Windows 로그인 중 사용하는 `http://127.0.0.1:<임의 포트>`는 Google
데스크톱 OAuth 응답을 같은 PC의 Sprache 프로세스로 돌려주는 일회성
loopback 콜백이다. 공용 API가 아니며 Cloudflare Tunnel로 공개하지 않는다.

## 남은 외부 검증

- 실제 Google 계정으로 Windows 로그인·Drive 폴더 동의 완료
- 같은 계정으로 Android 로그인
- Windows에서 올린 snapshot을 실제 Drive를 거쳐 Android에서 복원
- 물리 Android 기기의 마이크·TTS·파일 선택기·오프라인 복귀
- Play Store release signing과 App Signing OAuth 지문 등록

2026-07-28 실계정 Windows E2E에서는 기존 token exchange 400이 재현되지
않았지만 사용자가 5분 안에 Google 동의 callback을 완료하지 않아
`NETWORK-TIMEOUT`으로 끝났다. 따라서 실제 Drive 전송 완료는 아직
검증됐다고 판정하지 않는다.
