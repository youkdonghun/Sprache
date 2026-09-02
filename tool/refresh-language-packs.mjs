import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = join(repositoryRoot, 'language-packs', 'sources');
const packRoot = join(repositoryRoot, 'language-packs', 'packs');
const publishedAt = '2026-09-02T00:00:00Z';
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
const keyOf = (value) => normalize(value).toLocaleLowerCase('und');

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

function buildItems(definition, alignment, bundledTerms) {
  const excluded = new Set(bundledTerms.map(keyOf));
  const seen = new Set();
  const packId = `sprache-${definition.slug}-tufs-core-2026-09`;
  return alignment.items.flatMap((row) => {
    const rawTerm = normalize(row[definition.sourceKey]);
    const parsed = definition.language === 'zh-Hans'
      ? chineseTermAndReading(rawTerm)
      : { term: rawTerm, pinyin: null };
    const key = keyOf(parsed.term);
    if (!parsed.term || !normalize(row.ko) || excluded.has(key) || seen.has(key)) {
      return [];
    }
    seen.add(key);
    return [{
      id: `${packId}-word-${String(row.conceptId).replace(/[^a-zA-Z0-9._-]/gu, '-')}`,
      type: 'word',
      language: definition.language,
      term: parsed.term,
      meaning: normalize(row.ko),
      accepted_answers: acceptedAnswers(normalize(row.ko)),
      tags: ['TUFS', '생활 핵심 어휘', 'GitHub 언어팩'],
      priority: 3,
      ...(parsed.pinyin ? { pinyin: parsed.pinyin } : {}),
    }];
  });
}

function buildPack(definition, items) {
  const id = `sprache-${definition.slug}-tufs-core-2026-09`;
  return {
    schemaVersion: 1,
    id,
    title: `${definition.name} 생활 핵심 추가 어휘 ${items.length}`,
    description: '앱 내장 어휘와 겹치지 않게 선별한 TUFS 다국어 생활 핵심 어휘입니다.',
    language: definition.language,
    version: '2026.09.1',
    revision: 1,
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
  const bundled = JSON.parse(
    await readFile(join(sourceRoot, 'bundled-word-terms.json'), 'utf8'),
  );
  assert.equal(alignment.schemaVersion, 1);
  assert.equal(alignment.license, 'CC-BY-4.0');
  assert.equal(alignment.items.length, 444);
  assert.equal(bundled.schemaVersion, 1);
  return { alignment, bundled: bundled.languages };
}

async function refresh() {
  const { alignment, bundled } = await readSources();
  for (const definition of definitions) {
    const items = buildItems(definition, alignment, bundled[definition.language]);
    assert.ok(items.length >= 350, `${definition.language} yielded too few items`);
    const pack = buildPack(definition, items);
    const path = join(packRoot, `sprache-${definition.slug}-tufs-core-2026-09.json`);
    await writeFile(path, `${JSON.stringify(pack, null, 2)}\n`, 'utf8');
    process.stdout.write(`Updated ${path} (${items.length} items)\n`);
  }
}

async function check() {
  const { alignment, bundled } = await readSources();
  for (const definition of definitions) {
    const expectedItems = buildItems(
      definition,
      alignment,
      bundled[definition.language],
    );
    const path = join(packRoot, `sprache-${definition.slug}-tufs-core-2026-09.json`);
    const pack = JSON.parse(await readFile(path, 'utf8'));
    assert.deepEqual(pack, buildPack(definition, expectedItems));
    assert.ok(pack.items.length >= 350);
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
