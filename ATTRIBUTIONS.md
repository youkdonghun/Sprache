# Sprache 콘텐츠 출처와 이용 조건

이 문서는 앱에 포함되거나 가져올 수 있는 학습 콘텐츠의 출처와 이용 조건을 추적한다. 앱 소스 코드의 라이선스와 학습 콘텐츠의 라이선스는 별도로 판단한다.

## Sprache starter catalog

| 항목 | 값 |
| --- | --- |
| 범위 | 영어·일본어·독일어·프랑스어·스페인어·중국어 단어 480개, 문장 600개(언어별 100개) |
| 출처 | Sprache 프로젝트를 위해 직접 작성한 입문 표현 |
| 외부 코퍼스 사용 | 없음 |
| `sourceVersion` | `2026.09` |
| `contentVersion` | `4` |
| 앱 내부 라이선스 식별값 | `project-internal` |

`project-internal`은 공개 재배포 권한을 부여하는 라이선스 이름이 아니다. 저장소의 최종 `LICENSE`와 콘텐츠 배포 정책을 확정하기 전까지 이 카탈로그를 별도 데이터셋으로 재배포하지 않는다.

2026.09 카탈로그에는 체크인·교통·결제·응급 상황·업무·언어 학습 표현에
일상·가정·취미·연락·건강 표현을 더해 언어별 문장을 100개로 확장했다.
모든 추가 문장은 프로젝트에서 직접 작성했으며 일본어 읽기·로마자,
중국어 병음, 문장 배열용 수동 토큰을 함께 검수한다.

## Tatoeba 한국어 연결 예문 팩

| 항목 | 값 |
| --- | --- |
| 범위 | 영어·일본어·독일어·프랑스어·스페인어·중국어 간체 문장 각 4개, 총 24개 |
| 원본 | https://tatoeba.org/ |
| 이용 조건 | 각 원문과 한국어 번역에 표시된 `CC BY 2.0 FR` |
| 라이선스 | https://creativecommons.org/licenses/by/2.0/fr/ |
| 확인일·`sourceVersion` | `2026-07-28`, `2026-07-29` |
| 포함 파일 | `apps/client/assets/content/tatoeba-korean-sentence-pack-2026-07-28.json`, `apps/client/assets/content/tatoeba-practical-sentence-pack-2026-07-29.json` |
| 가공 | BCP 47 코드 매핑, 학습 그룹·태그, 수동 문장 토큰, 일본어 읽기와 중국어 병음 추가 |

기초 팩과 출퇴근·학습 팩에는 Tatoeba API에서 원문과 직접 연결된 한국어 번역이 모두 승인 상태이고
각각 `CC BY 2.0 FR`로 표시된 쌍만 포함한다. 각 항목의 `source_id`,
`source_url`, `author`, `attribution`에 원문·번역 ID, 작성자, 라이선스
표시문을 보존한다. 사용자는 앱의 가져오기 검토 화면에서 원하는 항목만
선택해 저장할 수 있다. 2026-07-29 팩의 중국어 두 문장은 API의 `Hans`
스크립트 표기를 다시 확인했다.

온라인 원본 상태는 저장소 루트에서 `npm run check:tatoeba`로 다시 검사한다.
이 명령은 공식 API의 승인·비고아·직접 한국어 번역 조건으로 원문을 검색하고
팩의 텍스트, 번역, 작성자, 라이선스와 중국어 간체 스크립트를 대조한다.

## 야구 용어 샘플 주제

| 항목 | 값 |
| --- | --- |
| 범위 | 야구 통계·경기 규칙 8개 원본 행, 예문 독립 문장화를 포함하면 13개 학습 항목 |
| 참고 출처 | MLB Baseball Glossary |
| 원본 | https://www.mlb.com/baseball-basics |
| 사용 방식 | 공식 통계식과 규칙 사실을 확인한 뒤 한국어 설명과 예문을 새로 작성 |
| 앱 내부 이용 조건 식별값 | `reference-only; paraphrased fact` |
| 확인일·`sourceVersion` | `2026-07-28` |
| 포함 파일 | `apps/client/assets/content/baseball-starter-pack-2026-07-28.json` |

MLB 문장을 데이터셋처럼 복제하지 않는다. 각 항목은 사실·공식 규칙을 짧게
바꾸어 쓴 학습용 설명이며 원문 URL과 `MLB Glossary의 공식 설명을 한국어로
요약`이라는 표시를 함께 보존한다. 샘플 팩은 사용자가 가져오기 검토 화면에서
선택하기 전에는 자료함에 저장되지 않는다.

## 아이돌·팬덤 샘플 주제

| 항목 | 값 |
| --- | --- |
| 범위 | K-pop 팬덤 용어와 설명 8개 원본 행, 예문 독립 문장화를 포함하면 15개 학습 항목 |
| 참고 출처 | Korea.net K-pop Dictionary·K-pop Lingo·Encyclopedia of Hallyu 소개, 문화체육관광부 팬덤 기사 |
| 원본 | https://www.korea.net/NewsFocus/Culture/view?articleId=211012 |
| 문화체육관광부 원본 | https://www.mcst.go.kr/english/policy/kocis/newsView.jsp?pSeq=46 |
| 사용 방식 | 용어의 뜻을 확인한 뒤 한국어 설명과 예문을 새로 작성 |
| 확인일 | `2026-07-28` |
| 포함 파일 | `apps/client/assets/content/idol-fandom-starter-pack-2026-07-28.json` |

Korea.net 참고 항목에는 `reference-only; paraphrased fact`를, 문화체육관광부
참고 항목에는 원문에 표시된 공공누리 제1유형과 출처표시 문구를 기록한다.
각 항목은 원문 URL과 요약 출처를 보존하며 사용자가 검토한 뒤에만 저장한다.

## 사용자 콘텐츠

직접 입력하거나 Excel·CSV·JSON·JSONL로 가져온 콘텐츠의 기본 라이선스 값은 `private`다. Sprache는 사용자 콘텐츠에 새로운 라이선스를 부여하지 않는다. 외부 사전·교재·데이터셋을 사용했다면 편집 화면 또는 가져오기 파일에 실제 `source`, `license`, `source_version`, `source_id`, `source_url`, `author`, `attribution`을 기록해야 한다.

## 영어 TOSS·TOEIC 선택형 언어팩

| 항목 | 값 |
| --- | --- |
| 범위 | TOSS 기본 어휘·숙어 5,000개, TOEIC 기본 어휘·숙어 5,000개 |
| 빈도 목록 | NGSL-Spoken 1.2, NGSL 1.2, NGSL-GR, TOEIC Service List 1.2, Business Service List 1.2 |
| 목록 원본 | https://www.newgeneralservicelist.com/word-lists |
| 한국어 뜻 | TUFS, 한국어 위키낱말사전, Open English-Korean Dictionary 부분본, Sprache 교정 |
| 사전 원본 | https://kaikki.org/kowiktionary/영어/ · https://github.com/jhseo1211/open-english-korean-dict |
| 라이선스 | CC BY-SA 4.0(팩 전체), TUFS 부분은 CC BY 4.0 |
| 개정판 | `2026.09.2`, revision `2` |
| 포함 파일 | `language-packs/packs/sprache-en-toss-speaking-core-2026-09.json`, `language-packs/packs/sprache-en-toeic-service-core-2026-09.json` |

두 팩은 ETS 공식 문제나 공식 단어장이 아니다. TOSS 팩은 말하기 고빈도
단어 4,750개와 직접 정리한 회화·숙어 250개, TOEIC 팩은 시험·업무
고빈도 단어 4,750개와 실무 결합표현 250개로 구성한다. 기존 revision 1의
첫 721개·1,250개 ID는 그대로 보존해 재설치가 아닌 업데이트로 처리한다.
영어 철자를 한글 발음으로 추측한 값은 넣지 않고 기기의 영어 TTS를 사용한다.

## 추가 콘텐츠 등록 템플릿

새 외부 데이터셋을 포함하기 전 다음 정보를 이 문서에 추가한다.

```text
이름:
원본 URL:
저작자·제공자:
라이선스:
원본 버전:
Sprache 콘텐츠 버전:
가공 방법:
포함 파일:
검수자와 검수일:
```
