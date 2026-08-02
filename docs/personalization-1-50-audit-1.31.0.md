# Sprache 1.31.0 목표 1–50 독립 감사

감사일: 2026-08-03

범위는 개인화 계획의 1–50번이다. 각 항목은 설정 모델 존재 여부만 보지 않고,
실제 화면 반영, 로컬 영속화·손상 복구, 사용자 동작 회귀 테스트를 함께 확인했다.

## 목표별 근거

| # | 구현 근거 | 검증 근거 |
|---:|---|---|
| 1 | `personalization_screen.dart`의 홈 요약·카드·퀴즈 `_LivePreview` | `personalization_panel_test.dart` |
| 2 | `PersonalizationPreset.sprache`가 시각 기본값만 복원 | `personalization_presets_test.dart` |
| 3 | `focus` 프리셋의 집중 폭·최소 장식·reduced motion | `personalization_presets_test.dart` |
| 4 | `paper` 프리셋의 warm surface·narrow reading width | `personalization_presets_test.dart` |
| 5 | `oledNight`와 OLED scaffold/card surface 모두 `#000000` | `app_theme_preferences_test.dart`, `personalization_presets_test.dart` |
| 6 | Sunrise 주황·남색 팔레트와 선택 UI | `app_theme_preferences_test.dart`, `theme_expansion_personalization_test.dart` |
| 7 | Mint 장시간 학습 팔레트와 선택 UI | 같은 팔레트 고유성·조작 테스트 |
| 8 | Rose 팔레트와 선택 UI | 같은 팔레트 고유성·조작 테스트 |
| 9 | Mono 저자극 팔레트와 선택 UI | 같은 팔레트 고유성·조작 테스트 |
| 10 | neutral/warm/cool surface가 실제 scaffold·surface에 적용 | `app_theme_preferences_test.dart` |
| 11 | rounded/balanced/square가 카드·컨트롤 radius에 적용 | `app_theme_preferences_test.dart`, `theme_expansion_personalization_test.dart` |
| 12 | flat/outlined/elevated가 border·elevation에 적용 | 같은 테마 테스트 |
| 13 | standard/strong이 본문 font weight에 적용 | 같은 테마 테스트 |
| 14 | high contrast와 focus ring을 독립 저장·적용 | `app_theme_preferences_test.dart`, `theme_expansion_preferences_test.dart` |
| 15 | extra-large app/study text와 line-height/reading-width 프로필 | `theme_expansion_personalization_test.dart`, `study_interaction_behavior_test.dart` |
| 16 | focused/balanced/wide가 880/1120/1360px 제한으로 적용 | `responsive_shell_personalization_test.dart` |
| 17 | full은 플랫폼 기본, reduced는 저자극 fade, off는 즉시 전환 | `app_theme_preferences_test.dart`의 전환 빌더 동작 테스트 |
| 18 | full/subtle/off 축하 표현이 정답·완료 UI에 적용 | `study_interaction_behavior_test.dart` |
| 19 | focus/balanced/insights가 홈의 폭·우선 배치를 실제 변경 | `home_personalization_regression_test.dart`의 3개 레이아웃 위치 테스트 |
| 20 | `showHomeHeader`로 인사말·주제 헤더 제어 | `home_personalization_regression_test.dart` |
| 21 | `showStreak`가 홈과 실시간 미리보기에서 제어 | `personalization_panel_test.dart` |
| 22 | `showXp`가 홈 XP·레벨 영역을 제어 | `home_personalization_regression_test.dart` |
| 23 | `showSyncStatus`가 홈·데스크톱 저장 상태 문구를 제어 | `responsive_shell_personalization_test.dart` |
| 24 | `showTodayPlan`이 오늘 계획 카드를 제어 | `home_personalization_regression_test.dart` |
| 25 | 고정 컬렉션 선반 visibility와 순서 적용 | `personalization_panel_test.dart`, `home_personalization_regression_test.dart` |
| 26 | 최근 추가 자료 선반 visibility와 순서 적용 | 같은 홈 순서 회귀 테스트 |
| 27 | 학습 데이터 흐름 카드 visibility와 순서 적용 | 같은 홈 순서 회귀 테스트 |
| 28 | 예약 학습 목록 visibility와 순서 적용 | `home_screen.dart`의 personalized section switch, 설정 패널 회귀 테스트 |
| 29 | 네 섹션의 위·아래 이동과 정규화된 순서 저장 | `personalization_panel_test.dart`, `app_experience_preferences_test.dart` |
| 30 | 홈 필드만 초기화하고 등록·테마 설정은 보존 | `personalization_panel_test.dart` |
| 31 | always/selected/iconsOnly을 모바일·데스크톱 내비게이션에 적용 | `responsive_shell_personalization_test.dart` |
| 32 | 전역 빠른 추가 chrome 표시 토글 | 같은 테스트의 hidden chrome 회귀 |
| 33 | 전역 검색 chrome 표시 토글 | 같은 테스트의 hidden chrome 회귀 |
| 34 | full/compact 주제 전환기와 접근 가능한 의미 정보 유지 | 같은 테스트의 compact switcher 회귀 |
| 35 | word/sentence/lastUsed 초기 종류와 주제별 마지막 종류 복원 | `quick_content_personalization_test.dart` |
| 36 | 상세 필드 expansion 기본값을 sheet에 적용 | 같은 빠른 등록 테스트 |
| 37 | 즐겨찾기 기본값을 저장된 자료에 적용 | 같은 빠른 등록 테스트 |
| 38 | 우선순위 0–5 기본값을 저장된 자료에 적용 | 같은 빠른 등록 테스트 |
| 39 | ask/merge/separate가 각각 중단·병합·별도 ID 저장으로 동작 | 같은 테스트의 3개 중복 정책 회귀 |
| 40 | 저장 직전 공통 NFKC·공백 정규화 | 같은 테스트의 Unicode 입력 회귀 |
| 41 | 저장 후 닫기/계속 추가 기본 흐름과 반대 동작 버튼 제공 | 같은 테스트 및 `quick_content_sheet.dart` |
| 42 | 최근 태그를 주제별 로컬 저장하고 다음 등록에 chip 추천 | 같은 테스트의 reopen 회귀 |
| 43 | 200–2000ms debounce와 빠르게/균형/느리게 라벨 | 같은 테스트의 1200ms 경계 회귀, `personalization_panel_test.dart` |
| 44 | 필수 0/2–2/2 상태와 스크린리더 label을 실시간 갱신 | 같은 빠른 등록 테스트 |
| 45 | 동적 경로를 canonical activity ID로 마이그레이션·정규화 | `practice_catalog_preferences_test.dart` |
| 46 | 최근 실행 ID·횟수 선반과 저장 규칙 즉시 재실행 | `practice_catalog_workflow_test.dart`, `practice_autonomy_test.dart` |
| 47 | 즐겨찾기 앞·뒤 이동과 stable order 영속화 | `practice_catalog_workflow_test.dart` |
| 48 | quick launch가 설정 창을 건너뛰고 설정 변경 진입은 유지 | 같은 워크플로 테스트 |
| 49 | 로컬 날짜·subject ID·활성 후보 ID로 결정적 도전 계산 | 같은 테스트의 재진입 동일 도전 회귀 |
| 50 | due/wrong/accuracy 기반 추천 basis와 카드별 reason 표시 | `practice_catalog_workflow_test.dart`, `learning_hub_screen.dart` |

## 감사 중 보완한 명백한 공백

- 5: OLED 카드 표면도 scaffold와 동일한 완전 검정으로 맞췄다.
- 17: motion 설정을 실제 페이지 전환 빌더에 연결했다.
- 19: 세 홈 레이아웃의 실제 배치 차이를 검증하는 회귀 테스트를 추가했다.
- 32–33: 검색·빠른 추가를 숨겨도 도움말·주 내비게이션이 유지되는지 검증했다.
- 39: 질문·병합·별도 저장 세 정책의 실제 저장 결과를 각각 검증했다.
- 43: 자동 저장 간격에 빠르게·균형·느리게 의미 라벨을 추가하고 debounce 경계를 검증했다.

## 검증 명령

```powershell
flutter analyze <1-50 관련 구현 및 테스트 20개 파일>
flutter test <1-50 관련 14개 테스트 묶음>
```

정적 분석 20개 파일은 경고·오류 0건이며, 1–50 관련 14개 테스트 파일의
105개 테스트가 모두 통과했다.
