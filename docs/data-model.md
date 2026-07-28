# 다국어 데이터 모델

## 언어 식별

모든 언어는 BCP 47 태그로 저장한다. 현재 지원 태그는 `ko`, `en`, `ja`, `de`, `fr`, `es`, `zh-Hans`다.

## LearningItem

```json
{
  "id": "uuid",
  "kind": "word",
  "baseLanguageTag": "ko",
  "learningLanguageTag": "ja",
  "text": "勉強",
  "translations": ["공부"],
  "acceptedAnswers": ["공부", "학습"],
  "readings": [
    {"scheme": "kana", "value": "べんきょう"},
    {"scheme": "romaji", "value": "benkyou"}
  ],
  "sentenceTokens": [],
  "examples": [],
  "partOfSpeech": "noun",
  "tags": ["기초"],
  "level": {"scheme": "JLPT", "value": "N5"},
  "exerciseCapabilities": ["recognition", "production", "listening"],
  "enabled": true,
  "selectedForStudy": true,
  "suspended": false,
  "priority": 0,
  "source": {
    "name": "Sprache starter catalog",
    "license": "project-internal",
    "sourceVersion": "2026.07",
    "contentVersion": 1
  },
  "updatedAt": "2026-01-01T00:00:00Z",
  "deletedAt": null
}
```

문장 배열 문제는 형태소 분석기에 의존하지 않고 `sentenceTokens`를 콘텐츠에 명시한다. 읽기 표기는 일반 정답으로 자동 허용하지 않으며 해당 문제의 `acceptedAnswers`에 명시된 경우에만 정답으로 처리한다.

단어의 `partOfSpeech`는 같은 철자·뜻의 다른 용법을 구분하는 안정적 ID와 중복 판정에 포함한다. 문장에는 품사를 저장하지 않는다. `sourceVersion`은 원본 교재·사전·데이터셋의 버전이고, `contentVersion`은 Sprache 안에서 항목이 수정될 때 증가하는 정수다. 기존 데이터에 출처가 없으면 `사용자 직접 입력 / private / 1 / 1`로 안전하게 복원한다.

## 진도 범위

- `Progress`는 `courseId + itemId`로 식별한다.
- 일일 목표와 큐는 코스별로 생성한다.
- `StudyEvent`는 전역 고유 `eventId`와 `deviceId`를 가진다.
- 삭제는 `deletedAt` tombstone으로 전파하고 보존 기간 이후 백업과 함께 정리한다.

## 개인 학습 설정

`StudyPreferences`에는 큐 제한과 읽기·TTS 설정 외에 다음 집합을 저장한다.

- `favoriteItemIds`: 사용자가 별표로 저장한 표현 ID
- `completedMissionIds`: `courseId:unitIndex` 형식의 언어별 실전 미션 완료 키
- `excludedItemIds`: 학습 큐에서 제외한 표현 ID

세 집합은 SQLite 설정 JSON에 먼저 저장되고 Drive snapshot의 `settings`에 포함된다. 사용자 표현을 삭제할 때 해당 ID는 즐겨찾기에서도 제거하지만, 기존 학습 기록은 통계 보존을 위해 남긴다.

마지막으로 저장한 맞춤 세션도 `StudyPreferences.sessionPlan`에 함께 저장한다.

```json
{
  "mode": "mixed",
  "deck": "unit",
  "unitIndex": 2,
  "difficulty": "weak",
  "tags": ["여행", "동사"],
  "levels": ["입문"],
  "includeWords": true,
  "includeSentences": true,
  "sentenceRatio": 0.4,
  "itemLimit": 15,
  "updatedAt": "2026-07-28T10:00:00Z"
}
```

`deck`은 `course`, `unit`, `favorites`, `personal` 중 하나다. 태그는 선택한 값 중 하나라도 포함하면 통과하고, 레벨은 선택 집합과 정확히 일치해야 한다. 큐는 복습 예정, 취약도, 신규 여부, 사용자 우선순위와 날짜 기반 안정 해시 순으로 결정한다. 동일한 로컬 날짜와 설정에서는 신규 표현 순서가 바뀌지 않는다.
