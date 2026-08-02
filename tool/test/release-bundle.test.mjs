import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  createReleaseManifest,
  verifyReleaseManifest,
} from '../release-bundle.mjs';

const policy = {
  windows: 'REAL',
  android: 'REAL',
  ios: 'MOCK',
  macos: 'MOCK',
};

test('creates and verifies a checksummed four-platform manifest', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'sprache-release-bundle-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const entries = await writeBundleInputs(root);
  const specPath = path.join(root, 'release-spec.json');
  const manifestPath = path.join(root, 'release-manifest-1.31.0.json');
  await writeJson(specPath, {
    format: 'sprache-release-spec-v1',
    version: '1.31.0',
    buildNumber: 55,
    releasePolicy: policy,
    entries,
  });

  await createReleaseManifest({ specPath, outputPath: manifestPath });
  const verified = await verifyReleaseManifest({ manifestPath });

  assert.equal(verified.entries.length, 4);
  assert.deepEqual(
    verified.entries.map((entry) => entry.platform),
    ['android', 'ios', 'macos', 'windows'],
  );
  assert.ok(
    verified.entries.every((entry) => /^[0-9a-f]{64}$/.test(entry.sha256)),
  );
});

test('detects artifact tampering after manifest creation', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'sprache-release-tamper-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const entries = await writeBundleInputs(root);
  const specPath = path.join(root, 'release-spec.json');
  const manifestPath = path.join(root, 'release-manifest-1.31.0.json');
  await writeJson(specPath, {
    format: 'sprache-release-spec-v1',
    version: '1.31.0',
    buildNumber: 55,
    releasePolicy: policy,
    entries,
  });
  await createReleaseManifest({ specPath, outputPath: manifestPath });
  await writeFile(path.join(root, entries[0].artifact), 'tampered');

  await assert.rejects(
    verifyReleaseManifest({ manifestPath }),
    /byte length changed|SHA-256 mismatch/,
  );
});

test('rejects path traversal and dishonest runtime evidence', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'sprache-release-unsafe-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const entries = await writeBundleInputs(root);
  entries[0] = { ...entries[0], artifact: '../outside.apk' };
  const specPath = path.join(root, 'release-spec.json');
  await writeJson(specPath, {
    format: 'sprache-release-spec-v1',
    version: '1.31.0',
    buildNumber: 55,
    releasePolicy: policy,
    entries,
  });
  await assert.rejects(
    createReleaseManifest({ specPath }),
    /escapes the release root/,
  );

  const safeEntries = await writeBundleInputs(root);
  const evidence = JSON.parse(
    await readFile(path.join(root, safeEntries[1].runtimeEvidence), 'utf8'),
  );
  evidence.firstFrameRendered = false;
  await writeJson(path.join(root, safeEntries[1].runtimeEvidence), evidence);
  await writeJson(specPath, {
    format: 'sprache-release-spec-v1',
    version: '1.31.0',
    buildNumber: 55,
    releasePolicy: policy,
    entries: safeEntries,
  });
  await assert.rejects(
    createReleaseManifest({ specPath }),
    /first-frame probe failed/,
  );
});

async function writeBundleInputs(root) {
  const definitions = [
    ['windows', 'REAL', 'Sprache-Windows-Setup-1.31.0.exe'],
    ['android', 'REAL', 'Sprache-Android-1.31.0.apk'],
    ['ios', 'MOCK', 'Sprache-iOS-Simulator-1.31.0-mock.zip'],
    ['macos', 'MOCK', 'Sprache-macOS-1.31.0-mock.zip'],
  ];
  const entries = [];
  for (const [platform, mode, artifact] of definitions) {
    const runtimeEvidence = `runtime-${platform}.json`;
    await writeFile(path.join(root, artifact), `${platform}-${mode}-artifact`);
    await writeJson(path.join(root, runtimeEvidence), {
      format: 'sprache-runtime-evidence-v1',
      platform,
      mode,
      version: '1.31.0',
      buildNumber: 55,
      launched: true,
      firstFrameRendered: true,
      firstFrameMillis: 731,
      probe: platform === 'windows' ? 'native-runtime' : 'flutter-first-frame',
      checkedAt: '2026-08-03T06:00:00.000Z',
    });
    entries.push({ platform, mode, artifact, runtimeEvidence });
  }
  return entries;
}

async function writeJson(file, value) {
  await writeFile(file, `${JSON.stringify(value, null, 2)}\n`);
}
