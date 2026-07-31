# 동기화 프로토콜

## Drive 구조

```text
WordStudyData/
├─ manifest.json
├─ state/
│  └─ snapshot.json
├─ backups/
└─ quarantine/
```

가져오기 파일 자체는 Drive에 저장하지 않는다. 행을 검증·정규화한 결과를 SQLite에
먼저 반영하고, 동기화 시 원격 snapshot을 pull한 다음 항목 ID·의미 동일성·수정
시각·tombstone 규칙으로 병합해 같은 `state/snapshot.json`을 갱신한다. 따라서
같은 키를 다시 가져와도 별도 Excel 파일을 만들지 않고 기존 논리 데이터셋에
추가·갱신된다. 파일명과 SHA-256은 로컬 가져오기 이력에만 남는다.

`distribution_key → subjectId + groupName` 규칙, 기본 주제 표시/숨김 상태,
기본 주제의 사용자 정의 이름·기호·설명은 snapshot의 `settings`에 포함한다. 각 규칙과
주제 표시 변경에는 변경 시각을 두고 기기 간 최신 값을 병합한다.

사용자가 입력하거나 안전하게 자동 보완한 `kana`·`romaji`·`pinyin`·한글 읽기는
학습 항목의 일부로 snapshot의 `customItems`에 동기화한다. 반면 설치된 TTS 엔진과
구체적인 음성 이름은 기기 로컬 정보라 snapshot에 넣지 않는다. 각 기기는 동기화된
항목의 언어 태그에서 `ttsLocale`을 결정하고, 해당 로케일의 오프라인 음성을 우선
선택하며 없으면 같은 언어 음성 또는 운영체제 기본 음성으로 대체한다.

`canonical-v1` 레이아웃은 프로필, 설정, 진도, 사용자 콘텐츠, 세션을 하나의
`state/snapshot.json`에 저장한다. `manifest.json`은 앱 루트 Folder ID와 이
canonical 파일의 ID, revision, SHA-256을 기록한다. push는 파일을 새로 만들지
않고 같은 ID를 갱신한다.

기존 schema v1 `state/snapshot.json`과 `segmented-v1` 여섯 섹션은 pull에서
계속 읽는다. 다음 정상 push가 성공하면 병합된 schema v2 snapshot을 canonical
파일에 쓰고 manifest를 마지막에 `canonical-v1`로 전환한다. 구버전 섹션은
자동 삭제하지 않으며 새 manifest에서는 참조하지 않는다.

### manifest와 snapshot 버전의 구분

- Drive `manifest.json`의 `schemaVersion: 1`과 `layout: canonical-v1`은 파일
  배치 방식의 버전이다. snapshot 내부 데이터 버전과 별개다.
- 앱이 새로 쓰는 snapshot은 `schemaVersion: 2`다. 기존 snapshot
  `schemaVersion: 1`도 계속 읽고 병합하며, 다음 정상 push에서만 v2로
  자연스럽게 승격한다.
- v2는 스마트 컬렉션, 가져오기 열 매핑 프리셋·영수증과 Undo 상태, 휴지통,
  콘텐츠 교정, 복수 그룹·시간 예산·진도 비기록·출제 방향·채점 강도·시험 일정이
  포함된 세션 계획을 계정 데이터로 보존한다.
- 가져오기 영수증에는 원본 파일의 저장 경로나 원본 바이트를 넣지 않는다.
  정돈된 학습 데이터와 병합 결과만 기존 canonical Drive 파일 ID에 upsert한다.
  따라서 같은 Excel을 다시 가져와도 가져오기마다 별도 데이터 파일을 만들지 않는다.
- 백업 archive 포맷은 `schemaVersion: 1`을 유지하고, 내부 snapshot 버전은
  `snapshotSchemaVersion`으로 따로 기록한다. 구버전 archive도 계속 복원할 수 있다.

## 저장·동기화 상태 센터

앱 셸은 모든 탭에서 같은 상태를 사용해 `로컬 저장`, `동기화 대기`,
`동기화 중`, `오류`, `동기화 완료`를 표시한다. 설정의 동기화 센터에서는
다음 기능을 제공한다.

- 자동, Wi-Fi 전용, 수동 정책. 수동 동기화 버튼은 어떤 정책에서도 항상 실행한다.
- 마지막 로컬·Drive 차이를 항목별로 비교하고 각 항목에 적용할 버전을 고른다.
- 최근 병합 직전 상태로 로컬 데이터를 복구한다.
- 성공·실패·정책상 건너뜀을 포함한 최근 동기화 이력을 기기 로컬에 영속 저장한다.
- 인증 토큰, Drive 파일·폴더 ID, 로컬 경로를 제외한 진단 JSON을 내보낸다.

동기화 정책, 네트워크 정책, 충돌 선택, 이력과 복구 지점은 기기별 로컬 설정이다.
학습 콘텐츠·진도·음성은 Railway API나 PostgreSQL에 저장하지 않는다. Railway는
기존과 같이 검증된 계정과 Drive 연결 정보만 보관하며, 음성 녹음은 Drive에도
올리지 않는다.

## SQLite·로컬 미러·Drive의 관계

앱 전용 SQLite가 유일한 작업 원본이다. 로컬 미러는 `segmented-v1`, Drive는
`canonical-v1`을 사용하며 실행 중인 SQLite 파일을 로컬 폴더나 Drive에서
직접 열지 않는다.

- Google 미연결: 선택한 Windows 파일시스템 또는 Android SAF 문서 트리의
  `Sprache` 폴더에 여섯 섹션과 전체 복원 archive를 자동 미러한다.
- Google 연결 성공: Drive가 활성 동기화 대상이 되고 로컬 폴더 ID·권한은
  현재 기기의 fallback 설정으로 남지만 새 로컬 generation은 쓰지 않는다.
- 일시적인 Drive 오류: 정돈된 snapshot을 `pending_syncs`에 유지하고 Drive를
  재시도한다. 원본 업로드 파일을 staging하거나 로컬 폴더로 자동 failover하지
  않는다.
- 명시적 Google 연결 해제: 현재 기기의 인증만 정리하고 설정된 로컬 미러를
  다시 활성화한다. Railway 바인딩, Drive 파일, 로컬 폴더 파일은 삭제하지 않는다.

로컬 미러도 SHA-256과 manifest-last 커밋을 사용한다. 섹션과 전체 archive를
새 generation 파일로 검증해 쓴 뒤 현재 manifest를 `manifest.previous.json`으로
회전하고 새 manifest를 마지막에 교체한다. 읽기는 현재 manifest를 우선하고,
파일 길이·SHA 검증에 실패하면 이전 manifest가 가리키는 archive를 시도한다.
자세한 폴더 형식과 복원 선택은
[로컬 저장과 저장 대상 전환](local-storage.md)에 기록한다.

## Pull

1. 앱 루트에서 `manifest.json`을 찾고 스키마와 앱 루트 Folder ID를 검증한다.
2. manifest가 `canonical-v1` 또는 기존 단일 형식이면
   `files.state/snapshot.json.fileId`를 읽는다. `segmented-v1`이면 마이그레이션
   입력으로 여섯 필수 경로를 읽는다. 표시 경로나 같은 이름의 다른 파일은 사용하지 않는다.
3. 각 Drive metadata의 revision과 manifest revision을 비교한다. revision이
   달라도 공유·권한 같은 metadata-only 변경일 수 있으므로 즉시 손상 판정하지 않는다.
4. 각 다운로드 원본 바이트의 SHA-256과 manifest checksum을 비교한 뒤에만
   JSON을 해석한다. revision만 달라지고 SHA-256이 같으면 정상으로 허용하며,
   둘 다 달라진 경우에만 격리한다.
5. canonical envelope의 내부 payload SHA-256도 검증한다. 외부 manifest와
   내부 checksum 중 하나라도 맞지 않으면 정상 로컬 데이터를 덮어쓰지 않는다.
6. segmented-v1이면 여섯 섹션을 기존 snapshot 계약으로 조립한 뒤
   `schemaVersion`과 전체 필드 형식을 검증한다.
   SHA·JSON·필드 검증에 실패하면 원본을 수정하지 않고 `quarantine/`에
   timestamp가 포함된 사본을 만든다.
7. 항목별 최근 학습 시각으로 진도를 병합한다.
8. 계정 XP는 설치별 `replicaId`의 증가 전용 카운터를 병합해 합산한다.
   같은 기기 카운터는 큰 값을 선택하며, 구버전의 단일 `totalXp`는
   `legacy` 카운터로 승계한다. 오늘 XP도 날짜·코스·기기별 카운터로 병합한다.
   연속 학습일은 큰 값, 배지는 합집합을 사용한다.
9. 사용자 콘텐츠는 먼저 ID·`updatedAt`·삭제 tombstone으로 병합한다. 같은
   주제·언어·종류·정규화 표현·품사의 살아 있는 항목은 ID가 달라도 하나로
   수렴시키고 뜻·허용 정답·읽기·그룹을 합친다. 사라지는 ID에는 tombstone을
   남기고 그 ID의 진도는 살아남은 ID로 옮긴다.
10. 제외 표현·즐겨찾기는 항목별 변경 시각으로 추가와 취소를 병합한다.
    구버전처럼 변경 시각이 없으면 안전한 합집합을 사용한다.
    언어별 미션 완료 키는 합집합으로 병합한다.
11. 맞춤 세션 설정은 `updatedAt`이 더 최신인 값을 선택하고, 같은 시각에는 JSON 서명 순서로 결정적으로 선택한다.
12. 최근 완료 세션은 `sessionId`로 합치고 더 늦은 종료 시각을 우선하며, 같은 시각에는 JSON 서명 순서로 결정적으로 선택한다.
13. 활성 주제와 주제별 일일 목표는 각 변경 시각이 최신인 값을 선택하고,
    구버전처럼 시각이 없거나 같으면 고정된 tie-breaker로 순서와 무관하게 결정한다.
14. 저장한 학습 일정 삭제는 일정 ID별 tombstone을 남기고, 일정의 `updatedAt`
    보다 삭제 시각이 같거나 늦으면 오래된 일정이 다시 생기지 않게 한다.
    각 일정의 `subjectId`도 함께 동기화해 언어·사용자 주제별로 격리하며,
    구버전의 빈 값은 snapshot의 활성 주제에 귀속한다.
15. 정상인 경우에만 SQLite에 저장하고 병합 dataset을 다시 올린다.

## Push와 충돌

- 연결·수동 동기화·앱 생명주기 전환 시 pull → validate → merge → push 순서로 실행한다.
- pull한 canonical snapshot의 `fileId|SHA-256` 지문과 push 직전
  manifest 지문이 다르면 업로드하지 않고 최신 데이터를 다시 병합한다.
- 병합된 전체 snapshot은 기존 canonical 파일 ID에 media PATCH로 갱신한다.
- 저장 직후 전체 바이트 SHA, 내부 payload SHA와 writer operation ID를 다시
  검증한 뒤 manifest를 커밋한다. manifest 커밋이 실패하면 직전 snapshot
  바이트를 같은 ID에 복구한다.
- segmented-v1 전환 중 snapshot 업로드가 실패하면 기존 segmented manifest를
  건드리지 않으므로 이전 데이터셋이 계속 유효하다.
- 사용자가 고른 Excel·CSV 원본은 Drive에 복제하지 않으며, 가져오기 횟수와
  관계없이 데이터 파일 ID는 하나로 유지한다.
- 기존 snapshot 또는 섹션의 Drive revision이 manifest와 다르면 실제 바이트의
  SHA-256을 다시 확인한다. 내용이 같으면 metadata-only 변경으로 계속하고,
  SHA까지 다르면 업로드 전에 충돌로 중단한다.
- 항목 충돌 병합기는 `updatedAt`, `deviceId`, 삭제 tombstone 규칙을 제공한다.
- 학습 응답은 항상 SQLite에 먼저 저장하고 최신 전체 snapshot을 `pending_syncs` 한 건으로 합치므로 네트워크 실패가 학습을 막지 않는다.
- 대기 작업은 operation ID, payload, 시도 횟수, 다음 시도 시각, 생성 시각을 저장해 앱 재시작 후에도 남는다.
- 네트워크 실패는 5초부터 최대 5분까지 백오프로 재시도한다. Drive가
  `Retry-After`를 반환하면 그 대기 시간보다 먼저 자동 재시도하지 않는다.
  수동 동기화는 대기 시각 전에도 즉시 실행할 수 있다.
- 이전 업로드가 끝나는 동안 새 snapshot이 대기열에 들어오면 이전 operation ID만 완료 처리해 새 변경을 보존한다.
- 지원 버전보다 새 원격 스키마는 덮어쓰지 않고 업데이트 안내를 표시한다.
- 원격 맞춤 세션의 문제 방식·덱·학습 단계·단원·비율·문제 수·태그·레벨·수정 시각을 경로별로 검증한다.
- 최근 완료 세션은 최대 20개만 동기화하고 코스 ID, 시각, 정답·오답 수,
  항목 ID와 오답 ID의 포함 관계를 적용 전에 검증한다.
- 기기별 XP 원장은 기기 ID 형식, 정수 범위와 최대 500개 제한을 적용 전에
  검증한다. 원장이 없는 구버전 snapshot도 계속 읽을 수 있다.
- 항목별 즐겨찾기·제외 변경 시각과 일정 삭제 tombstone도 개수·ID 길이·
  ISO 8601 형식을 적용 전에 검증한다.
- SHA 불일치, revision과 SHA의 동시 불일치, JSON·snapshot 필드 무결성 오류는
  자동 반복하지 않는다.
  설정 화면에 격리 사본 이름, 바이트 수·SHA 일부·최상위 구조만 포함한
  안전 미리보기와 복구 순서를 표시하며 학습 내용 원문은 진단에 넣지 않는다.

## Drive 오류 복구

- 401은 토큰 갱신 이후에도 실패한 인증 만료로 분류하고 Google 재연결을 안내한다.
- 403의 `appNotAuthorizedToFile`·권한 오류는 권한 철회로 분류한다.
- 403의 `rateLimitExceeded`·`userRateLimitExceeded`·`dailyLimitExceeded`와
  429는 API 제한으로 분류해 백오프한다.
- `storageQuotaExceeded`는 저장공간 문제로 분리해 공간 확보를 안내한다.
- 404는 선택한 폴더·파일이 삭제됐거나 접근할 수 없는 상태로 분류한다.
- 500·502·503·504는 일시적 서버 장애로 분류해 로컬 대기열을 유지한다.

분류 기준은 Google 공식
[Drive API 오류 해결 문서](https://developers.google.com/workspace/drive/api/guides/handle-errors)를 따른다.

## 이전 섹션 보존과 정리

- Drive 파일은 자동 삭제하지 않는다.
- 설정의 저장 공간 관리에서 현재 manifest가 참조하지 않고 수정 후 30일 이상 지난
  `state/`·`content/` JSON만 정리 후보로 표시한다.
- 삭제 확인 뒤 manifest를 다시 읽고 fingerprint와 참조 파일 ID를 재검증한다.
- 조회 후 manifest가 바뀌었거나 선택 파일이 다시 참조되면 아무 파일도 이동하지 않는다.
- 안전 조건을 통과한 선택 파일은 영구 삭제가 아니라 Google Drive 휴지통으로 이동한다.
- 상세 사용자 흐름과 로컬 복구 사본 정책은
  [저장 공간 보존과 사용자 정리](storage-retention.md)에 기록한다.

장기 오프라인 분기와 재연결 검증 범위는
[장기 오프라인 충돌 검증](offline-conflict-testing.md)에 기록한다.
