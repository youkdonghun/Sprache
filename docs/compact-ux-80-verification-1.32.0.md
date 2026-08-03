# Sprache 1.32.0 컴팩트 UX 80개 최종 검증

버전: `1.32.0+56`

이 문서는 [80개 개선 목표](compact-ux-80-upgrade-plan-1.32.0.md)를 실제 코드,
회귀 테스트, 골든 이미지, Windows 네이티브 실행과 로컬 릴리스 산출물로 검증한
결과를 요약한다. 세부 목표별 근거는 다음 문서에 나뉘어 있다.

- [1–30 검증](compact-ux-1-30-verification-1.32.0.md)
- [31–46 검증](compact-ux-31-46-verification-1.32.0.md)
- [47–63 검증](compact-ux-47-63-verification-1.32.0.md)
- [64–80 검증](compact-ux-64-80-verification-1.32.0.md)

## 최종 자동 검증

| 검증 | 결과 |
|---|---|
| Dart 정적 분석 | `dart analyze lib test` 오류 0건 |
| Flutter 전체 회귀 | 983/983 통과 |
| 플랫폼·테마 골든 | 46/46 통과 |
| API TypeScript strict 검사 | 통과 |
| API Vitest | 15/15 통과 |
| 릴리스 번들 보안 테스트 | 5/5 통과 |
| Windows·Android 통합 검사 | `verify-release.ps1 -Version 1.32.0` 통과 |
| Git 공백 검사 | `git diff --check` 통과 |

전체 회귀에서 처음 발견된 5건은 제품 결함이 아니라 컴팩트 문구 변경 뒤 남은
낡은 문자열 기대 4건과 화면 밖 버튼을 스크롤하지 않고 누르던 테스트 1건이었다.
새 문구와 실제 사용자 스크롤 동선으로 검증을 보정한 뒤 전체 983개를 다시
통과시켰다.

## 앱 잠금 제거와 호환성

- 앱 수명주기에서 보호 커튼, 지연 타이머와 복귀 오버레이를 제거했다.
- 과거 1.31 설정의 `curtainDelay` 필드는 오류 없이 무시한다.
- 개인정보 가림, 알림 내용 표시와 Drive 동기화 중지는 서로 독립된 기능으로
  유지한다.
- 포터블 Windows 실행본을 다른 창으로 전환했다가 복귀시켜 홈이 즉시 보이고
  앱 잠금·재인증 화면이 나타나지 않음을 확인했다.

## Windows 네이티브 실행

`Sprache-Windows-1.32.0-google-x64.zip`을 새 폴더에 풀어 실제 EXE를 실행했다.
인앱 증거는 다음 값을 기록했다.

- 모드: `REAL`
- 버전: `1.32.0+56`
- 프로브: `native-runtime`
- 창 응답: 정상
- 첫 프레임: 225ms
- 첫 프레임 SHA-256:
  `50376af04fb13353280d6ff443943e57a2e6c2862dc8039b4274709711ce89c6`

홈, 빠른 자료 추가, 자료실, Practice Hub, 환경설정과 개인화 스튜디오를 실제
Windows 창에서 열었다. 빠른 등록은 표현·뜻이 먼저 보이고, 자료실은 검색·필터·
결과가 가까우며, 학습실은 추천·검색·무작위 게임과 자율 세션 진입을 한 화면에서
제공했다.

## 로컬 REAL 산출물

| 파일 | 바이트 | SHA-256 |
|---|---:|---|
| `Sprache-Windows-Setup-1.32.0-google-x64.exe` | 18,703,161 | `cacf1f9120814fe9349809417af7ef3c8436aa0cee4bca6d566ca432aee00d83` |
| `Sprache-Windows-1.32.0-google-x64.zip` | 23,110,873 | `6b3f0253e489400012f8d068b28d629698eec7c6e1a6be77b33b6ebebf43e680` |
| `Sprache-Android-1.32.0-google-debug-signed.apk` | 88,256,566 | `2de6a2a230e5b6d8044862b4df0a72eba390ab81c6697d59a12fc44cb2e29a6c` |

Android는 `com.youkdonghun.sprache`, 버전 `1.32.0+56`, `arm64-v8a`,
`armeabi-v7a`, `x86_64`와 APK Signature Scheme v2를 검증했다. 제공된 배포 키가
없으므로 파일 이름 그대로 테스트 설치용 `debug-signed`이며 Play 배포본으로
표시하지 않는다. Windows 설치본도 코드 서명 인증서가 없어 기능 검증용 무서명
산출물이다.

## 재현 가능한 Windows 빌드 보완

- MSBuild 플러그인의 260자 제한을 피하도록 Windows ASCII 스테이징 루트를 짧게
  만들었다.
- 구형 Android `aapt.exe`가 한글 작업공간 경로를 읽지 못하는 경우 APK를 짧은
  ASCII 경로에 SHA-256 검증 복사한 뒤 검사하고 즉시 정리한다.

iOS Simulator와 macOS ad-hoc ZIP은 이 변경 커밋의 Codemagic macOS M2
워크플로에서 `MOCK/RUNTIME`으로 생성·실행 검증했다. iOS 첫 프레임은 2,631ms,
macOS 첫 프레임은 421ms에 확인했다. 기기 설치용 IPA나 서명·공증된 macOS
배포본으로 표시하지 않으며, 최종 파일과 evidence는
`release-manifest-1.32.0.json`에 SHA-256으로 결속했다.
