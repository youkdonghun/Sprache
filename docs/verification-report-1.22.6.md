# Sprache 1.22.6 검증 보고서

검증일: 2026-07-30

## 변경 범위

- 간편 Excel 템플릿의 저장 창 제안 이름을
  `Sprache 업로드 템플릿_YYYYMMDD.xlsx` 형식으로 변경했다.
- 날짜는 저장 동작을 실행한 기기의 로컬 날짜를 사용한다.
- 앱에 포함되는 원본 자산 `Sprache-easy-import-template.xlsx`는 변경하지 않았다.

## 검증

| 검사 | 결과 |
| --- | --- |
| 파일명 단위 테스트 | `Sprache 업로드 템플릿_20260730.xlsx` 확인 |
| `npm run analyze:client` | 이슈 0개 |
| `npm run test:client` | 361개 통과 |
| Android 실연동 release 빌드 | 성공 |
| Windows 실연동 release 빌드 | 성공 |
| `npm run verify:release` | 통과 |

릴리스 검증기는 앱 버전 `1.22.6+44`, Android ABI 3개, Windows ZIP
33개 항목, 체크섬 3개, 개인정보처리방침 URL 포함을 확인했다.

## 실행

- Windows `1.22.6+44` release 앱을 실행했다.
- 프로세스 ID 37756, 창 제목 `작업 보드`, `Responding=True`를 확인했다.

## 산출물

| 파일 | SHA-256 |
| --- | --- |
| `Sprache-Android-1.22.6-google-debug-signed.apk` | `DDFFE0375005BD111513C844EBD6E79E56103FA727D9EFE701235174FA770ADC` |
| `Sprache-Windows-1.22.6-google-x64.zip` | `0F55338E7B6FC2AC9B317714178321B89EAEE2C6F48FDB89701AA48BAE8F5809` |
| `Sprache-Windows-Setup-1.22.6-google-x64.exe` | `836C36A70D44CC1A434810301D842FCA79570C1BC4511AC8A952C06CDB473491` |

바탕화면 Android 설치 파일:
`C:\Users\youk\Desktop\Sprache-Android-1.22.6.apk`
