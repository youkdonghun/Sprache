import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = join(repositoryRoot, 'language-packs', 'sources');
const packRoot = join(repositoryRoot, 'language-packs', 'packs');
const publishedAt = '2026-09-03T00:00:00Z';
const definitions = [
  { language: 'de', sourceKey: 'de', slug: 'de', name: '독일어' },
  { language: 'en', sourceKey: 'en', slug: 'en', name: '영어' },
  { language: 'es', sourceKey: 'es', slug: 'es', name: '스페인어' },
  { language: 'fr', sourceKey: 'fr', slug: 'fr', name: '프랑스어' },
  { language: 'ja', sourceKey: 'ja', slug: 'ja', name: '일본어' },
  { language: 'zh-Hans', sourceKey: 'zh', slug: 'zh-hans', name: '중국어' },
];

const normalize = (value) => value
  .normalize('NFKC')
  .replace(/\s+/gu, ' ')
  .trim();
const reviewedKoreanPronunciations = new Map([
  ['en:51299', '비프'],
]);

function chineseTermAndReading(value) {
  const normalized = normalize(value);
  const match = normalized.match(/^(.+?)\s+([A-Za-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ].*)$/u);
  return match
    ? { term: normalize(match[1]), pinyin: normalize(match[2]) }
    : { term: normalized, pinyin: null };
}

function acceptedAnswers(meaning) {
  return [...new Set([
    meaning,
    ...meaning.split(/[,;/，、]/u).map(normalize).filter(Boolean),
  ])];
}

function buildItems(definition, alignment) {
  const seenConcepts = new Set();
  const itemsByTerm = new Map();
  const packId = `sprache-${definition.slug}-tufs-core-2026-09`;
  for (const row of alignment.languages[definition.sourceKey]) {
    const rawTerm = normalize(row.term);
    const parsed = definition.language === 'zh-Hans'
      ? chineseTermAndReading(rawTerm)
      : { term: rawTerm, pinyin: null };
    const conceptId = String(row.conceptId);
    const meaning = normalize(row.ko);
    if (!parsed.term || !meaning || seenConcepts.has(conceptId)) {
      continue;
    }
    seenConcepts.add(conceptId);
    const koreanPronunciation = reviewedKoreanPronunciations.get(
      `${definition.language}:${row.conceptId}`,
    );
    const termKey = parsed.term.toLocaleLowerCase(definition.language);
    const existing = itemsByTerm.get(termKey);
    if (existing) {
      existing.accepted_answers = [...new Set([
        ...existing.accepted_answers,
        ...acceptedAnswers(meaning),
      ])];
      if (existing.kana && row.kana && existing.kana !== normalize(row.kana)) {
        delete existing.kana;
      }
      if (existing.pinyin && parsed.pinyin && existing.pinyin !== parsed.pinyin) {
        delete existing.pinyin;
      }
      continue;
    }
    itemsByTerm.set(termKey, {
      id: `${packId}-word-${String(row.conceptId).replace(/[^a-zA-Z0-9._-]/gu, '-')}`,
      type: 'word',
      language: definition.language,
      term: parsed.term,
      meaning,
      accepted_answers: acceptedAnswers(meaning),
      tags: ['TUFS', '생활 핵심 어휘', '추천 자료'],
      priority: 3,
      ...(row.kana ? { kana: normalize(row.kana) } : {}),
      ...(parsed.pinyin ? { pinyin: parsed.pinyin } : {}),
      ...(koreanPronunciation ? { korean_pronunciation: koreanPronunciation } : {}),
    });
  }
  return [...itemsByTerm.values()];
}

function buildPack(definition, items) {
  const id = `sprache-${definition.slug}-tufs-core-2026-09`;
  return {
    schemaVersion: 1,
    id,
    title: `${definition.name} 생활 핵심 어휘 ${items.length}`,
    description: 'TUFS의 한국어 대응 생활 핵심 어휘 전체본입니다. 앱 기본 자료와 겹치면 중복 없이 합쳐집니다.',
    language: definition.language,
    version: '2026.09.2',
    revision: 2,
    publishedAt,
    license: 'CC-BY-4.0',
    attribution: 'TUFS Open Language Resources, adapted by Sprache',
    items,
  };
}

async function readSources() {
  const alignment = JSON.parse(
    await readFile(join(sourceRoot, 'tufs-core-alignment.json'), 'utf8'),
  );
  assert.equal(alignment.schemaVersion, 2);
  assert.equal(alignment.license, 'CC-BY-4.0');
  for (const definition of definitions) {
    assert.ok(Array.isArray(alignment.languages[definition.sourceKey]));
    assert.ok(alignment.languages[definition.sourceKey].length >= 450);
  }
  return alignment;
}

async function refresh() {
  const alignment = await readSources();
  for (const definition of definitions) {
    const items = buildItems(definition, alignment);
    assert.ok(items.length >= 440, `${definition.language} yielded too few items`);
    const pack = buildPack(definition, items);
    const path = join(packRoot, `sprache-${definition.slug}-tufs-core-2026-09.json`);
    await writeFile(path, `${JSON.stringify(pack, null, 2)}\n`, 'utf8');
    process.stdout.write(`Updated ${path} (${items.length} items)\n`);
  }
}

async function check() {
  const alignment = await readSources();
  for (const definition of definitions) {
    const expectedItems = buildItems(definition, alignment);
    const path = join(packRoot, `sprache-${definition.slug}-tufs-core-2026-09.json`);
    const pack = JSON.parse(await readFile(path, 'utf8'));
    assert.deepEqual(pack, buildPack(definition, expectedItems));
    assert.ok(pack.items.length >= 440);
    assert.equal(new Set(pack.items.map((item) => item.id)).size, pack.items.length);
  }
}

if (process.argv.includes('--refresh')) {
  await refresh();
} else if (process.argv.includes('--check')) {
  await check();
} else {
  process.stderr.write('Use --refresh or --check.\n');
  process.exitCode = 1;
}
