import assert from 'node:assert/strict';
import { createReadStream } from 'node:fs';
import { readFile, writeFile } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = join(repositoryRoot, 'language-packs', 'sources');
const outputPath = join(sourceRoot, 'english-korean-wiktionary-subset.json');

const normalize = (value) => value.normalize('NFKC').replace(/\s+/gu, ' ').trim();
const keyFor = (value) => normalize(value).toLocaleLowerCase('en');

function cleanGloss(value) {
  const cleaned = normalize(value)
    .replace(/^\d+\.\s*:?\s*/u, '')
    .replace(/^:\s*/u, '')
    .replace(/\s*\([^)]*(?:[A-Za-z]|부록:)[^)]*\)/gu, '')
    .replace(/\s+/gu, ' ')
    .replace(/[.]$/u, '')
    .trim();
  if (
    cleaned.length < 1 ||
    cleaned.length > 100 ||
    !/[가-힣]/u.test(cleaned) ||
    /[A-Za-z〔〕]/u.test(cleaned)
  ) {
    return null;
  }
  return cleaned;
}

async function readCsvHeadwords(fileName) {
  const body = await readFile(join(sourceRoot, fileName), 'utf8');
  return body
    .split(/\r?\n/u)
    .filter((line) => line && !line.startsWith('#'))
    .map((line) => line.split(','))
    .map((columns) => keyFor(/^\d+$/u.test(columns[0]) ? columns[1] : columns[0]))
    .filter((word) => word && word !== 'word');
}

async function targetHeadwords() {
  const [ngsl, bsl, graded, spoken, toeic] = await Promise.all([
    readCsvHeadwords('ngsl-1.2-teaching.csv'),
    readCsvHeadwords('bsl-1.2-teaching.csv'),
    readCsvHeadwords('ngsl-gr-rank.csv'),
    readFile(join(sourceRoot, 'ngsl-spoken-1.2.txt'), 'utf8').then((body) =>
      body.split(/\r?\n/u).map(keyFor).filter(Boolean)),
    readFile(join(sourceRoot, 'toeic-service-list-1.2.txt'), 'utf8').then((body) =>
      body.split(/\r?\n/u).map(keyFor).filter(Boolean)),
  ]);
  return new Set([...ngsl, ...bsl, ...graded, ...spoken, ...toeic]);
}

async function refresh(inputPath) {
  assert.ok(inputPath, 'Usage: node tool/refresh-english-korean-wiktionary-source.mjs --input <Kaikki JSONL>');
  const targets = await targetHeadwords();
  const existing = JSON.parse(await readFile(outputPath, 'utf8'));
  const additions = new Map();
  const input = createInterface({
    input: createReadStream(resolve(inputPath), { encoding: 'utf8' }),
    crlfDelay: Infinity,
  });

  for await (const line of input) {
    if (!line) continue;
    const entry = JSON.parse(line);
    const key = keyFor(entry.word ?? '');
    if (!targets.has(key) || Object.hasOwn(existing, key) || additions.has(key)) continue;
    const glosses = (entry.senses ?? []).flatMap((sense) => sense.glosses ?? []);
    const gloss = glosses.map(cleanGloss).find(Boolean);
    if (gloss) additions.set(key, gloss);
  }

  const merged = Object.fromEntries(
    [...Object.entries(existing), ...additions]
      .map(([key, value]) => [keyFor(key), normalize(value)])
      .sort(([left], [right]) => left.localeCompare(right, 'en')),
  );
  await writeFile(outputPath, `${JSON.stringify(merged, null, 2)}\n`, 'utf8');
  process.stdout.write(
    `Updated ${outputPath}: ${Object.keys(existing).length} existing + ${additions.size} new = ${Object.keys(merged).length}\n`,
  );
}

const inputIndex = process.argv.indexOf('--input');
if (inputIndex >= 0) {
  await refresh(process.argv[inputIndex + 1]);
} else {
  process.stderr.write('Use --input <Kaikki JSONL>.\n');
  process.exitCode = 1;
}
