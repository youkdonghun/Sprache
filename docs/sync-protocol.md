# 동기화 프로토콜

## Drive 구조

```text
WordStudyData/
├─ manifest.json
├─ content/
├─ state/
│  └─ snapshot.json
├─ imports/
└─ backups/
```

`snapshot.json`은 프로필, 항목별 진도, 사용자 가져오기 콘텐츠를 한 트랜잭션 단위로 저장한다. `manifest.json`은 스키마·데이터셋 버전, 앱 루트 Folder ID, snapshot 파일 ID, revision, SHA-256, 수정 시각을 기록한다.

## Pull

1. 앱 루트에서 `manifest.json`을 찾고 스키마와 앱 루트 Folder ID를 검증한다.
2. `files.state/snapshot.json.fileId`로 정확한 원격 파일을 읽는다. 표시 경로나 같은 이름의 다른 파일은 사용하지 않는다.
3. Drive metadata의 revision과 manifest revision을 비교한다.
4. 다운로드 원본 바이트의 SHA-256과 manifest checksum을 비교한 뒤에만 JSON을 해석한다.
5. 지원하는 snapshot `schemaVersion`과 전체 필드 형식을 검증한다.
6. 항목별 최근 학습 시각으로 진도를 병합한다.
7. XP·연속 학습일은 큰 값, 배지는 합집합을 사용한다.
8. 사용자 콘텐츠는 ID·`updatedAt`·삭제 tombstone으로 병합한다.
9. 제외 표현·즐겨찾기·언어별 미션 완료 키는 각각 합집합으로 병합한다.
10. 맞춤 세션 설정은 `updatedAt`이 더 최신인 값을 선택하고, 같은 시각에는 JSON 서명 순서로 결정적으로 선택한다.
11. 정상인 경우에만 SQLite에 저장하고 병합 snapshot을 다시 올린다.

## Push와 충돌

- 연결·수동 동기화·앱 생명주기 전환 시 pull → validate → merge → push 순서로 실행한다.
- pull한 snapshot의 `fileId|revision|SHA-256` 지문과 push 직전 manifest 지문이 다르면 업로드하지 않고 최신 데이터를 다시 병합한다.
- 기존 snapshot의 Drive revision이 manifest와 다르면 업로드 전에 중단한다.
- 항목 충돌 병합기는 `updatedAt`, `deviceId`, 삭제 tombstone 규칙을 제공한다.
- 학습 응답은 항상 SQLite에 먼저 저장하고 최신 전체 snapshot을 `pending_syncs` 한 건으로 합치므로 네트워크 실패가 학습을 막지 않는다.
- 대기 작업은 operation ID, payload, 시도 횟수, 다음 시도 시각, 생성 시각을 저장해 앱 재시작 후에도 남는다.
- 네트워크 실패는 5초부터 최대 5분까지 백오프로 재시도한다. 수동 동기화는 대기 시각 전에도 즉시 실행할 수 있다.
- 이전 업로드가 끝나는 동안 새 snapshot이 대기열에 들어오면 이전 operation ID만 완료 처리해 새 변경을 보존한다.
- 지원 버전보다 새 원격 스키마는 덮어쓰지 않고 업데이트 안내를 표시한다.
- 원격 맞춤 세션의 문제 방식·덱·학습 단계·단원·비율·문제 수·태그·레벨·수정 시각을 경로별로 검증한다.
- SHA·revision·JSON 무결성 오류는 자동 반복하지 않고 설정 화면에 복구 필요 상태를 표시한다.
