import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const packPath = path.join(root, 'exam-packs', 'packs', 'sprache-business-english-practice-1.json');
const catalogPath = path.join(root, 'exam-packs', 'catalog.json');

async function readFixtures() {
  const [packText, catalogText] = await Promise.all([
    readFile(packPath, 'utf8'),
    readFile(catalogPath, 'utf8'),
  ]);
  return { packText, pack: JSON.parse(packText), catalog: JSON.parse(catalogText) };
}

test('starter exam pack has the complete current seven-part distribution', async () => {
  const { pack } = await readFixtures();
  const expected = new Map([[1, 6], [2, 25], [3, 39], [4, 30], [5, 30], [6, 16], [7, 54]]);

  assert.equal(pack.schemaVersion, 1);
  assert.equal(pack.language, 'en');
  assert.equal(pack.questions.length, 200);
  for (const [part, count] of expected) {
    assert.equal(pack.questions.filter((question) => question.part === part).length, count);
  }
});

test('every question has a valid answer and useful explanations', async () => {
  const { pack } = await readFixtures();
  const ids = new Set();
  const stimulusIds = new Set(pack.stimuli.map((stimulus) => stimulus.id));

  for (const question of pack.questions) {
    assert.ok(!ids.has(question.id), `duplicate question id: ${question.id}`);
    ids.add(question.id);
    assert.equal(question.choices.length, question.part === 2 ? 3 : 4, question.id);
    assert.ok(question.correctIndex >= 0 && question.correctIndex < question.choices.length, question.id);
    assert.ok(question.explanation.trim().length >= 8, question.id);
    assert.equal(question.choiceExplanations.length, question.choices.length, question.id);
    question.choiceExplanations.forEach((value) => assert.ok(value.trim().length >= 8, question.id));
    assert.ok(question.skill.trim().length > 0, question.id);
    if (question.part !== 5) assert.ok(stimulusIds.has(question.stimulusId), question.id);
  }
});

test('Part 2 spoken labels use the same shuffled order shown by the app', async () => {
  const { pack } = await readFixtures();
  const stimuli = new Map(pack.stimuli.map((stimulus) => [stimulus.id, stimulus]));

  for (const question of pack.questions.filter((item) => item.part === 2)) {
    const script = stimuli.get(question.stimulusId).audioScript;
    question.choices.forEach((choice, index) => {
      assert.ok(script.includes(`${String.fromCharCode(65 + index)}. ${choice}`), question.id);
    });
  }
});

test('catalog pins exact bytes and content stays independent from ETS', async () => {
  const { packText, pack, catalog } = await readFixtures();
  const descriptor = catalog.packs.find((item) => item.id === pack.id);

  assert.ok(descriptor);
  assert.equal(descriptor.questionCount, 200);
  assert.equal(descriptor.sizeBytes, Buffer.byteLength(packText));
  assert.equal(descriptor.sha256, createHash('sha256').update(packText).digest('hex'));
  assert.match(pack.disclaimer, /not endorsed or approved by ETS/i);
  assert.match(pack.disclaimer, /공식 또는 기출문제를 포함하지 않습니다/);
});
