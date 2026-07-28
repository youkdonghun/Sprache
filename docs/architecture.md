# 아키텍처

## 시스템 경계

```text
Flutter Android / Windows
  ├─ UI + Riverpod
  ├─ 순수 Dart 학습 엔진
  ├─ Drift SQLite
  ├─ 플랫폼 TTS
  ├─ Google 인증 및 Drive 어댑터
  └─ OS 보안 저장소
          │
          ├── Google Drive: 콘텐츠·진도·설정의 원본
          │
          └── Fastify API on Railway
                  └── PostgreSQL: account_key ↔ Drive Folder ID
```

학습은 네트워크와 분리한다. 문제 응답은 SQLite에 즉시 기록하고 세션 종료, 앱 비활성화, 수동 요청, 로그아웃 전에 묶어서 동기화한다.

## 다국어 코스

- 기본 언어는 `ko`이며 코스는 `ko-en`, `ko-ja`, `ko-de`, `ko-fr`, `ko-es`, `ko-zh-Hans`다.
- 진도, 오늘의 큐, 일일 목표는 코스별이다.
- XP, 계정 레벨, 연속 학습일, 배지는 전체 코스에 걸쳐 합산한다.
- UI 문자열은 첫 버전에서 한국어만 제공하며 학습 콘텐츠 언어와 분리한다.

## 플랫폼 UI

- Android는 큰 터치 목표, 짧은 세션, 애니메이션 피드백, XP와 배지를 강조한다.
- Windows는 좌측 사이드바와 키보드 중심 조작을 제공한다.
- Windows 창은 최소 compact, 일반, 확장 레이아웃으로 전환되며 항상 크기 조절 가능하다.
- compact 모드는 작은 창에서도 오늘의 문제, 답안, 진행률만 남겨 업무 도구처럼 보이도록 한다.

