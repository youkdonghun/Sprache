import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  buildLanguagePackCatalog,
  serializeLanguagePackCatalog,
  validatePack,
} from '../build-language-pack-catalog.mjs';

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
