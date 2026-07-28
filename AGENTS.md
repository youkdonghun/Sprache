# Sprache 개발 규칙

## 제품 원칙

- Sprache는 한국어 사용자가 영어, 일본어, 독일어, 프랑스어, 스페인어, 중국어를 학습하는 Local-First 앱이다.
- 학습 코스와 복습 큐는 언어별로 분리하고 XP, 레벨, 연속 학습일, 배지는 계정 단위로 합산한다.
- 초기 완성 언어는 영어와 일본어다. 이후 독일어, 프랑스어·스페인어, 중국어 간체 순으로 확장한다.
- Android는 게임형 학습 UI를 사용하고 Windows는 크기 조절이 가능한 차분한 업무 도구형 UI를 사용한다.
- Google 로그인 전에도 샘플 학습을 체험할 수 있다. 영구 저장과 기기 간 동기화를 활성화할 때 Google 계정과 Drive를 연결한다.
- 사용자 학습 콘텐츠와 상세 진도는 Railway PostgreSQL에 저장하지 않는다.

## 저장소 구조

- `apps/client`: Android와 Windows용 Flutter 클라이언트
- `services/api`: Fastify, Prisma, PostgreSQL 기반 계정-Drive 연결 API
- `packages/contracts`: OpenAPI 계약
- `docs`: 아키텍처, 데이터 모델, 동기화, 보안 및 설정 문서
- `sample-data`: 라이선스와 출처가 기록된 검증용 다국어 콘텐츠

## 코드 규칙

- Dart 비즈니스 로직은 UI와 분리하고 순수 함수 또는 주입 가능한 서비스로 작성한다.
- 상태 관리는 Riverpod, 라우팅은 go_router, 로컬 영속성은 Drift를 사용한다.
- TypeScript는 strict 모드를 유지하고 요청과 환경변수를 런타임 검증한다.
- 모든 언어는 BCP 47 태그를 사용한다: `ko`, `en`, `ja`, `de`, `fr`, `es`, `zh-Hans`.
- 문장 배열 문제의 토큰은 런타임 자동 분절 대신 콘텐츠에 명시적으로 저장한다.
- 일본어 읽기는 `kana`, `romaji`, 중국어 읽기는 `pinyin` 스킴으로 저장한다.
- 정답 정규화는 Unicode NFKC, 앞뒤 공백 제거, 연속 공백 축소를 공통 적용하고 언어별 규칙을 별도 프로필로 적용한다.

## 보안 규칙

- 비밀값과 OAuth 토큰을 코드, 저장소, 로그, Railway DB에 기록하지 않는다.
- 클라이언트 토큰은 OS 보안 저장소에만 저장한다.
- `/v1/me/*` API는 검증된 Google ID Token과 HMAC 처리된 `account_key`를 사용한다.
- Drive 파일과 폴더는 표시 경로가 아니라 ID로 참조한다.
- 손상되거나 지원하지 않는 원격 데이터로 정상 로컬 데이터를 덮어쓰거나 삭제하지 않는다.
- 삭제 동기화에는 tombstone을 사용한다.

## 명령

- 전체 검사: `npm test`
- API 개발: `npm run dev:api`
- API 테스트: `npm run test:api`
- Flutter 실행: `npm run run:client`
- Flutter 테스트: `npm run test:client`
- Windows 빌드: `npm run build:windows`
- Android APK 빌드: `npm run build:android`

## 생성 파일

- Drift, Riverpod 등 생성 파일은 원본 선언을 수정한 뒤 생성 명령으로 갱신한다.
- 생성 파일을 직접 편집하지 않는다.
- 각 구현 묶음이 끝날 때 정적 분석, 테스트, 가능한 플랫폼 빌드를 실행한다.

