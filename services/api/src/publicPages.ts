const pageStyles = `
  :root {
    color-scheme: light;
    --ink: #172019;
    --muted: #526057;
    --line: #dce6de;
    --paper: #f7faf7;
    --panel: #ffffff;
    --brand: #2f7d41;
    --soft: #e8f5ea;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    color: var(--ink);
    background: var(--paper);
    font: 16px/1.7 system-ui, -apple-system, "Segoe UI", "Noto Sans KR", sans-serif;
  }
  main { width: min(880px, calc(100% - 32px)); margin: 0 auto; padding: 48px 0 72px; }
  header, section {
    padding: 28px;
    border: 1px solid var(--line);
    border-radius: 20px;
    background: var(--panel);
  }
  section { margin-top: 18px; }
  h1 { margin: 0 0 10px; font-size: clamp(2rem, 7vw, 3.8rem); line-height: 1.1; }
  h2 { margin: 0 0 10px; font-size: 1.35rem; }
  h3 { margin: 18px 0 6px; font-size: 1.05rem; }
  p { margin: 8px 0 0; color: var(--muted); }
  ul { margin: 10px 0 0; padding-left: 22px; }
  nav, footer { display: flex; flex-wrap: wrap; gap: 16px; margin: 0 0 20px; }
  footer { margin: 28px 0 0; padding: 18px 4px 0; border-top: 1px solid var(--line); }
  a { color: #226d35; font-weight: 700; }
  code { padding: 2px 5px; border-radius: 5px; background: #edf3ee; }
  .notice { margin-top: 18px; padding: 16px; border-radius: 14px; background: var(--soft); }
  .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; margin-top: 18px; }
  .card { padding: 18px; border: 1px solid var(--line); border-radius: 14px; }
  @media (max-width: 640px) {
    main { padding: 24px 0 48px; }
    header, section { padding: 20px; border-radius: 16px; }
    .grid { grid-template-columns: 1fr; }
  }
`;

function page(title: string, body: string) {
  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${title}">
  <title>${title}</title>
  <style>${pageStyles}</style>
</head>
<body>
  <main>
    <nav aria-label="Sprache 공개 문서">
      <a href="/">Sprache 소개</a>
      <a href="/privacy">개인정보처리방침</a>
      <a href="/terms">서비스 이용약관</a>
      <a href="https://github.com/youkdonghun/Sprache">프로젝트</a>
    </nav>
    ${body}
    <footer>
      <span>Sprache</span>
      <a href="/privacy">개인정보처리방침</a>
      <a href="/terms">서비스 이용약관</a>
      <a href="https://github.com/youkdonghun/Sprache/issues">문의하기</a>
    </footer>
  </main>
</body>
</html>`;
}

export const appHomepageHtml = page(
  "Sprache — 나만의 반복 학습 작업공간",
  `<header>
    <h1>Sprache</h1>
    <p>
      Android와 Windows에서 단어·뜻·예문을 직접 만들고, Excel로 가져오고,
      원하는 그룹과 일정으로 암기·퀴즈·문장·듣기·발음을 반복하는
      Local-First 학습 작업공간입니다.
    </p>
    <div class="notice">
      Google 연결은 선택 사항입니다. 로그인하지 않아도 로컬 학습을 사용할 수 있습니다.
    </div>
  </header>
  <section>
    <h2>주요 기능</h2>
    <div class="grid">
      <div class="card"><strong>여섯 언어</strong><p>영어, 일본어, 독일어, 프랑스어, 스페인어, 중국어 간체를 지원합니다.</p></div>
      <div class="card"><strong>모든 암기 주제</strong><p>야구 용어, 아이돌 팬덤, 시험 개념처럼 원하는 주제를 만들 수 있습니다.</p></div>
      <div class="card"><strong>내 자료 관리</strong><p>단어, 여러 뜻, 예문, 읽기, 태그, 그룹을 앱 또는 Excel에서 관리합니다.</p></div>
      <div class="card"><strong>반복 학습</strong><p>플래시카드, 뜻 선택, 직접 쓰기, 빈칸, 문장 배열, 듣기와 발음을 지원합니다.</p></div>
    </div>
  </section>
  <section>
    <h2>Google 사용자 데이터 사용 목적</h2>
    <p>
      Google 계정을 연결하면 기본 계정 정보로 사용자를 확인하고,
      <code>drive.file</code> 권한으로 Sprache가 만든 파일과 사용자가 선택한
      Drive 폴더에 학습 데이터를 저장하여 Android와 Windows에서 이어서 학습합니다.
    </p>
    <ul>
      <li>사용자가 선택하지 않은 다른 Drive 문서를 탐색하거나 읽지 않습니다.</li>
      <li>학습 내용과 상세 진도를 Railway 데이터베이스에 저장하지 않습니다.</li>
      <li>Google 사용자 데이터를 광고, 판매, 프로파일링 또는 AI 학습에 사용하지 않습니다.</li>
      <li>연결을 해제해도 기기의 로컬 학습 자료는 유지됩니다.</li>
    </ul>
    <p><a href="/privacy">Google 데이터 처리와 삭제 방법 자세히 보기</a></p>
  </section>`,
);

export const privacyPolicyHtml = page(
  "Sprache 개인정보처리방침",
  `<header>
    <h1>개인정보처리방침</h1>
    <p>시행일: 2026년 7월 30일 · Sprache Android 및 Windows 앱</p>
    <div class="notice">
      Sprache는 로컬 우선 앱입니다. Google 연결은 선택 기능이며,
      Google 사용자 데이터는 기기 간 학습 동기화에만 사용합니다.
    </div>
  </header>
  <section>
    <h2>1. 처리하는 데이터</h2>
    <h3>Google 계정을 연결하지 않을 때</h3>
    <p>사용자가 만든 학습 항목, 그룹, 일정, 정답 기록과 설정은 사용자의 기기에 저장됩니다.</p>
    <h3>Google 계정을 연결할 때</h3>
    <ul>
      <li><code>openid</code>, <code>email</code>, <code>profile</code>: 계정 확인과 앱 내 연결 상태 표시에 사용</li>
      <li><code>drive.file</code>: Sprache가 만든 파일과 사용자가 선택한 Drive 폴더의 동기화에 사용</li>
      <li>Railway DB: HMAC-SHA256 처리된 계정 키, 선택한 Drive 폴더 ID·이름, 스키마 버전만 저장</li>
    </ul>
    <p>
      Railway DB에는 이메일, 프로필, 단어·예문, 정답, 상세 진도, OAuth 토큰,
      인증 코드 또는 음성 데이터를 저장하지 않습니다.
    </p>
  </section>
  <section>
    <h2>2. 이용 목적과 제한</h2>
    <ul>
      <li>동일 사용자의 Android·Windows 앱 연결</li>
      <li>사용자가 선택한 Google Drive 폴더에서 학습 자료와 진도 동기화</li>
      <li>동기화 오류 진단과 안전한 재시도</li>
    </ul>
    <p>
      Google 사용자 데이터를 광고, 판매, 신용 평가, 프로파일링, AI 모델 학습,
      또는 앱 기능과 무관한 목적으로 사용하거나 제3자에게 이전하지 않습니다.
      사용은
      <a href="https://developers.google.com/terms/api-services-user-data-policy">Google API Services User Data Policy</a>의
      Limited Use 요건을 따릅니다.
    </p>
  </section>
  <section>
    <h2>3. 저장 위치와 보존</h2>
    <ul>
      <li>학습 자료와 상세 진도: 기기 로컬 DB 및 사용자가 선택한 Google Drive</li>
      <li>OAuth 토큰: 운영체제 보안 저장소</li>
      <li>계정–폴더 연결: Railway PostgreSQL의 HMAC 계정 키와 폴더 연결 정보</li>
    </ul>
    <p>연결 매핑은 사용자가 앱에서 Google 연결을 해제할 때 삭제합니다.</p>
  </section>
  <section>
    <h2>4. 음성·파일 권한</h2>
    <p>
      마이크 권한은 발음 연습을 시작할 때만 요청합니다. 음성 인식 결과와 녹음은
      Sprache 서버에 업로드하거나 저장하지 않습니다. 파일 선택 권한은 사용자가
      Excel·CSV·JSON 자료를 가져오거나 백업을 저장할 때만 사용합니다.
    </p>
  </section>
  <section>
    <h2>5. 보안</h2>
    <ul>
      <li>OAuth 토큰은 OS 보안 저장소에 보관</li>
      <li>Authorization 헤더, 토큰, 인증 코드와 PKCE verifier를 서버 로그에서 제거</li>
      <li>Drive revision, SHA-256과 스키마 검증 후에만 원격 데이터 병합</li>
      <li>손상된 원격 자료로 정상 로컬 자료를 덮어쓰지 않음</li>
    </ul>
  </section>
  <section>
    <h2>6. 사용자의 선택과 삭제</h2>
    <ul>
      <li>Google 연결 없이 로컬 모드로 계속 사용할 수 있습니다.</li>
      <li>앱에서 연결을 해제하면 로컬 토큰과 Railway 계정–폴더 매핑을 삭제합니다.</li>
      <li><a href="https://myaccount.google.com/connections">Google 계정 연결 관리</a>에서 Sprache 권한을 철회할 수 있습니다.</li>
      <li>학습 항목은 앱에서 삭제할 수 있고, Drive의 Sprache 폴더는 사용자가 직접 삭제할 수 있습니다.</li>
    </ul>
  </section>
  <section>
    <h2>7. 문의와 정책 변경</h2>
    <p>
      개인정보 및 Google 데이터 처리 문의는
      <a href="https://github.com/youkdonghun/Sprache/issues">Sprache 프로젝트 문의 페이지</a>에서
      접수합니다. 처리 방식이 달라지면 시행일과 본문을 갱신합니다.
    </p>
  </section>`,
);

export const termsOfServiceHtml = page(
  "Sprache 서비스 이용약관",
  `<header>
    <h1>서비스 이용약관</h1>
    <p>시행일: 2026년 7월 30일</p>
  </header>
  <section>
    <h2>1. 서비스</h2>
    <p>
      Sprache는 사용자가 직접 학습 자료를 만들고 로컬 또는 선택한 Google Drive에서
      관리하도록 돕는 Android·Windows 학습 도구입니다.
    </p>
  </section>
  <section>
    <h2>2. 사용자 책임</h2>
    <p>
      사용자는 가져오거나 공유하는 학습 자료에 필요한 권리를 확보해야 하며,
      계정과 기기의 접근 권한을 안전하게 관리해야 합니다.
    </p>
  </section>
  <section>
    <h2>3. 데이터와 연결</h2>
    <p>
      Google 연결은 선택 사항입니다. 네트워크 또는 외부 서비스 장애가 발생해도
      정상 로컬 자료를 우선 보존하도록 설계되지만, 중요한 자료는 정기적으로
      내보내기·백업하는 것을 권장합니다.
    </p>
  </section>
  <section>
    <h2>4. 변경과 문의</h2>
    <p>
      기능 또는 데이터 처리 방식이 달라지면 약관과 개인정보처리방침을 갱신합니다.
      문의는 <a href="https://github.com/youkdonghun/Sprache/issues">프로젝트 문의 페이지</a>에서 접수합니다.
    </p>
  </section>`,
);
