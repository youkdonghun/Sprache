# Sprache 1.32.0 컴팩트 UX 1–30 검증

검증일: 2026-08-03
대상: `apps/client`의 컴팩트 UX 목표 1–30
결론: **30/30 PASS**

이번 감사에서는 체크리스트 표시만 보지 않고 실제 화면 코드, 저장 호환성, 위젯 테스트와
좁은 화면 렌더링을 서로 대조했다. 감사 중 발견한 15분 예상 문제 수의 근접 표시,
고급 연습 설정의 범위, 컴팩트 프리셋의 완전한 실행 취소와 320px 화면 오버플로도 함께
수정했다.

## 최종 검증 수치

| 검증 | 결과 |
|---|---|
| `dart analyze` (`apps/client`) | 이슈 0건 |
| 목표 1–30 집중 회귀 14개 파일 | 84/84 통과 |
| `app_smoke_test.dart` | 58/58 통과 |
| 집중 회귀와 앱 스모크 합계 | 142/142 통과 |
| 런타임 커튼 문자열·심볼 검색 | `apps/client/lib`에서 0건 |
| 좁은 화면 접근성 | 320px 자료실, 320px·200% 학습 허브 포함 오버플로 0건 |

## 항목별 근거

| # | 프로덕션 코드·실제 최종 상태 | 테스트·실측 근거 | 판정 |
|---:|---|---|:---:|
| 01 | `app.dart`에서 복귀 커튼 상태·타이머·오버레이를 제거했다. 런타임 소스에는 `privacyCurtain`, `curtainDuration`, `Sprache 보호 중`이 없다. | `privacy_mode_scope_test.dart`; `rg` 검색 0건 | PASS |
| 02 | `device_preferences.dart`에서 커튼 enum과 필드를 제거했다. `fromJson`은 과거 `curtainDelay`를 무시하고 `toJson`은 다시 내보내지 않는다. | `device_preferences_test.dart`의 `immediate`, `seconds60` 레거시 JSON 호환 테스트; `device_preferences_store_test.dart` | PASS |
| 03 | `settings_screen.dart`는 사생활 보호 모드, 알림 내용 표시, Drive 동기화 일시 중지를 서로 독립된 설정으로 안내한다. | `privacy_mode_scope_test.dart`, `data_health_report_test.dart`, 설정 스모크 | PASS |
| 04 | `AppLayoutDensity`를 공통 테마 확장으로 두고 페이지·카드·섹션·컨트롤·사이드바·주제 바 수치를 공급한다. 컴팩트 데스크톱은 페이지 `18/14`, 카드 `12`, 섹션 `12`, 컨트롤 `2`; 모바일 좌우 `12`다. | `app_theme_preferences_test.dart`에서 각 밀도 토큰 값을 직접 검증 | PASS |
| 05 | `responsive_shell.dart`가 토큰을 사용한다. Windows 사이드바는 기본 `212/72px`, 컴팩트 `200/68px`; 컴팩트 조작 높이는 `44px`다. | `responsive_shell_personalization_test.dart`, 테마 수치 테스트 | PASS |
| 06 | 사이드바 항목·보조 동작 사이 간격을 `desktopSidebarPadding`, `sectionGap`, `controlGap` 기반으로 통일하고 보조 동작을 한 도구 행으로 묶었다. | 반응형 셸 개인화 테스트에서 기본/컴팩트 폭과 도구 노출 검증 | PASS |
| 07 | 상단 학습 주제 바의 토큰 높이는 `52px`이며 실제 셸은 접근성을 위해 최소 `54px`로 고정한다. 주제 선택과 보조 동작은 최소 `44px`다. | 반응형 셸 테스트와 실제 렌더 크기 대조 | PASS |
| 08 | `home_screen.dart`의 첫 학습 카드는 진행 중 세션이면 `_ResumeSessionCard`, 아니면 하나의 `_DailyHero`만 사용한다. 핵심 버튼 키는 `home-primary-study-button` 하나다. | `home_personalization_regression_test.dart`, 홈 진입·이어하기 스모크 | PASS |
| 09 | 오늘 계획은 `home-today-plan-summary-row` 한 줄에 복습·새 학습·취약 항목 세 지표를 배치한다. | 기본 높이 `<100px`, 컴팩트 전체 높이 `<=60px` 실측 테스트 | PASS |
| 10 | 복습 수가 0이면 복습 전용 큰 빈 카드를 만들지 않고 다음 일정·휴식일·다음 학습으로 주 행동을 넘긴다. 0은 작은 지표로만 남는다. | 홈 회귀 테스트와 `reviewCount == 0` 경로 대조 | PASS |
| 11 | 주간 목표는 `home-weekly-target-summary-row` 진행 스트립으로 축약했다. | 기본 `<=60px`, 컴팩트 `<=50px` 실측 테스트 | PASS |
| 12 | 홈 헤더는 `520px`, `370px` 경계에서 보조 내용을 축약하고 말줄임한다. 지표는 `Expanded`로 폭을 나눈다. | 320–430px 스모크, 모바일 1.3배 글자 크기 테스트 모두 오버플로 0건 | PASS |
| 13 | `quick_content_sheet.dart`는 자료 종류 다음에 표현·뜻 핵심 입력을 먼저 두고 그룹·추가 정보·작업 도구를 뒤로 보낸다. | `quick_content_workbench_test.dart`의 필수 필드 선행 순서 검증 | PASS |
| 14 | 읽기·예문·태그·즐겨찾기·우선순위는 `quick-content-more`의 `추가 정보` 안에 접힌다. 헤더에는 입력된 선택 항목 수만 요약한다. | 추가 정보가 초기에는 접히고 요청 뒤 나타나는 위젯 테스트 | PASS |
| 15 | 최근 언어는 `activeSubjectId`, 종류·그룹은 언어별 `lastKindBySubject`·`recentGroupBySubject`로 저장한다. 존재하지 않는 최근 그룹은 자동 선택하지 않는다. | 빠른 등록 워크플로·개인화 저장 회귀 테스트 | PASS |
| 16 | 템플릿·바구니·실행 취소는 접힌 `quick-content-workbench` 한 행으로 시작하며 개수를 헤더에 요약한다. 실행 취소 기록은 최대 5개다. | 작업대 초기 접힘, 바구니 저장, 5단계 실행 취소 테스트 | PASS |
| 17 | 그룹 검색·새 그룹 만들기는 `quick-content-group-options` 안에 두고, 새 그룹 입력은 `quick-content-show-new-group`을 누른 뒤에만 표시한다. | 그룹 도구 지연 노출과 새 그룹 생성 워크플로 테스트 | PASS |
| 18 | 빠른 등록 시트는 컴팩트/보통 좌우 여백 `12/18px`, 최대 폭 `680/720px`, 최대 높이 `720/760px`, 하단 여백 `10/16px`를 사용한다. | 320×700, 200% 글자 크기에서 고정 하단 동작과 입력 화면 오버플로 0건 | PASS |
| 19 | 중복 요약을 핵심 입력 바로 아래에 먼저 표시하고 전체 비교는 `quick-content-duplicate-details-toggle`을 눌렀을 때만 연다. | 중복 상세가 초기에는 없고 요청 후 기존/신규 비교가 나타나는 테스트 | PASS |
| 20 | 저장·바구니·학습 동작은 스크롤 밖 고정 하단 바에 있고, 연속 등록 저장은 스낵바와 세션 실행 취소로 되돌릴 수 있다. | Enter 저장, 200% 글자 크기 동작 바, 바구니 5단계 실행 취소 테스트 | PASS |
| 21 | `library_screen.dart`는 검색·활성 필터·그룹 도구·강도 필터를 결과 바로 위 하나의 제어 영역에 모은다. | 자료실 검색 스모크; 320px에서 결과/페이지 영역 오버플로 0건 | PASS |
| 22 | 자료 저장 흐름은 `LearningDataFlowCard(condensed: true)`로 시작하고 상세 설명은 별도 시트에서 연다. 스마트 컬렉션도 작은 수평 칩/행으로 표시한다. | `learning_data_flow_storage_test.dart`에서 요약 카드 실측 높이 `<=60px` 및 직접 다음 동작 검증 | PASS |
| 23 | 개인 추천 Practice Hub는 높이 `88px`의 수평 추천 행이며 카드 폭은 `180px`다. 큰 글자에서는 근거 배지를 요약 문장으로 합친다. | 추천 허브 높이 정확히 `88px`; 320px·200% 글자 크기 오버플로 0건 | PASS |
| 24 | 한 연습 카탈로그에서 실수 복습·단어·듣기·말하기·문장·게임 진입점을 빠르게 훑을 수 있다. | `practice_catalog_workflow_test.dart`; 학습/퀴즈/문장/말하기 분리 스모크 | PASS |
| 25 | 세션 설정은 `practice-time-options` 한 줄 묶음에 3·5·10·15분 선택지를 제공하고 각 조작 영역은 최소 `44px`다. | 프리셋 노출·선택·영속화와 44px 제어 회귀 테스트 | PASS |
| 26 | 선택 직후 프리셋 바로 아래 `practice-time-selected-estimate` live region이 `3→7`, `5→12`, `10→24`, `15→36` 문제를 보여 주며 실제 재고로 상한을 제한한다. | 15분 선택 시 `선택 · 15분 · 예상 36문제`; 실행 계획 `15분/36문제` 검증 | PASS |
| 27 | 기본 화면에는 시간·문제 수·난이도만 남기고 기록 범위·출제 순서·진행 기록·채점·힌트 등은 `practice-advanced-settings` 안으로 이동했다. | 고급 설정이 접혔을 때 `practice-advanced-history-and-order`가 없고 펼친 뒤 나타나며 값이 유지되는 테스트 | PASS |
| 28 | 연습 허브 순서는 추천 다음에 최근 사용, 즐겨찾기를 두고 일반 검색·카테고리를 뒤에 둔다. | 최근 행이 카테고리보다 앞서는 위치 검증과 즐겨찾기 안정 정렬 테스트 | PASS |
| 29 | 개인화 화면의 처음 열린 테마 섹션에 화면 모드·강조색·글자 크기·`theme-density-group`을 함께 둔다. | `personalization_panel_test.dart`, 테마/밀도 선택 회귀 테스트 | PASS |
| 30 | `compactWorkspace`는 밀도·카드·본문 폭·홈 집중 모드·선택형 탐색 레이블·컴팩트 주제 전환·모듈 표시를 한 번에 적용한다. 적용 전 전체 `StudyPreferences` 스냅샷을 저장해 `undo-compact-workspace-preset`으로 색상과 비관련 목표까지 완전히 복원한다. | 프리셋 단위 테스트와 실제 화면 통합 테스트에서 일일/주간 목표, 색상, 밀도, 홈, 탐색, 모듈 전체 복원 검증 | PASS |

## 감사 중 보완한 결함

- 15분 프리셋의 예상 문제 수를 프리셋 바로 아래에서 확인할 수 있도록 추가했다.
- 학습 기록과 출제 순서를 고급 설정 안으로 이동해 기본 세션 설정을 더 짧게 만들었다.
- 컴팩트 작업 공간 적용 전 전체 설정을 보관해 스낵바의 실행 취소가 실제로 모든 값을 복원하게 했다.
- 320px 자료실에서 페이지 도구가 결과 높이를 잠식하던 오버플로를 제거했다.
- 320px·200% 글자 크기의 추천 허브에서 근거 배지가 넘치던 문제를 제거했다.

## 검증 명령

```powershell
dart analyze
flutter test test/domain/device_preferences_test.dart `
  test/data/device_preferences_store_test.dart `
  test/widget/privacy_mode_scope_test.dart `
  test/theme/app_theme_preferences_test.dart `
  test/widget/responsive_shell_personalization_test.dart `
  test/widget/home_personalization_regression_test.dart `
  test/widget/quick_content_workbench_test.dart `
  test/widget/quick_content_workflow_test.dart `
  test/widget/learning_data_flow_storage_test.dart `
  test/widget/practice_catalog_workflow_test.dart `
  test/widget/practice_autonomy_test.dart `
  test/domain/practice_catalog_preferences_test.dart `
  test/domain/personalization_presets_test.dart `
  test/widget/personalization_panel_test.dart
flutter test test/widget/app_smoke_test.dart
```
