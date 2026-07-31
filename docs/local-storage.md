# 로컬 저장과 저장 대상 전환

## 변하지 않는 원칙

- 앱 전용 Drift SQLite가 유일한 실시간 작업 원본이다.
- 사용자 지정 로컬 폴더와 Google Drive는 SQLite의 검증된 사본을 보관하는
  대상이며, 실행 중인 SQLite 파일 자체를 외장 폴더나 Drive에서 열지 않는다.
- 로컬 폴더 위치와 Android 문서 트리 권한은 기기별 설정이다. 이 값은 Drive
  snapshot에 넣지 않으므로 다른 기기에서는 저장 위치를 별도로 선택한다.
- 로컬 폴더나 Drive에 쓸 수 없어도 학습 기록은 SQLite에 먼저 남는다. 정상
  로컬 데이터를 손상되거나 지원하지 않는 사본으로 자동 교체하지 않는다.

사용자가 Google과 로컬 폴더를 모두 설정하지 않은 상태에서도 앱 내부 SQLite에는
계속 저장된다. 다만 외부 복구 사본이 없으므로 홈과 설정에서 로컬 폴더 선택을
계속 안내한다.

## 활성 저장 대상

| 상태 | 활성 보관 대상 | 동작 |
| --- | --- | --- |
| Google 미연결, 로컬 폴더 미설정 | 앱 전용 SQLite만 | 학습은 가능하나 로컬 폴더 선택을 안내한다. |
| Google 미연결, 로컬 폴더 설정 | 사용자 지정 `Sprache` 폴더 | 변경을 debounce한 뒤 자동 미러하고 `지금 저장`도 제공한다. |
| Google 연결 성공 | Google Drive | pull → validate → merge → push를 사용하며 로컬 폴더 설정은 fallback으로 유지한다. |
| Google 연결 상태에서 일시 오류 | Google Drive 대기열 | 로컬 폴더로 자동 failover하지 않고 백오프 또는 재연결을 기다린다. |
| 사용자가 Google 연결 해제 | 설정된 로컬 폴더 | 이 기기의 인증만 지운 뒤 로컬 자동 미러를 다시 시작한다. |

일시적인 401·403·429·5xx, 네트워크 단절, Drive 용량 부족은 “연결 해제”가
아니다. 같은 변경을 Drive와 로컬 폴더에 서로 다른 시점으로 동시에 쓰면 나중에
어느 사본이 최신인지 불명확해지므로 자동 failover를 금지한다.

Google 연결 해제는 현재 기기에만 적용한다. OS 보안 저장소의 이 기기 인증을
정리하고 런타임 Drive 클라이언트를 닫지만, 아래 항목은 삭제하지 않는다.

- Railway의 계정별 Drive 폴더 바인딩
- Google Drive의 `WordStudyData` 폴더와 그 안의 파일
- 사용자가 선택한 로컬 `Sprache` 폴더와 그 안의 파일
- 앱 전용 SQLite와 아직 전송하지 못한 업로드 대기 작업

따라서 다른 기기는 같은 Drive 바인딩을 계속 사용할 수 있고, 이 기기도 나중에
같은 계정으로 재연결할 수 있다.

사용자가 설정의 `계정–Drive 연결 기록 삭제`를 별도로 확인하면 이 기기의
Google 인증과 Railway의 HMAC 계정–폴더 매핑을 함께 삭제한다. 이 동작도 Drive
폴더, 사용자 지정 로컬 폴더와 앱 DB 파일은 자동 삭제하지 않는다.

## 플랫폼별 폴더 선택

### Windows

사용자가 파일시스템 폴더를 선택한다. 선택한 폴더 이름이 이미 `Sprache`이면
그 폴더를 사용하고, 아니면 바로 아래에 `Sprache`를 만든다. 쓰기 전에는 작은
검증 파일을 기록하고 다시 읽어 실제 읽기·쓰기 가능 여부를 확인한다.

### Android

네이티브 `ACTION_OPEN_DOCUMENT_TREE`로 폴더를 선택하고 Storage Access
Framework의 읽기·쓰기 지속 권한을 보관한다. 앱 재시작 뒤에도 문서 트리 URI로
같은 폴더를 다시 검증한다. 권한이 철회됐거나 저장소 제공자가 사라지면 SQLite는
그대로 두고 폴더 재선택을 안내한다. 폴더를 바꾸거나 연결을 해제하면 이전 문서
트리 권한은 best effort로 반환한다.

## 로컬 `Sprache` 폴더 형식

```text
Sprache/
├─ manifest.json
├─ manifest.previous.json
├─ content/
│  └─ custom-items-<generation>.json
├─ state/
│  ├─ meta-<generation>.json
│  ├─ profile-<generation>.json
│  ├─ settings-<generation>.json
│  ├─ progress-<generation>.json
│  └─ sessions-<generation>.json
├─ backups/
│  └─ archive-<generation>.json
```

한 번의 자동 저장은 다음 순서로 커밋한다.

1. SQLite 상태에서 `segmented-v1` 여섯 섹션과 전체 복원용 JSON archive를 만든다.
2. 각 새 generation 파일을 기록하고 바이트 길이와 SHA-256을 다시 확인한다.
3. 논리 경로, 실제 상대 경로, 길이, SHA-256을 담은 새 manifest를 임시 파일로 쓴다.
4. 기존 `manifest.json`을 `manifest.previous.json`으로 회전한다.
5. 검증한 새 manifest를 마지막에 `manifest.json`으로 교체한다.

읽을 때는 현재 manifest와 해당 archive의 길이·SHA-256을 먼저 검증하고, 읽을
수 없으면 이전 manifest가 가리키는 검증된 archive를 fallback으로 시도한다.
정리할 때도 현재·이전 manifest가 참조하는 generation을 보호한다. 전체 archive는
현재 백업 계약과 같이 10MB 제한을 적용한다.

## 기존 폴더 선택과 복원

선택한 폴더에 검증 가능한 Sprache archive가 있으면 즉시 덮어쓰지 않고 다음
선택을 표시한다.

- `나중에`: 결정을 내릴 때까지 폴더에 새 generation을 쓰지 않는다.
- `현재 데이터 사용`: 현재 SQLite 상태로 새 generation을 만든다.
- `기존 저장본 병합`: archive 계약과 각 필드를 검증한 뒤 현재 SQLite 데이터와
  병합한다. 콘텐츠 ID·수정 시각·tombstone, 진도 시각, XP 원장 등 Drive와 같은
  충돌 규칙을 사용하고, 병합 성공 뒤 새 로컬 generation을 저장한다.

사용자는 설정에서 선택한 폴더의 최신 검증 백업을 다시 병합할 수 있다. 복원
검증이나 병합이 실패하면 현재 SQLite는 유지한다. `로컬 폴더 연결 해제`는 앱의
위치 설정과 Android 지속 권한만 정리하며 폴더의 파일을 삭제하지 않는다.

## 가져오기 파일 처리

Excel·CSV·JSON·JSONL은 선택한 기기 메모리에서 검증하고 사용자가 `반영`한
항목만 SQLite transaction으로 저장한다. 로컬 미러에는 원본 업로드 파일을
별도로 만들지 않고, 정돈된 항목이 포함된 다음 검증 snapshot을 저장한다.
Drive 장애가 발생해도 원본 바이트가 아니라 정돈된 snapshot 변경만 재시도한다.

## 보안 주의

- 사용자 지정 로컬 폴더의 JSON은 별도 암호화 파일이 아니다.
  공용 PC의 공유 폴더, 다른 앱이 읽을 수 있는 공개 폴더, 자동 공유되는 회사
  네트워크 폴더는 피하고 사용자만 접근하는 위치를 선택한다.
- 폴더를 다른 사람에게 복사하면 단어·문장·진도·학습 기록이 함께 전달될 수 있다.
- OAuth access/refresh token과 Client Secret은 로컬 미러, Drive dataset,
  가져오기 staging, Railway PostgreSQL에 넣지 않는다. 클라이언트 토큰은 OS
  보안 저장소에만 둔다.
- Google Drive는 앱이 만들거나 사용자가 Picker로 선택해 권한을 준 파일에
  접근하는 `drive.file` 범위만 요청한다.
