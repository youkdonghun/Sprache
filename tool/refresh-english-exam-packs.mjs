import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = join(repositoryRoot, 'language-packs', 'sources');
const packRoot = join(repositoryRoot, 'language-packs', 'packs');
const publishedAt = '2026-09-03T01:37:00Z';

const definitions = [
  {
    id: 'sprache-en-toss-speaking-core-2026-09',
    primarySourceFile: 'ngsl-spoken-1.2.txt',
    expansionSourceFiles: ['ngsl-gr-rank.csv'],
    title: 'TOSS 기본 어휘·숙어 5,000',
    description:
      '말하기 고빈도 단어 4,750개와 바로 쓰는 회화·숙어 250개를 묶었습니다. 공식 시험 문제가 아닌 공개 어휘 목록 기반 자료입니다.',
    wordCount: 4750,
    phraseGroups: ['common', 'speaking'],
    reviewedGlossFile: 'english-toss-reviewed-glosses.json',
    tags: ['TOSS', '토익 스피킹', '기본 어휘·숙어'],
    attribution:
      'NGSL-Spoken 1.2 and NGSL-GR by Browne and Culligan; Korean meanings from TUFS, Korean Wiktionary, Open English-Korean Dictionary, and Sprache editorial review; phrases edited by Sprache',
  },
  {
    id: 'sprache-en-toeic-service-core-2026-09',
    primarySourceFile: 'toeic-service-list-1.2.txt',
    expansionSourceFiles: ['bsl-1.2-teaching.csv', 'ngsl-1.2-teaching.csv'],
    title: 'TOEIC 기본 어휘·숙어 5,000',
    description:
      '시험·업무 고빈도 단어 4,750개와 실무 결합표현 250개를 묶었습니다. 공식 시험 문제가 아닌 공개 어휘 목록 기반 자료입니다.',
    wordCount: 4750,
    phraseGroups: ['common', 'toeic'],
    tags: ['TOEIC', '업무 영어', '기본 어휘·숙어'],
    attribution:
      'TOEIC Service List 1.2, Business Service List 1.2, and NGSL 1.2 by Browne and Culligan; Korean meanings from TUFS, Korean Wiktionary, Open English-Korean Dictionary, and Sprache editorial review; phrases edited by Sprache',
  },
];

const normalize = (value) => value.normalize('NFKC').replace(/\s+/gu, ' ').trim();
const keyFor = (value) => normalize(value).toLocaleLowerCase('en');
const comparableKeyFor = (value) => keyFor(value).replace(/\s+/gu, '');

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
    .filter((line) => line && !line.startsWith('#'))
    .map((line) => {
      const columns = line.split(',');
      if (/^\d+$/u.test(columns[0])) return columns[1];
      return columns[0];
    })
    .map(normalize)
    .filter((word) => word && keyFor(word) !== 'word');
}

async function readSources() {
  const [manual, expandedOverrides, wiktionary, openDictionary, phrases, tossReviewed, tossOverrides, tufs] = await Promise.all([
    readFile(join(sourceRoot, 'english-exam-manual-glosses.json'), 'utf8').then(JSON.parse),
    readFile(join(sourceRoot, 'english-exam-expanded-overrides.json'), 'utf8').then(JSON.parse),
    readFile(join(sourceRoot, 'english-korean-wiktionary-subset.json'), 'utf8').then(JSON.parse),
    readFile(join(sourceRoot, 'english-korean-open-dictionary-subset.json'), 'utf8').then(JSON.parse),
    readFile(join(sourceRoot, 'english-exam-phrases.json'), 'utf8').then(JSON.parse),
    readFile(join(sourceRoot, 'english-toss-reviewed-glosses.json'), 'utf8').then(JSON.parse),
    readFile(join(sourceRoot, 'english-toss-overrides.json'), 'utf8').then(JSON.parse),
    readFile(join(packRoot, 'sprache-en-tufs-core-2026-09.json'), 'utf8').then(JSON.parse),
  ]);
  const tufsMeanings = Object.fromEntries(
    tufs.items.map((item) => [keyFor(item.term), normalize(item.meaning)]),
  );
  return {
    manual,
    expandedOverrides,
    wiktionary,
    openDictionary,
    phrases,
    tossReviewed,
    tossOverrides,
    tufsMeanings,
  };
}

function safeMeaning(value) {
  if (value == null) return null;
  const cleaned = normalize(value)
    .replace(/\s*\([^)]*[A-Za-z][^)]*\)/gu, '')
    .replace(/\s*[〈<][^〉>]*[〉>]/gu, '')
    .replace(/\s+/gu, ' ')
    .replace(/[.]$/u, '')
    .trim();
  if (!cleaned || !/[가-힣]/u.test(cleaned) || /[A-Za-z〔〕]/u.test(cleaned)) return null;
  return cleaned;
}

function meaningFor(definition, term, sources) {
  const key = keyFor(term);
  const candidates = [
    sources.expandedOverrides[term] ?? sources.expandedOverrides[key],
    definition.reviewedGlossFile == null ? null : sources.tossOverrides[term] ?? sources.tossOverrides[key],
    definition.reviewedGlossFile == null ? null : sources.tossReviewed[term] ?? sources.tossReviewed[key],
    sources.manual[key],
    sources.tufsMeanings[key],
    sources.wiktionary[key],
    sources.openDictionary[key],
  ];
  return candidates.map(safeMeaning).find(Boolean) ?? '';
}

function uniqueWords(groups) {
  const seen = new Set();
  return groups.flat().filter((word) => {
    const key = keyFor(word);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function buildPack(definition, candidateWords, sources) {
  const words = uniqueWords(candidateWords)
    .filter((term) => meaningFor(definition, term, sources))
    .slice(0, definition.wordCount);
  assert.equal(words.length, definition.wordCount, `${definition.title}: resolved word count`);
  const wordComparableKeys = new Set(words.map(comparableKeyFor));
  const phraseComparableKeys = new Set();
  const phrasePairs = definition.phraseGroups
    .flatMap((group) => sources.phrases[group])
    .filter(([term]) => {
      const key = comparableKeyFor(term);
      if (wordComparableKeys.has(key) || phraseComparableKeys.has(key)) return false;
      phraseComparableKeys.add(key);
      return true;
    });
  assert.equal(new Set(phrasePairs.map(([term]) => comparableKeyFor(term))).size, phrasePairs.length,
    `${definition.title}: duplicate phrase`);
  assert.equal(phrasePairs.length, 250, `${definition.title}: phrase count`);
  const missing = [];
  const items = words.map((term, index) => {
    const meaning = meaningFor(definition, term, sources);
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
  items.push(...phrasePairs.map(([term, rawMeaning], index) => {
    const meaning = safeMeaning(rawMeaning);
    assert.ok(meaning, `${definition.title}: unsafe phrase meaning for ${term}`);
    return {
      id: `${definition.id}-phrase-${index + 1}`,
      type: 'word',
      language: 'en',
      term: normalize(term),
      meaning,
      accepted_answers: acceptedAnswers(meaning),
      tags: [...definition.tags, '숙어·표현'],
      priority: 3,
    };
  }));
  assert.equal(items.length, 5000, `${definition.title}: total item count`);
  return {
    schemaVersion: 1,
    id: definition.id,
    title: definition.title,
    description: definition.description,
    language: 'en',
    version: '2026.09.2',
    revision: 2,
    publishedAt,
    license: 'CC-BY-SA-4.0',
    attribution: definition.attribution,
    items,
  };
}

async function expectedPacks() {
  const sources = await readSources();
  return Promise.all(definitions.map(async (definition) => {
    const primary = await readWordList(definition.primarySourceFile);
    const expansions = await Promise.all(
      definition.expansionSourceFiles.map(readWordList),
    );
    return buildPack(definition, [primary, ...expansions], sources);
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
