import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = join(repositoryRoot, 'language-packs', 'sources');
const packRoot = join(repositoryRoot, 'language-packs', 'packs');
const publishedAt = '2026-09-03T00:00:00Z';

const definitions = [
  {
    id: 'sprache-en-toss-speaking-core-2026-09',
    sourceFile: 'ngsl-spoken-1.2.txt',
    title: 'TOSS 기본 어휘 721',
    description:
      '토익 스피킹에 필요한 일상 회화 중심 어휘입니다. 공식 시험 문제가 아닌 NGSL-Spoken 1.2 기반 자료입니다.',
    expectedCount: 721,
    reviewedGlossFile: 'english-toss-reviewed-glosses.json',
    tags: ['TOSS', '토익 스피킹', '기본 어휘'],
    attribution:
      'NGSL-Spoken 1.2 by Browne and Culligan; Korean meanings from TUFS, Korean Wiktionary, and Sprache editorial additions',
  },
  {
    id: 'sprache-en-toeic-service-core-2026-09',
    sourceFile: 'toeic-service-list-1.2.txt',
    title: 'TOEIC 기본 어휘 1,250',
    description:
      '업무와 시험 문맥에서 자주 쓰는 핵심 어휘입니다. 공식 시험 문제가 아닌 TOEIC Service List 1.2 기반 자료입니다.',
    expectedCount: 1250,
    tags: ['TOEIC', '업무 영어', '기본 어휘'],
    attribution:
      'TOEIC Service List 1.2 by Browne and Culligan; Korean meanings from TUFS, Korean Wiktionary, and Sprache editorial additions',
  },
];

const normalize = (value) => value.normalize('NFKC').replace(/\s+/gu, ' ').trim();
const keyFor = (value) => normalize(value).toLocaleLowerCase('en');

function acceptedAnswers(meaning) {
  return [...new Set([
    meaning,
    ...meaning.split(/[,;/，、]/u).map(normalize).filter(Boolean),
  ])];
}

async function readWordList(fileName) {
  return (await readFile(join(sourceRoot, fileName), 'utf8'))
    .split(/\r?\n/u)
    .map(normalize)
    .filter((line) => line && !line.startsWith('#'));
}

async function readSources() {
  const [manual, wiktionary, tossReviewed, tossOverrides, tufs] = await Promise.all([
    readFile(join(sourceRoot, 'english-exam-manual-glosses.json'), 'utf8').then(JSON.parse),
    readFile(join(sourceRoot, 'english-korean-wiktionary-subset.json'), 'utf8').then(JSON.parse),
    readFile(join(sourceRoot, 'english-toss-reviewed-glosses.json'), 'utf8').then(JSON.parse),
    readFile(join(sourceRoot, 'english-toss-overrides.json'), 'utf8').then(JSON.parse),
    readFile(join(packRoot, 'sprache-en-tufs-core-2026-09.json'), 'utf8').then(JSON.parse),
  ]);
  const tufsMeanings = Object.fromEntries(
    tufs.items.map((item) => [keyFor(item.term), normalize(item.meaning)]),
  );
  return { manual, wiktionary, tossReviewed, tossOverrides, tufsMeanings };
}

function buildPack(definition, words, sources) {
  assert.equal(words.length, definition.expectedCount, `${definition.title}: source count`);
  assert.equal(new Set(words.map(keyFor)).size, words.length, `${definition.title}: duplicate word`);
  const missing = [];
  const items = words.map((term, index) => {
    const key = keyFor(term);
    const meaning = normalize(
      (definition.reviewedGlossFile == null ? null : sources.tossOverrides[term] ?? sources.tossOverrides[key]) ??
        (definition.reviewedGlossFile == null ? null : sources.tossReviewed[term] ?? sources.tossReviewed[key]) ??
        sources.manual[key] ??
        sources.tufsMeanings[key] ??
        sources.wiktionary[key] ??
        '',
    );
    if (!meaning) missing.push(term);
    return {
      id: `${definition.id}-word-${index + 1}`,
      type: 'word',
      language: 'en',
      term,
      meaning,
      accepted_answers: acceptedAnswers(meaning),
      tags: definition.tags,
      priority: index < 100 ? 4 : 2,
    };
  });
  assert.deepEqual(missing, [], `${definition.title}: Korean meanings missing`);
  return {
    schemaVersion: 1,
    id: definition.id,
    title: definition.title,
    description: definition.description,
    language: 'en',
    version: '2026.09.1',
    revision: 1,
    publishedAt,
    license: 'CC-BY-SA-4.0',
    attribution: definition.attribution,
    items,
  };
}

async function expectedPacks() {
  const sources = await readSources();
  return Promise.all(definitions.map(async (definition) => {
    const words = await readWordList(definition.sourceFile);
    return buildPack(definition, words, sources);
  }));
}

async function refresh() {
  for (const pack of await expectedPacks()) {
    const path = join(packRoot, `${pack.id}.json`);
    await writeFile(path, `${JSON.stringify(pack, null, 2)}\n`, 'utf8');
    process.stdout.write(`Updated ${path} (${pack.items.length} items)\n`);
  }
}

async function check() {
  for (const expected of await expectedPacks()) {
    const path = join(packRoot, `${expected.id}.json`);
    const actual = JSON.parse(await readFile(path, 'utf8'));
    assert.deepEqual(actual, expected);
  }
  process.stdout.write('English exam language packs are current.\n');
}

if (process.argv.includes('--refresh')) {
  await refresh();
} else if (process.argv.includes('--check')) {
  await check();
} else {
  process.stderr.write('Use --refresh or --check.\n');
  process.exitCode = 1;
}
