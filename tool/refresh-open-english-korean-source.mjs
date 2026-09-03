import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = join(repositoryRoot, 'language-packs', 'sources');
const outputPath = join(sourceRoot, 'english-korean-open-dictionary-subset.json');

const normalize = (value) => value.normalize('NFKC').replace(/\s+/gu, ' ').trim();
const keyFor = (value) => normalize(value).toLocaleLowerCase('en');

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
  assert.ok(inputPath, 'Usage: node tool/refresh-open-english-korean-source.mjs --input <words.json>');
  const input = JSON.parse(await readFile(resolve(inputPath), 'utf8'));
  const targets = await targetHeadwords();
  const subset = {};
  for (const word of [...targets].sort((left, right) => left.localeCompare(right, 'en'))) {
    const meaning = normalize(input[word]?.meaning_ko ?? '');
    if (!meaning || !/[가-힣]/u.test(meaning) || /[A-Za-z〔〕]/u.test(meaning)) continue;
    subset[word] = meaning;
  }
  await writeFile(outputPath, `${JSON.stringify(subset, null, 2)}\n`, 'utf8');
  process.stdout.write(`Updated ${outputPath}: ${Object.keys(subset).length} entries\n`);
}

const inputIndex = process.argv.indexOf('--input');
if (inputIndex >= 0) {
  await refresh(process.argv[inputIndex + 1]);
} else {
  process.stderr.write('Use --input <words.json>.\n');
  process.exitCode = 1;
}
