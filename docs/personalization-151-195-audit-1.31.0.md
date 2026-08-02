# Sprache 1.31.0 목표 151–195 독립 감사

감사일: 2026-08-03

범위는 개인화 계획의 151–195번이다. 모델 또는 화면 문구만 존재하는 경우는
완료로 보지 않고, 실제 사용자 흐름 연결과 회귀 테스트를 함께 확인했다. 특히
플랫폼 입력은 Dart 경계뿐 아니라 Android·iOS·macOS·Windows 호스트 연결까지,
백그라운드 수명 주기는 실제 앱 수명 주기와 활성 미디어 화면 연결까지 감사했다.

## 목표별 1:1 근거

| # | 구현 근거 | 검증 근거 |
|---:|---|---|
| 151 | `content_quality_audit.dart`의 읽기·문맥·연습 가능성·출처별 점수와 0–100 종합 점수, `content_quality_screen.dart` | `content_quality_audit_test.dart`의 불완전 항목 점수 테스트, `content_quality_workflow_test.dart` |
| 152 | `ContentQualityIssueFilter`와 품질 큐의 이슈 건수·다음 항목·수정 뒤 필터 복귀 흐름 | `content_quality_workflow_test.dart`의 품질 큐 필터·수정 회귀 |
| 153 | `ContentQualityAuditor`의 주제 범위 NFKC 정규화 정답 충돌 탐지 | `content_quality_audit_test.dart`의 동일 주제 탐지와 다른 주제 격리 테스트 |
| 154 | `exercise_readiness.dart`의 듣기·빈칸·배열·발음 readiness 및 불가 사유 | `content_quality_audit_test.dart`의 명시적 연습 불가 사유 테스트 |
| 155 | 품질 큐가 교정 메모·출처·readiness 이슈를 통합하고 사용자 콘텐츠만 수정 | `content_quality_workflow_test.dart`의 사용자 자료 편집·기본 자료 보호 테스트 |
| 156 | `pronunciation_score.dart`의 누락·추가·치환 토큰 정렬과 `pronunciation_screen.dart`의 아이콘·문구 패널 | `pronunciation_advanced_feedback_test.dart`의 토큰 정렬 설명 테스트 |
| 157 | `pronunciation_ladder.dart`의 명시 sentence token 우선 분절과 이전·반복·다음 제어 | `pronunciation_advanced_feedback_test.dart`의 explicit-token shadowing 테스트 |
| 158 | 발음 화면의 0.6·0.75·1.0배 목표 음성 및 임시 녹음 A/B 제어 | `pronunciation_advanced_feedback_test.dart`, `pronunciation_voice_recording_test.dart` |
| 159 | `pronunciation_signal.dart`의 무음·소음·locale 사전 판정과 재시도 안내 | `pronunciation_advanced_feedback_test.dart`의 신호 판정 테스트, 음성 녹음 위젯 테스트 |
| 160 | `PronunciationAttemptMetric`이 점수·시각·방식만 보관하고 발음 화면에서 전체 삭제 | metric JSON 원문 비포함 테스트와 `pronunciation_voice_recording_test.dart`의 기록 삭제 테스트 |
| 161 | `offline_readiness.dart`의 SQLite·콘텐츠·TTS·음성팩·대기 저장 점검 및 `data_health_screen.dart` 카드 | `platform_continuity_test.dart`의 준비 상태·capability 판정 테스트 |
| 162 | 세션 mode를 완전 오프라인/기기 서비스 필요로 분류하고 fallback을 산출 | `platform_continuity_test.dart`의 capability 제한·대체 설명 테스트 |
| 163 | 발음 화면의 음성 서비스 불가 시 읽기 표기·수동 평가 전환 | `pronunciation_voice_recording_test.dart`의 수동 평가 fallback 테스트 |
| 164 | `study_completion_receipt.dart`와 학습 완료 화면의 저장 시각·XP·연속일·대기 건수 영수증 | `study_completion_receipt_test.dart`, `completion_actions_test.dart` |
| 165 | `ReconnectSyncSummary`와 홈의 업로드·병합·충돌·보류 1회 요약 및 재시도 진입 | `sync_center_state_test.dart`의 1회 소비·재시도 상태 테스트 |
| 166 | `device_preferences.dart`·`device_preferences_state.dart`의 조용한 시간·잠금화면 기기 전용 저장 | `device_preferences_test.dart`, `device_preferences_store_test.dart`, `device_notification_policy_test.dart` |
| 167 | 설정 화면의 다음 알림 3개 현지 시각·내용 preview와 테스트 알림 | `device_notification_policy_test.dart`, `saved_session_plans_test.dart` |
| 168 | 알림 payload의 exact saved-plan ID 검증 후 세션 또는 안전한 builder로 이동 | `device_notification_policy_test.dart`의 exact-plan decode와 `saved_session_plans_test.dart` |
| 169 | 시작·10분·30분·내일 action을 payload 한 건으로 해석하고 계획 상태에 원자 적용 | `device_notification_policy_test.dart`, `saved_session_plans_test.dart`의 action 적용 테스트 |
| 170 | `study_notification_service.dart`의 Darwin 권한·예약·category/action 연결, 기존 Android/Windows 경로 유지 | `device_notification_policy_test.dart`의 플랫폼 중립 정책·action 회귀와 Apple CI 빌드 단계 |
| 171 | `text_import_decoder.dart`의 UTF-8/BOM·UTF-16·CP949 strict 감지와 수동 인코딩 재선택 UI | `text_import_decoder_test.dart`의 4개 감지·오류 테스트 |
| 172 | delimiter 감지와 `import_screen.dart`의 쉼표·탭·세미콜론 첫 행 preview 선택 | `text_import_decoder_test.dart`, `import_review_test.dart` |
| 173 | `xlsx_import_reader.dart`의 sheet metadata와 선택 sheet 전용 파싱·preview dialog | `xlsx_sheet_selection_test.dart`의 논리 sheet 이름·선택 sheet 테스트 |
| 174 | 차단 행 편집 dialog가 ID·표현·뜻을 검증한 뒤 preview를 다시 reconcile | `import_review_test.dart`의 `blocked import row can be edited and revalidated` |
| 175 | `import_report_exporter.dart`의 stable error code·원문 기본 제외 CSV 보고서 | `import_report_exporter_test.dart`의 개인정보 제외·안정 코드 테스트 |
| 176 | `study_routines.dart`의 요일·현지 시각·주제별 saved-plan 묶음과 명시 순서 | `study_routines_test.dart`, `study_routine_state_test.dart`, `study_routine_workflow_test.dart` |
| 177 | 홈·알림에서 due/weak 항목 3–5개로 만드는 2분 quick-study plan | `study_routines_test.dart`, `study_routine_workflow_test.dart` |
| 178 | 놓친 분량을 남은 학습 요일에 daily cap 이하로 균등 재분배 | `study_routines_test.dart`의 missed-work cap 테스트 |
| 179 | 완료 시각의 로컬 시간대 추천과 사용자 명시 적용·저장 | `study_routines_test.dart`, `study_routine_state_test.dart` |
| 180 | 완료 화면의 종료·오답 재학습·다음 예약·루틴 행동 compact action row | `completion_actions_test.dart` |
| 181 | `PrivacyModeScope`·앱 privacy frame이 원문·뜻·계정 식별자를 가리고 수치를 유지 | `privacy_curtain_test.dart`의 redaction·수치 보존 테스트 |
| 182 | 기기 전용 0·15·60초 curtain 정책과 resume 해제 | `privacy_curtain_test.dart`의 즉시 curtain·resume 테스트, `device_preferences_test.dart` |
| 183 | `clipboard_read_session.dart`가 명시 동작당 한 번만 읽고 미확정 값을 보관하지 않음 | `clipboard_read_session_test.dart`의 claim-before-await·중복 방지·실패 제거 테스트 |
| 184 | `temporary_voice_recording_service.dart` janitor를 앱 시작과 발음 화면 종료에 연결 | `temporary_voice_recording_janitor_test.dart`, `pronunciation_voice_recording_test.dart` |
| 185 | `connection_state.dart`의 토큰·Drive ID·원문 없는 진단 bundle 복사/내보내기 | `sync_center_state_test.dart`의 record ID·source preview 제외 테스트 |
| 186 | 기기 설정은 Drift 별도 키, 학습·화면 취향은 계정 snapshot으로 분리 | `device_preferences_test.dart`, `device_preferences_store_test.dart`, `study_preferences_test.dart` |
| 187 | `sync_policy.dart`·connection state의 stable operation ID와 완료 영수증 중복 차단 | `sync_center_state_test.dart`의 완료 operation 재적용 방지 테스트 |
| 188 | `import_review_draft.dart`가 hash·열 mapping·선택·목적지만 저장하고 원문 row를 제외 | `import_review_draft_test.dart`의 round-trip·원문 제외·손상 격리 테스트 |
| 189 | `app_database.dart`의 WAL·FULL/fullfsync 및 교체 transaction rollback | `database_durability_test.dart`의 partial replacement·SQLITE_FULL 보존 테스트 |
| 190 | `local_civil_schedule.dart`가 현재 zone에서 civil rule을 재계산하고 기록 instant는 유지 | `local_civil_schedule_test.dart`의 DST 반복/누락·여행·과거 기록 불변 테스트 |
| 191 | `platform_capabilities.dart`의 네 플랫폼 Drive·알림·TTS·음성·파일 열기 중앙 표 | `platform_continuity_test.dart`의 실제/preview 제한 설명 테스트 |
| 192 | `inbound_intent.dart`·`platform_inbound_intent_service.dart`의 typed/allowlisted intent와 `SpracheApp` hydration 후 drain, 네 플랫폼 host bridge | `platform_continuity_test.dart`의 parser 거부/허용 테스트와 `inbound_intent_integration_test.dart`의 초기 파일·runtime deep link 테스트 |
| 193 | `MediaLifecycleCoordinator`·registry를 앱 pause/detach와 학습·발음·플래시카드·미션·가이드·노트 화면에 연결 | `platform_continuity_test.dart`의 fan-out/order 테스트와 `pronunciation_voice_recording_test.dart` |
| 194 | 앱·주요 입력 화면의 `SafeArea`, 스크롤 기반 입력, 시스템/앱 text scale 합성, 좁은 폭 adaptive layout | `settings_accessibility_layout_test.dart`의 320/360px·2.0x·명암 행렬, `platform_back_protection_test.dart`, `release_visual_semantics_matrix_test.dart` |
| 195 | Android intent filter, iOS/macOS document type·scheme, Windows OpenWith/protocol 등록이 모두 typed inbound 파일 preview로 수렴 | `inbound_intent_integration_test.dart`, 플랫폼 metadata XML 정적 검사, `test-windows-installer.ps1`의 설치·실행 경로·제거 registry smoke |

## 감사 중 보완한 명백한 공백

- 174: 차단 행의 ID·표현·뜻을 수정한 뒤 실제로 `blocked`에서 안전한 기본
  `add` 상태로 다시 분류되는 위젯 회귀 테스트를 추가했다.
- 192: parser만 있던 경계를 앱 시작 인수·runtime channel·hydration 이후 라우팅과
  Android·iOS·macOS host bridge까지 연결했다. 같은 intent의 중복 전달도 억제한다.
- 193: lifecycle 유틸을 실제 `AppLifecycleState`와 활성 화면 registry에 연결했다.
  체크포인트·pending write flush 뒤 TTS·STT·녹음·효과음을 중지한다.
- 195: Windows는 사용자 기본앱을 강제하지 않고 `OpenWithProgids`와
  `sprache://`만 등록한다. 설치 smoke가 실행 경로와 `%1`, 제거 뒤 잔여 key까지
  확인하도록 보강했다.

## 검증 결과

```powershell
dart analyze <151-195 관련 구현 및 테스트 15개 파일>
flutter test <151-160 관련 4개 테스트 파일>
flutter test <161-170 관련 4개 테스트 파일>
flutter test <171-180 관련 8개 테스트 파일>
flutter test <181-190 관련 8개 테스트 파일>
flutter test <191-195 관련 4개 테스트 파일>
```

- 관련 Dart 정적 분석: 경고·오류 0건.
- 목표별 기능·위젯 회귀: 28개 테스트 파일, 94개 테스트 전부 통과.
- Android/iOS/macOS manifest·plist: XML 구문 및 등록 항목 정적 검사 통과.
- Windows association 설치 smoke script: PowerShell 구문 검사 통과. 실제 설치
  smoke는 Windows release installer가 생성된 뒤 최종 릴리스 게이트에서 수행한다.

Apple 서명·공증은 이 감사의 완료 근거가 아니다. iOS simulator와 unsigned/ad-hoc
macOS 산출물은 별도 GitHub macOS 릴리스 잡의 결과와 manifest로 최종 봉인한다.
