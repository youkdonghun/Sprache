# Sprache 1.31.0 개인화 200개 목표 검증 보고서

검증 기준일: 2026-08-03

대상 버전: `1.31.0+55`

이 문서는 [200개 개선 목표](personalization-200-upgrade-plan-1.31.0.md)의 완결성과
목표별 구현·회귀 근거를 한곳에서 찾기 위한 색인이다. 최종 실행 파일의 해시나
아직 실행되지 않은 CI 결과를 미리 확정하지 않는다. 네 플랫폼 산출물의 최종 사실은
검증을 통과한 `release-manifest-1.31.0.json`과 그 manifest가 가리키는 runtime
evidence만을 기준으로 한다.

## 로드맵 완결성

로드맵의 번호와 상태를 기계적으로 검사한 결과는 다음과 같다.

```text
항목 수       200
고유 번호     200
최솟값/최댓값 1/200
완료 [x]      200
미완료        0
중복/누락     0
```

따라서 목표 목록 자체는 정확히 1–200의 연속된 고유 번호이며 모든 항목이
`[x]` 상태다. 이 검사는 구현 체크리스트의 구조를 보증한다. 최종 통합 테스트,
플랫폼 빌드, 실제 첫 프레임과 산출물 무결성은 아래 릴리스 게이트를 별도로
통과해야 한다.

## 목표 범위별 구현·검증 근거

| 목표 | 범위 | 근거 |
|---:|---|---|
| 1–50 | 테마, 홈, 등록 기본값, 게임 발견 | [1–50 독립 감사](personalization-1-50-audit-1.31.0.md): 50개 1:1 구현/테스트 표, 관련 정적 분석 오류 0건, 14개 테스트 파일 105개 테스트 통과 기록 |
| 51–110 | 등록 작업대, 검색, 자료실, 게임 자율성, 온보딩, 적응형 학습, 통계 | [51–110 구현 감사](personalization-51-110-audit-1.31.0.md): 60개 1:1 구현/테스트 표, 관련 정적 분석 오류 0건, 16개 테스트 파일 70개 테스트 통과 기록 |
| 111–120 | 스크린리더, 초점, 키보드 재지정, 투명도, 비색상 피드백, TTS·효과 강도 | `study_accessibility_111_120_test.dart`, `keyboard_help_accessibility_test.dart`, `accessibility_input_profile_test.dart`, `device_voice_feedback_settings_test.dart`, `tts_interaction_preferences_test.dart` |
| 121–140 | 확장 테마, 데이터 건강, 복구 체크포인트, 선택 복원, 완전 오프라인 잠금 | [121–140 독립 감사](personalization-121-140-audit-1.31.0.md): 20개 1:1 구현/테스트 표, 관련 정적 분석 오류 0건, 13개 테스트 파일 38개 테스트 통과 기록 |
| 141–150 | 플랫폼 단축키·메뉴·드롭·선택·창 복원·뒤로 가기·적응형 패널·완료 행동 | `platform_workspace_test.dart`, `library_multiview_workflow_test.dart`, `window_placement_service_test.dart`, `platform_back_protection_test.dart`, `completion_actions_test.dart`, `responsive_shell.dart` |
| 151–195 | 품질·발음, 오프라인·알림, 가져오기, 루틴, 개인정보·내구성, 네 플랫폼 연속성 | [151–195 독립 감사](personalization-151-195-audit-1.31.0.md): 45개 1:1 구현/테스트 표, 관련 정적 분석 오류 0건, 28개 테스트 파일 94개 테스트 통과 기록 |
| 196–200 | fuzz, golden·semantics, 성능, 1.30→1.31 E2E, 네 플랫폼 manifest | [품질·릴리스 게이트](release-quality-gates-1.31.0.md)와 `test/qa`의 고정 fixture·테스트, `release-bundle.mjs` 검증 규칙 |

111–120과 141–150의 상세 목표 문구는 [원본 로드맵](personalization-200-upgrade-plan-1.31.0.md)에
있으며 위 표의 전용 회귀 테스트와 실제 연결 지점을 근거로 삼는다. 범위별 감사에
기록된 통과 수는 각 독립 감사 당시의 집중 회귀 결과다. 전체 제품 suite와 최종
플랫폼 산출물 결과를 대신하지 않는다.

## 최종 통합 게이트

릴리스 후보는 아래 순서가 모두 성공해야 한다. 실제 실행 결과는
`release-manifest-1.31.0.json` 및 연결된 runtime evidence에만 기록한다.

1. `flutter analyze`와 전체 Flutter 테스트를 통과한다.
2. 고정 fuzz corpus, 8개 visual·semantics 행렬, 2만 행 가져오기·5만 항목 검색·
   1만 세션 통계 성능 예산, 1.30→1.31 실제 SQLite E2E를 통과한다.
3. API lint·테스트·빌드를 포함한 `npm test`를 통과한다.
4. `npm run build:real`로 Windows 설치 EXE·포터블 ZIP과 Android APK를 만든다.
5. `npm run verify:release`로 버전·ABI·운영 설정·서명 상태와 해시를 검사한다.
6. 최종 Windows 설치 EXE와 Android APK를 실제로 실행해 첫 프레임 runtime
   evidence를 수집한다.
7. GitHub macOS runner에서 iOS Simulator와 macOS 앱을 빌드·실행하고 각 runtime
   evidence를 회수한다.
8. 정확히 네 플랫폼 산출물과 네 evidence로 release manifest를 만들고 다시
   검증한다.

상세 명령과 합격 조건은 [릴리스 준비 감사](release-readiness-1.31.0.md)와
[빌드·릴리스 문서](build-and-release.md)를 따른다.

## REAL·MOCK 표시 정책

| 플랫폼 | 최종 표시 | 의미와 제한 |
|---|:---:|---|
| Windows | `REAL` | Google·Railway 실제 연결 설정으로 빌드한다. 코드 서명 인증서가 없으면 기능 검증용 무서명 설치 EXE이며 공개 배포용 Authenticode 서명본이 아니다. |
| Android | `REAL` | Mock Mode를 끄고 실제 연결 설정으로 빌드한다. 외부 release keystore가 없으면 파일명과 manifest에 `google-debug-signed`를 명시하며 Play 배포본으로 가장하지 않는다. |
| iOS | `MOCK` | GitHub macOS runner의 iOS Simulator 앱 ZIP이다. 실제 기기용 IPA가 아니며 App Store 서명·provisioning을 포함하지 않는다. |
| macOS | `MOCK` | unsigned/ad-hoc 앱 ZIP이다. Developer ID 서명과 Apple 공증을 거친 공개 배포본이 아니다. |

Apple Developer 인증서, provisioning profile, Developer ID 인증서와 공증 권한이
없는 환경에서는 iOS 기기용 IPA와 공증된 macOS 앱을 만들 수 없다. 이 제한은
파일명, manifest, 릴리스 보고서에서 숨기지 않는다.

## 해시와 실행 증거 원칙

- 이 문서에는 고정 SHA-256 값을 적지 않는다. 최종 파일이 모두 모인 뒤 생성한
  manifest가 각 산출물과 runtime evidence의 실제 SHA-256·바이트 길이를 봉인한다.
- `launched`와 `firstFrameRendered`는 해당 산출물을 실제 설치·실행해 확인했을 때만
  `true`로 기록한다. 빌드 성공을 실행 성공으로 바꾸어 쓰지 않는다.
- 산출물이나 evidence를 바꾸면 기존 manifest는 무효다. 새 manifest를 생성하고
  다시 검증한다.
- 절대 경로, 상위 경로 탈출, 심볼릭 링크, 플랫폼 중복 또는 누락, 파일 변조를
  허용하지 않는다.

## 기존 버전의 안전한 정리

1. 1.31.0 네 플랫폼 manifest와 runtime evidence를 먼저 검증한다.
2. Windows 새 설치본과 포터블 ZIP, Android 업그레이드 설치가 정상 동작하는지
   확인할 때까지 1.30 실행 산출물을 보존한다.
3. manifest 경로를 전달한 `npm run verify:release:promote`가 다시 검증한 뒤에만
   저장소의 구버전 **빌드 산출물**을 정리한다.
4. 실행 중인 구버전 프로세스는 새 버전 검증 후 정상 종료한다. 임의 강제 삭제로
   데이터 쓰기 중인 프로세스를 끊지 않는다.
5. 사용자 SQLite DB, 로컬 콘텐츠 폴더, Google Drive 데이터, 복구 체크포인트,
   백업, OS 보안 저장소의 토큰은 정리 대상이 아니다.
6. 바탕화면 전달 폴더의 manifest와 보고서는 재검증과 롤백 근거이므로 유지한다.

이 원칙은 “기존 버전 삭제”를 사용자 학습 데이터 삭제로 해석하지 않는다.
삭제 대상은 검증을 마친 뒤의 낡은 설치·패키지 산출물뿐이다.

## 관련 문서

- [1.31.0 릴리스 노트](release-notes-1.31.0.md)
- [200개 개선 목표 원본](personalization-200-upgrade-plan-1.31.0.md)
- [1–50 독립 감사](personalization-1-50-audit-1.31.0.md)
- [51–110 구현 감사](personalization-51-110-audit-1.31.0.md)
- [121–140 독립 감사](personalization-121-140-audit-1.31.0.md)
- [151–195 독립 감사](personalization-151-195-audit-1.31.0.md)
- [196–200 품질·릴리스 게이트](release-quality-gates-1.31.0.md)
- [릴리스 준비 감사](release-readiness-1.31.0.md)
