# Sprache 1.38.6

## 앱 업데이트 없이 추가하는 언어팩

- 자료실의 추가 메뉴에 `언어팩 받기`를 더했다. 현재 학습 언어를 먼저 보여 주고
  전체 또는 다른 언어로 좁혀 공개 팩을 고를 수 있다.
- 언어팩 목록과 JSON은 GitHub 공개 저장소에서 직접 받는다. 별도 서버, Railway,
  Cloudflare 또는 앱 재배포가 필요하지 않다.
- 받기 전에 HTTPS 경로, 20MB 제한, 정확한 파일 크기, SHA-256, 팩 ID·언어·버전·
  revision·라이선스·항목 수와 문장 토큰을 확인한다.
- 확인된 팩도 자동 저장하지 않는다. 기존 가져오기 검토 화면에서 신규·변경·동일
  자료를 비교하고 사용자가 반영한 항목만 SQLite에 원자적으로 저장한다.
- 동일 팩은 안정적인 `source_id`와 항목 ID로 설치됨·업데이트 상태를 구분한다.
  중복 병합, 초안 복구, 가져오기 되돌리기와 Drive snapshot 동기화는 기존 안전
  흐름을 그대로 사용한다.

## GitHub 등록 공간

- `language-packs/packs/`: 실제 공개 언어팩 JSON
- `language-packs/templates/`: 복사해서 작성할 예시
- `language-packs/schema/`: 팩과 카탈로그 JSON Schema
- `language-packs/catalog.json`: 앱이 읽는 자동 생성 목록
- `tool/build-language-pack-catalog.mjs`: 파일 검증과 카탈로그 생성기
- `.github/workflows/language-pack-catalog.yml`: 새 팩 push 시 카탈로그 자동 갱신

팩 원본은 사용자 Google Drive에 복제하지 않는다. 검토 후 반영된 학습 항목과
출처 메타데이터만 기존 사용자 자료로 동기화한다.

버전: `1.38.6+74`
