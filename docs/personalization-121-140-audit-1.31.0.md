# Sprache 1.31.0 목표 121–140 독립 감사

- 감사일: 2026-08-03
- 범위: 개인 테마 확장 121–130, Local-First 데이터 안전 131–140
- 원칙: 구현 흔적만으로 완료 처리하지 않고 모델·화면 연결·실제 회귀 테스트를 함께 확인했다.
- 결론: 20개 목표 모두 검증 완료. 감사 중 발견한 실제 공백 4건을 보완했다.

## 항목별 증거

| 번호 | 상태 | 구현 증거 | 테스트 증거 |
|---:|:---:|---|---|
| 121 | ✅ | `AppExperiencePreferences.lightAccentPalette/darkAccentPalette`가 밝기별 강조색을 직렬화하고 `AppTheme`이 현재 밝기에 맞춰 선택한다. | `theme_expansion_preferences_test.dart`, `theme_expansion_test.dart` |
| 122 | ✅ | `colorModeAt`·`nextThemeBoundaryAfter`와 `app.dart`의 경계 타이머가 사용자 지정 낮·밤 시각에 실제 테마를 다시 계산한다. | `theme_expansion_preferences_test.dart`의 야간 구간·다음 경계·동일 시각 안전 폴백 |
| 123 | ✅ | `AppTheme.safeCustomAccentColor`가 배경 대비 3:1 미만 색을 안전 방향으로 보정하며, 별도 안전 팔레트도 제공한다. | `theme_expansion_test.dart`의 밝은/어두운 배경 대비 검사 |
| 124 | ✅ | `themeProfiles`를 직렬화하고 `copyWith`와 파서 양쪽에서 최대 5개로 제한하며, 개인화 화면에서 현재 설정을 캡처한다. | `theme_expansion_preferences_test.dart`, `theme_expansion_personalization_test.dart` |
| 125 | ✅ | `_ThemeProfileManagerState`가 이름 변경·복제·삭제·위/아래 정렬을 제공하고 `_parseThemeProfiles`가 손상·중복·초과 프로필을 개별 격리한다. | 프로필 이름 변경·복제·정렬·삭제 위젯 회귀와 손상 격리 도메인 회귀 |
| 126 | ✅ | `AppFontFamily`과 `AppTheme._fontFamilyName`이 시스템 산세리프·플랫폼 세리프·고정폭과 번들 Noto Sans를 지원한다. | 세 글꼴 계열 테마 생성 및 개인화 선택 회귀 |
| 127 | ✅ | 앱 전체 `textScale`과 별도 `studyTextScale`을 저장하며 `study_screen.dart`가 문제·정답 영역에 전용 배율을 적용한다. | 개인화 화면에서 30% 확대 선택·상태 반영 회귀 |
| 128 | ✅ | `cardAlignment`를 적응형·왼쪽·가운데로 저장하고 학습 화면의 표현·뜻 양쪽 정렬에 적용한다. | 왼쪽 정렬 선택·상태 반영 위젯 회귀 |
| 129 | ✅ | `navigationIconStyle`을 적응형·윤곽형·채움형으로 저장하고 `responsive_shell.dart`의 모바일·데스크톱 내비게이션 아이콘에 적용한다. | 윤곽형 선택과 프로필 관리 결합 위젯 회귀 |
| 130 | ✅ | `decorationIntensity`가 카드 깊이, 브랜드 그라데이션·그림자·장식량을 최소·균형·생동감 3단계로 조절한다. | `theme_expansion_test.dart`의 0/3/5 elevation 및 그림자 회귀 |
| 131 | ✅ | `DataHealthReportBuilder`, `DataHealthScreen`, `/settings/data-health` 경로가 SQLite·로컬 폴더·Drive·대기열 상태와 재시도를 설명한다. | `data_health_report_test.dart`의 4개 섹션 상태 회귀 |
| 132 | ✅ | 정상 SHA 검증을 통과한 체크포인트만 `lastBackup` 후보로 선택하고 시각·크기·항목 수·검증 상태를 건강 화면에 표시한다. | 더 최신인 손상 체크포인트를 배제하는 `data_health_report_test.dart` 회귀 |
| 133 | ✅ | 가져오기·일괄 삭제·모든 백업 복원 경로가 본 작업 전에 `RecoveryCheckpointService.create`를 호출하고 실패 시 작업을 중단한다. | `recovery_checkpoint_service_test.dart`의 원자 생성·검증·변조 차단, 기존 가져오기 검토 회귀 |
| 134 | ✅ | 저장 공간 관리 화면이 체크포인트 원인·시각·크기·항목 수·SHA 상태를 보이고 검증된 항목만 복원하거나 30일 이후 명시적으로 삭제한다. | `storage_maintenance_dialog_test.dart`의 메타데이터 표시·복원·명시적 삭제 회귀 |
| 135 | ✅ | `previewBackupRestore`가 현재/백업을 비교해 범주별 추가·변경·보존 건수를 `BackupRestorePreview`로 계산한다. | `backup_restore_test.dart`의 콘텐츠 추가량·미선택 세션 변화 0 검증 |
| 136 | ✅ | `BackupRestoreSelection`과 복원 대화상자가 콘텐츠·진도·세션·설정을 독립 선택하고 선택 결과만 병합한다. | 콘텐츠 전용 복원 시 언어 설정·세션 보존 회귀 |
| 137 | ✅ | `SettingsTransferCodec`과 설정 화면이 학습 콘텐츠를 포함하지 않는 앱/기기 설정 전용 내보내기·가져오기를 제공한다. | `settings_transfer_bundle_test.dart`의 왕복·콘텐츠 키 부재·백업형 파일 거부 |
| 138 | ✅ | `SyncPolicy.offlineLock`을 기기 전용으로 보존하고 연결·복원·수동/자동 동기화·연결 해제·계정 바인딩 삭제의 모든 Drive 진입점을 차단한다. | 잠금 중 connect/push/disconnect 호출 0회, 명시 해제 후 connect 1회 회귀 |
| 139 | ✅ | 건강 화면이 대기 스냅샷을 프로필·설정·진도·콘텐츠·삭제·세션·활성 학습 섹션으로 나눠 표시하고 각 행에 재시도 동작을 제공한다. | 7개 섹션과 진도 2건 집계, 잠금 중 재시도 비활성 회귀 |
| 140 | ✅ | 체크포인트 메타데이터에 SHA-256·바이트 크기·항목 수를 영속화하고 건강 화면에서 검증 영수증을 복사한다. | 원자 쓰기 후 SHA/크기/항목 검증, 변조 거부, 영수증 텍스트 회귀 |

## 감사 중 보완한 실제 공백

1. 목표 125: 저장·덮어쓰기·삭제만 있던 프로필 관리에 이름 변경·복제·정렬을 추가했다.
2. 목표 126: Noto Sans와 시스템 기본만 있던 글꼴 선택에 플랫폼 세리프·고정폭을 추가했다.
3. 목표 132: 해시는 있으나 검증에 실패한 최신 체크포인트가 마지막 정상 백업으로 선택되지 않도록 제한했다.
4. 목표 134: 복구 체크포인트 목록에 생성/수정 시각을 명시하고 복원 동작을 회귀 테스트로 고정했다.

## 실행한 검증

정적 분석:

```text
flutter analyze <관련 모델·테마·개인화·건강·복구·백업·동기화 11개 파일>
No issues found
```

집중 회귀:

```text
flutter test \
  test/domain/theme_expansion_preferences_test.dart \
  test/theme/theme_expansion_test.dart \
  test/widget/theme_expansion_personalization_test.dart \
  test/services/data_health_report_test.dart \
  test/services/recovery_checkpoint_service_test.dart \
  test/services/recovery_backup_catalog_test.dart \
  test/backup/settings_transfer_bundle_test.dart \
  test/backup/backup_restore_test.dart \
  test/state/sync_center_state_test.dart \
  test/sync/sync_policy_test.dart \
  test/widget/backup_data_card_test.dart \
  test/widget/pending_sync_status_test.dart \
  test/widget/storage_maintenance_dialog_test.dart
38 tests passed
```

시각 골든·전체 제품 빌드는 이 독립 감사 범위에서 실행하지 않았으며 최종 통합 검증 단계가 담당한다.
