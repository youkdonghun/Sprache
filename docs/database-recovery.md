# 로컬 데이터베이스 복구

Sprache는 정상 학습 화면을 만들기 전에 `sprache.sqlite`를 검사한다. DB를
열거나 마이그레이션할 수 없을 때 새 DB로 덮어쓰지 않고 읽기 전용 복구
화면으로 전환한다.

## 시작 순서

1. 운영체제 앱 문서 폴더에서 SQLite 파일 위치를 확인한다.
2. 기존 파일이 있으면 SQLite 3 헤더와 `user_version`을 직접 읽는다.
3. 앱보다 높은 스키마는 열지 않고 즉시 복구 모드로 전환한다.
4. 낮은 스키마는 DB, `-wal`, `-shm` 파일을 먼저 별도 복구 폴더에 복사한다.
5. 안전 사본 생성에 성공한 경우에만 Drift 마이그레이션을 시작한다.
6. 마이그레이션 또는 최초 쿼리가 실패하면 연결을 닫고 일반 앱의 쓰기 기능을 잠근다.
7. 성공한 경우에만 Riverpod·라우터·일반 학습 화면을 만든다.

복구 모드에서는 초기화, 삭제, 새 DB 생성 버튼을 제공하지 않는다. 사용자는
진단 복사, 안전 사본 ZIP 저장, DB 다시 열기만 실행할 수 있다.

## 복구 패키지

`Sprache-database-recovery-<UTC>.zip`은 다음을 담는다.

- 보존된 `sprache.sqlite`
- 존재하는 경우 `sprache.sqlite-wal`, `sprache.sqlite-shm`
- 파일명·크기·SHA-256·스키마·오류 코드가 있는 `recovery-manifest.json`

진단 복사 문자열에는 DB 원문과 로컬 절대 경로를 넣지 않는다. 복구 ZIP에는
개인 학습 데이터가 포함되므로 사용자 본인이 신뢰하는 위치에만 저장해야 한다.

앱 내부 자동 사본은 원본 DB 옆 `sprache-recovery/<UTC>-<reason>` 폴더에
만든다. 앱은 이 폴더를 자동 삭제하지 않는다. 설정의 저장 공간 관리에서
30일 이상 지난 사본만 사용자가 선택할 수 있고, 영구 삭제 확인 뒤 크기와
수정 시각을 다시 검사해 조회 후 바뀐 사본은 삭제하지 않는다. 상세 규칙은
[저장 공간 보존과 사용자 정리](storage-retention.md)를 따른다.

## 오류 코드

| 코드 | 의미 | 권장 조치 |
| --- | --- | --- |
| `database_newer_schema` | 더 최신 Sprache가 만든 DB | 앱 업데이트 후 다시 열기 |
| `database_invalid_header` | SQLite 헤더가 아니거나 파일이 짧음 | 안전 사본 저장 후 지원 요청 |
| `database_migration_backup_failed` | 마이그레이션 전 사본 생성 실패 | 저장 공간·폴더 권한 확인 |
| `database_migration_failed` | 사본 생성 후 migration 실패 | ZIP 저장 후 앱 업데이트·지원 요청 |
| `database_open_failed` | 현재 스키마 DB의 열기·검사 실패 | ZIP 저장 후 디스크·권한 확인 |
| `database_location_unavailable` | 앱 문서 폴더 확인 실패 | OS 저장 권한과 사용자 프로필 확인 |

## 검증 체크리스트

- 없는 DB는 schema 2로 정상 생성된다.
- 미래 schema DB는 open callback 자체가 호출되지 않고 원본 hash가 유지된다.
- 잘못된 헤더는 SQLite로 열지 않는다.
- migration 실패 전에 복사한 DB의 SHA-256이 원본과 일치한다.
- 복구 ZIP manifest에 로컬 절대 경로가 포함되지 않는다.
- 모바일과 Windows 복구 화면에 초기화·삭제 동작이 없다.
- 일반 앱은 부트스트랩 성공 후에만 생성된다.
- 복구 사본은 자동 삭제되지 않으며 30일 이상 지난 직접 선택 항목만 정리된다.
- 조회 후 크기나 수정 시각이 달라진 사본은 삭제되지 않는다.
