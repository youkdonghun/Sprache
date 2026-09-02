import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  buildLanguagePackCatalog,
  serializeLanguagePackCatalog,
  validatePack,
} from '../build-language-pack-catalog.mjs';

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

const validPack = {
  schemaVersion: 1,
  id: 'en-test-pack',
  title: '영어 테스트팩',
  description: '카탈로그 생성 테스트',
  language: 'en',
  version: '1.0.0',
  revision: 1,
  publishedAt: '2026-09-02T00:00:00Z',
  license: 'CC0-1.0',
  attribution: 'Test fixture',
  items: [
    {
      id: 'test-word-1',
      type: 'word',
      term: 'hello',
      meaning: '안녕하세요',
    },
    {
      id: 'test-sentence-1',
      type: 'sentence',
      term: 'Hello, world.',
      meaning: '안녕, 세상아.',
      sentence_tokens: 'Hello,|world.',
    },
  ],
};

test('builds a deterministic catalog with size and SHA-256', async (t) => {
  const root = await mkdtemp(join(tmpdir(), 'sprache-language-packs-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const packs = join(root, 'language-packs', 'packs');
  await mkdir(packs, { recursive: true });
  const body = `${JSON.stringify(validPack, null, 2)}\n`;
  await writeFile(join(packs, 'en-test-pack.json'), body, 'utf8');

  const first = await buildLanguagePackCatalog(root);
  const second = await buildLanguagePackCatalog(root);
  assert.equal(serializeLanguagePackCatalog(first), serializeLanguagePackCatalog(second));
  assert.equal(first.updatedAt, '2026-09-02T00:00:00.000Z');
  assert.equal(first.packs.length, 1);
  assert.equal(first.packs[0].itemCount, 2);
  assert.equal(first.packs[0].sizeBytes, Buffer.byteLength(body));
  assert.match(first.packs[0].sha256, /^[a-f0-9]{64}$/);
  assert.equal(first.packs[0].path, 'packs/en-test-pack.json');
});

test('rejects a sentence without explicit tokens', () => {
  assert.throws(
    () => validatePack({
      ...validPack,
      items: [{
        id: 'broken-sentence',
        type: 'sentence',
        term: 'No tokens.',
        meaning: '토큰이 없습니다.',
      }],
    }),
    /sentence_tokens/,
  );
});

test('rejects duplicate stable item ids', () => {
  assert.throws(
    () => validatePack({
      ...validPack,
      items: [validPack.items[0], { ...validPack.items[0] }],
    }),
    /duplicate item id/,
  );
});

test('repository publishes one curated download pack for every learning language', async () => {
  const catalog = await buildLanguagePackCatalog(repositoryRoot);
  const expected = new Map([
    ['de', 'sprache-de-tufs-core-2026-09'],
    ['en', 'sprache-en-tufs-core-2026-09'],
    ['es', 'sprache-es-tufs-core-2026-09'],
    ['fr', 'sprache-fr-tufs-core-2026-09'],
    ['ja', 'sprache-ja-tufs-core-2026-09'],
    ['zh-Hans', 'sprache-zh-hans-tufs-core-2026-09'],
  ]);

  for (const [language, id] of expected) {
    const descriptor = catalog.packs.find((pack) => pack.id === id);
    assert.ok(descriptor, `${language} starter pack is missing`);
    assert.equal(descriptor.language, language);
    assert.ok(descriptor.itemCount >= 440);
    assert.match(descriptor.sha256, /^[a-f0-9]{64}$/);
  }
});

test('English pack keeps the reviewed beef pronunciation', async () => {
  const pack = JSON.parse(await readFile(
    join(repositoryRoot, 'language-packs', 'packs', 'sprache-en-tufs-core-2026-09.json'),
    'utf8',
  ));
  const beef = pack.items.find((item) => item.term === 'beef');
  assert.ok(beef);
  assert.equal(beef.meaning, '쇠고기');
  assert.equal(beef.korean_pronunciation, '비프');
});

test('same spelling keeps every aligned Korean meaning without duplicate cards', async () => {
  const pack = JSON.parse(await readFile(
    join(repositoryRoot, 'language-packs', 'packs', 'sprache-en-tufs-core-2026-09.json'),
    'utf8',
  ));
  const mornings = pack.items.filter((item) => item.term === 'morning');
  assert.equal(mornings.length, 1);
  assert.ok(mornings[0].accepted_answers.includes('오전'));
  assert.ok(mornings[0].accepted_answers.includes('아침'));
});

test('Japanese pack preserves safe kana readings from the source', async () => {
  const pack = JSON.parse(await readFile(
    join(repositoryRoot, 'language-packs', 'packs', 'sprache-ja-tufs-core-2026-09.json'),
    'utf8',
  ));
  const beef = pack.items.find((item) => item.meaning === '쇠고기');
  assert.ok(beef);
  assert.equal(beef.term, '牛肉');
  assert.equal(beef.kana, 'ぎゅうにく');
});
