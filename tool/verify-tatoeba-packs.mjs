import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import process from "node:process";

const repositoryRoot = resolve(import.meta.dirname, "..");
const defaultPackPaths = [
  "apps/client/assets/content/tatoeba-korean-sentence-pack-2026-07-28.json",
  "apps/client/assets/content/tatoeba-practical-sentence-pack-2026-07-29.json",
];
const languageCodes = new Map([
  ["en", "eng"],
  ["ja", "jpn"],
  ["de", "deu"],
  ["fr", "fra"],
  ["es", "spa"],
  ["zh-Hans", "cmn"],
]);
const sourceIdPattern = /^(?<source>\d+) \/ ko (?<translation>\d+)$/;

const requestedPaths = process.argv.slice(2);
const packPaths = requestedPaths.length ? requestedPaths : defaultPackPaths;
const failures = [];
const rows = [];

for (const relativePath of packPaths) {
  const absolutePath = resolve(repositoryRoot, relativePath);
  const raw = await readFile(absolutePath, "utf8");
  const document = JSON.parse(raw);
  if (!Array.isArray(document.items)) {
    throw new TypeError(`${relativePath}: items 배열이 없습니다.`);
  }

  for (const item of document.items) {
    const sourceMatch = sourceIdPattern.exec(item.source_id ?? "");
    const language = languageCodes.get(item.language);
    if (!sourceMatch || !language) {
      failures.push(
        `${relativePath}:${item.id ?? "unknown"}: language 또는 source_id 형식 오류`,
      );
      continue;
    }

    const sourceId = Number(sourceMatch.groups.source);
    const translationId = Number(sourceMatch.groups.translation);
    const params = new URLSearchParams({
      q: item.term,
      lang: language,
      sort: "relevance",
      is_unapproved: "no",
      is_orphan: "no",
      "trans:lang": "kor",
      "trans:is_direct": "yes",
      "trans:is_unapproved": "no",
      "trans:is_orphan": "no",
    });
    const result = await fetchJson(
      `https://api.tatoeba.org/v1/sentences?${params}`,
    );
    const source = result.data?.find((candidate) => candidate.id === sourceId);
    const translation = source?.translations?.find(
      (candidate) => candidate.id === translationId,
    );
    const prefix = `${relativePath}:${item.id}`;

    check(source, `${prefix}: 승인된 원문 #${sourceId}을 찾지 못했습니다.`);
    if (!source) continue;
    check(
      translation,
      `${prefix}: 직접 연결된 한국어 번역 #${translationId}을 찾지 못했습니다.`,
    );
    if (!translation) continue;

    check(source.text === item.term, `${prefix}: 원문 텍스트가 바뀌었습니다.`);
    check(
      translation.text === item.meaning,
      `${prefix}: 한국어 번역 텍스트가 바뀌었습니다.`,
    );
    check(
      source.license === "CC BY 2.0 FR" &&
        translation.license === "CC BY 2.0 FR" &&
        item.license === "CC BY 2.0 FR",
      `${prefix}: CC BY 2.0 FR 라이선스가 일치하지 않습니다.`,
    );
    check(
      item.author === `${source.owner} / ${translation.owner}`,
      `${prefix}: 작성자 표시가 API와 다릅니다.`,
    );
    check(
      item.source_url ===
        `https://tatoeba.org/en/sentences/show/${sourceId}`,
      `${prefix}: source_url이 원문 ID와 다릅니다.`,
    );
    check(
      item.attribution?.includes(`#${sourceId} (${source.owner})`) &&
        item.attribution?.includes(
          `#${translationId} (${translation.owner})`,
        ) &&
        item.attribution?.includes("CC BY 2.0 FR"),
      `${prefix}: attribution에 ID·작성자·라이선스가 모두 없습니다.`,
    );
    if (item.language === "zh-Hans") {
      check(
        source.script === "Hans",
        `${prefix}: Tatoeba 원문의 스크립트가 간체(Hans)가 아닙니다.`,
      );
    }

    rows.push({
      pack: relativePath.split("/").at(-1),
      id: item.id,
      language: item.language,
      sourceId,
      translationId,
      license: source.license,
    });
    await delay(150);
  }
}

if (failures.length) {
  for (const failure of failures) console.error(`FAIL ${failure}`);
  process.exitCode = 1;
} else {
  console.table(rows);
  console.log(
    `Tatoeba 팩 ${packPaths.length}개, 문장 ${rows.length}개의 직접 번역·작성자·라이선스를 확인했습니다.`,
  );
}

function check(condition, message) {
  if (!condition) failures.push(message);
}

async function fetchJson(url) {
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: {
          Accept: "application/json",
          "User-Agent": "Sprache-content-audit/1.0",
        },
        signal: AbortSignal.timeout(30_000),
      });
      if (response.ok) return await response.json();
      if (response.status !== 429 && response.status < 500) {
        throw new Error(`${response.status} ${await response.text()}`);
      }
      lastError = new Error(`Tatoeba API ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await delay(attempt * 1_000);
  }
  throw lastError;
}

function delay(milliseconds) {
  return new Promise((resolveDelay) => setTimeout(resolveDelay, milliseconds));
}
