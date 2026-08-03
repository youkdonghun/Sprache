import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
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
const currentRelease = await readCurrentRelease();

test('creates and verifies a checksummed four-platform manifest', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'sprache-release-bundle-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const entries = await writeBundleInputs(root);
  const specPath = path.join(root, 'release-spec.json');
  const manifestPath = path.join(
    root,
    `release-manifest-${currentRelease.version}.json`,
  );
  await writeJson(specPath, {
    format: 'sprache-release-spec-v2',
    version: currentRelease.version,
    buildNumber: currentRelease.buildNumber,
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
  const android = verified.entries.find((entry) => entry.platform === 'android');
  assert.equal(android.mode, 'REAL');
  assert.equal(android.verification, 'BUILD_ONLY');
  assert.equal(android.launched, false);
  assert.equal(android.firstFrameRendered, false);
  assert.equal(android.firstFrameMillis, null);
});

test('detects artifact tampering after manifest creation', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'sprache-release-tamper-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const entries = await writeBundleInputs(root);
  const specPath = path.join(root, 'release-spec.json');
  const manifestPath = path.join(
    root,
    `release-manifest-${currentRelease.version}.json`,
  );
  await writeJson(specPath, {
    format: 'sprache-release-spec-v2',
    version: currentRelease.version,
    buildNumber: currentRelease.buildNumber,
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
    format: 'sprache-release-spec-v2',
    version: currentRelease.version,
    buildNumber: currentRelease.buildNumber,
    releasePolicy: policy,
    entries,
  });
  await assert.rejects(
    createReleaseManifest({ specPath }),
    /escapes the release root/,
  );

  const safeEntries = await writeBundleInputs(root);
  const evidence = JSON.parse(
    await readFile(path.join(root, safeEntries[0].evidence), 'utf8'),
  );
  evidence.firstFrameRendered = false;
  await writeJson(path.join(root, safeEntries[0].evidence), evidence);
  await writeJson(specPath, {
    format: 'sprache-release-spec-v2',
    version: currentRelease.version,
    buildNumber: currentRelease.buildNumber,
    releasePolicy: policy,
    entries: safeEntries,
  });
  await assert.rejects(
    createReleaseManifest({ specPath }),
    /first-frame probe failed/,
  );
});

test('rejects dishonest or unbound Android BUILD_ONLY evidence', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'sprache-release-build-only-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const entries = await writeBundleInputs(root);
  const android = entries.find((entry) => entry.platform === 'android');
  const specPath = path.join(root, 'release-spec.json');
  const original = JSON.parse(
    await readFile(path.join(root, android.evidence), 'utf8'),
  );

  for (const mutate of [
    (value) => { value.launched = true; },
    (value) => { value.signatureVerified = false; },
    (value) => { value.artifactSha256 = '0'.repeat(64); },
    (value) => { value.limitation = 'UNSPECIFIED'; },
  ]) {
    const evidence = structuredClone(original);
    mutate(evidence);
    await writeJson(path.join(root, android.evidence), evidence);
    await writeJson(specPath, {
      format: 'sprache-release-spec-v2',
      version: currentRelease.version,
      buildNumber: currentRelease.buildNumber,
      releasePolicy: policy,
      entries,
    });
    await assert.rejects(createReleaseManifest({ specPath }));
  }
});

test('does not let another platform or a mismatched spec opt into BUILD_ONLY', async (t) => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'sprache-release-verification-scope-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const entries = await writeBundleInputs(root);
  const specPath = path.join(root, 'release-spec.json');
  const windows = entries.find((entry) => entry.platform === 'windows');
  windows.verification = 'BUILD_ONLY';
  await writeJson(specPath, {
    format: 'sprache-release-spec-v2',
    version: currentRelease.version,
    buildNumber: currentRelease.buildNumber,
    releasePolicy: policy,
    entries,
  });
  await assert.rejects(
    createReleaseManifest({ specPath }),
    /windows\.verification must be RUNTIME/,
  );

  windows.verification = 'RUNTIME';
  const android = entries.find((entry) => entry.platform === 'android');
  android.verification = 'RUNTIME';
  await writeJson(specPath, {
    format: 'sprache-release-spec-v2',
    version: currentRelease.version,
    buildNumber: currentRelease.buildNumber,
    releasePolicy: policy,
    entries,
  });
  await assert.rejects(
    createReleaseManifest({ specPath }),
    /android\.verification must be BUILD_ONLY/,
  );
});

async function writeBundleInputs(root) {
  const definitions = [
    [
      'windows',
      'REAL',
      'RUNTIME',
      `Sprache-Windows-Setup-${currentRelease.version}.exe`,
    ],
    [
      'android',
      'REAL',
      'BUILD_ONLY',
      `Sprache-Android-${currentRelease.version}.apk`,
    ],
    [
      'ios',
      'MOCK',
      'RUNTIME',
      `Sprache-iOS-Simulator-${currentRelease.version}-mock.zip`,
    ],
    [
      'macos',
      'MOCK',
      'RUNTIME',
      `Sprache-macOS-${currentRelease.version}-mock.zip`,
    ],
  ];
  const entries = [];
  for (const [platform, mode, verification, artifact] of definitions) {
    const evidence = `${verification === 'RUNTIME' ? 'runtime' : 'build'}-${platform}.json`;
    const artifactContents = `${platform}-${mode}-artifact`;
    await writeFile(path.join(root, artifact), artifactContents);
    const common = {
      platform,
      mode,
      version: currentRelease.version,
      buildNumber: currentRelease.buildNumber,
      checkedAt: '2026-08-03T06:00:00.000Z',
    };
    if (verification === 'RUNTIME') {
      await writeJson(path.join(root, evidence), {
        format: 'sprache-runtime-evidence-v1',
        ...common,
        launched: true,
        firstFrameRendered: true,
        firstFrameMillis: 731,
        probe: platform === 'windows' ? 'native-runtime' : 'flutter-first-frame',
      });
    } else {
      await writeJson(path.join(root, evidence), {
        format: 'sprache-build-evidence-v1',
        ...common,
        verification: 'BUILD_ONLY',
        launched: false,
        firstFrameRendered: false,
        firstFrameMillis: null,
        probe: 'signed-release-build',
        buildVerified: true,
        signatureVerified: true,
        packageVerified: true,
        limitation: 'ANDROID_RUNTIME_UNAVAILABLE_CI_BILLING_AND_LOCAL_HYPERVISOR',
        packageName: 'com.youkdonghun.sprache',
        abis: ['arm64-v8a', 'armeabi-v7a', 'x86_64'],
        artifactSha256: createHash('sha256').update(artifactContents).digest('hex'),
        artifactByteLength: Buffer.byteLength(artifactContents),
      });
    }
    entries.push({ platform, mode, verification, artifact, evidence });
  }
  return entries;
}

async function readCurrentRelease() {
  const pubspec = await readFile(
    new URL('../../apps/client/pubspec.yaml', import.meta.url),
    'utf8',
  );
  const match = pubspec.match(
    /^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$/m,
  );
  assert.ok(match, 'pubspec.yaml must contain a semantic version and build number');
  return {
    version: match[1],
    buildNumber: Number(match[2]),
  };
}

async function writeJson(file, value) {
  await writeFile(file, `${JSON.stringify(value, null, 2)}\n`);
}
