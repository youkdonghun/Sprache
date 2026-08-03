import { createHash } from 'node:crypto';
import {
  lstat,
  readFile,
  realpath,
  stat,
  writeFile,
} from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const SPEC_FORMAT = 'sprache-release-spec-v2';
const MANIFEST_FORMAT = 'sprache-release-manifest-v2';
const RUNTIME_EVIDENCE_FORMAT = 'sprache-runtime-evidence-v1';
const BUILD_EVIDENCE_FORMAT = 'sprache-build-evidence-v1';
const EXPECTED_POLICY = Object.freeze({
  windows: 'REAL',
  android: 'REAL',
  ios: 'MOCK',
  macos: 'MOCK',
});
const EXPECTED_EXTENSIONS = Object.freeze({
  windows: '.exe',
  android: '.apk',
  ios: '.zip',
  macos: '.zip',
});
const EXPECTED_VERIFICATION = Object.freeze({
  windows: 'RUNTIME',
  android: 'BUILD_ONLY',
  ios: 'RUNTIME',
  macos: 'RUNTIME',
});
const ALLOWED_RUNTIME_PROBES = new Set([
  'native-runtime',
  'simulator-runtime',
  'flutter-first-frame',
]);
const BUILD_ONLY_PROBE = 'signed-release-build';
const BUILD_ONLY_REASON =
  'ANDROID_RUNTIME_UNAVAILABLE_CI_BILLING_AND_LOCAL_HYPERVISOR';

export async function createReleaseManifest({ specPath, outputPath, root }) {
  const resolvedSpec = path.resolve(specPath);
  const spec = await readJson(resolvedSpec, 'release spec');
  assert(spec.format === SPEC_FORMAT, `spec.format must be ${SPEC_FORMAT}`);
  const releaseRoot = path.resolve(root ?? path.dirname(resolvedSpec));
  const resolvedOutput = path.resolve(
    outputPath ?? path.join(releaseRoot, `release-manifest-${spec.version}.json`),
  );
  assertContained(releaseRoot, resolvedOutput, 'manifest output');
  const common = validateReleaseHeader(spec);
  await validateAgainstPubspec(common);
  validatePolicy(spec.releasePolicy);
  const entries = validateEntries(spec.entries, { version: common.version });
  const manifestEntries = [];
  for (const entry of entries) {
    const artifactPath = await resolveRegularFile(
      releaseRoot,
      entry.artifact,
      `${entry.platform} artifact`,
    );
    const evidencePath = await resolveRegularFile(
      releaseRoot,
      entry.evidence,
      `${entry.platform} verification evidence`,
    );
    const evidence = await readJson(
      evidencePath,
      `${entry.platform} verification evidence`,
    );
    const artifactInfo = await stat(artifactPath);
    const artifactSha256 = await sha256File(artifactPath);
    validateEvidence(evidence, entry, common, {
      artifactByteLength: artifactInfo.size,
      artifactSha256,
    });
    const manifestEntry = {
      platform: entry.platform,
      mode: entry.mode,
      verification: entry.verification,
      artifact: normalizeRelative(entry.artifact),
      byteLength: artifactInfo.size,
      sha256: artifactSha256,
      evidence: normalizeRelative(entry.evidence),
      evidenceSha256: await sha256File(evidencePath),
      probe: evidence.probe,
      launched: evidence.launched,
      firstFrameRendered: evidence.firstFrameRendered,
      checkedAt: new Date(evidence.checkedAt).toISOString(),
    };
    if (entry.verification === 'RUNTIME') {
      manifestEntry.firstFrameMillis = evidence.firstFrameMillis;
    } else {
      manifestEntry.firstFrameMillis = null;
      manifestEntry.buildVerified = evidence.buildVerified;
      manifestEntry.signatureVerified = evidence.signatureVerified;
      manifestEntry.packageVerified = evidence.packageVerified;
      manifestEntry.limitation = evidence.limitation;
      manifestEntry.packageName = evidence.packageName;
      manifestEntry.abis = evidence.abis;
    }
    manifestEntries.push(manifestEntry);
  }
  const manifest = {
    format: MANIFEST_FORMAT,
    version: common.version,
    buildNumber: common.buildNumber,
    releasePolicy: EXPECTED_POLICY,
    generatedAt: new Date().toISOString(),
    entries: manifestEntries.sort((left, right) =>
      left.platform.localeCompare(right.platform),
    ),
  };
  await writeFile(resolvedOutput, `${JSON.stringify(manifest, null, 2)}\n`, {
    encoding: 'utf8',
    flag: 'wx',
  });
  await verifyReleaseManifest({ manifestPath: resolvedOutput, root: releaseRoot });
  return { manifest, outputPath: resolvedOutput };
}

export async function verifyReleaseManifest({ manifestPath, root }) {
  const resolvedManifest = path.resolve(manifestPath);
  const releaseRoot = path.resolve(root ?? path.dirname(resolvedManifest));
  assertContained(releaseRoot, resolvedManifest, 'release manifest');
  const manifest = await readJson(resolvedManifest, 'release manifest');
  assert(
    manifest.format === MANIFEST_FORMAT,
    `manifest.format must be ${MANIFEST_FORMAT}`,
  );
  const common = validateReleaseHeader(manifest);
  await validateAgainstPubspec(common);
  assert(
    Number.isFinite(Date.parse(manifest.generatedAt)),
    'manifest.generatedAt is invalid',
  );
  validatePolicy(manifest.releasePolicy);
  const entries = validateEntries(manifest.entries, {
    manifest: true,
    version: common.version,
  });
  for (const entry of entries) {
    validateManifestVerification(entry);
    const artifactPath = await resolveRegularFile(
      releaseRoot,
      entry.artifact,
      `${entry.platform} artifact`,
    );
    const artifactInfo = await stat(artifactPath);
    assert(artifactInfo.size > 0, `${entry.platform} artifact is empty`);
    assert(
      artifactInfo.size === entry.byteLength,
      `${entry.platform} artifact byte length changed`,
    );
    assertSha(entry.sha256, `${entry.platform}.sha256`);
    assert(
      (await sha256File(artifactPath)) === entry.sha256,
      `${entry.platform} artifact SHA-256 mismatch`,
    );
    const evidencePath = await resolveRegularFile(
      releaseRoot,
      entry.evidence,
      `${entry.platform} verification evidence`,
    );
    assertSha(
      entry.evidenceSha256,
      `${entry.platform}.evidenceSha256`,
    );
    assert(
      (await sha256File(evidencePath)) === entry.evidenceSha256,
      `${entry.platform} verification evidence SHA-256 mismatch`,
    );
    const evidence = await readJson(
      evidencePath,
      `${entry.platform} verification evidence`,
    );
    validateEvidence(
      evidence,
      {
        platform: entry.platform,
        mode: entry.mode,
        verification: entry.verification,
        artifact: entry.artifact,
        evidence: entry.evidence,
      },
      common,
      {
        artifactByteLength: artifactInfo.size,
        artifactSha256: entry.sha256,
      },
    );
    validateManifestEvidenceMetadata(entry, evidence);
  }
  return manifest;
}

function validateReleaseHeader(value) {
  assert(
    typeof value.version === 'string' && /^\d+\.\d+\.\d+$/.test(value.version),
    'version must be semantic x.y.z',
  );
  assert(
    Number.isInteger(value.buildNumber) && value.buildNumber > 0,
    'buildNumber must be a positive integer',
  );
  return { version: value.version, buildNumber: value.buildNumber };
}

function validatePolicy(policy) {
  assert(isRecord(policy), 'releasePolicy must be an object');
  for (const [platform, mode] of Object.entries(EXPECTED_POLICY)) {
    assert(
      policy[platform] === mode,
      `releasePolicy.${platform} must be ${mode}`,
    );
  }
  assert(
    Object.keys(policy).length === Object.keys(EXPECTED_POLICY).length,
    'releasePolicy contains an unsupported platform',
  );
}

function validateEntries(rawEntries, options = {}) {
  assert(Array.isArray(rawEntries), 'entries must be an array');
  assert(rawEntries.length === 4, 'entries must contain exactly four platforms');
  const seen = new Set();
  return rawEntries.map((entry, index) => {
    assert(isRecord(entry), `entries[${index}] must be an object`);
    const platform = entry.platform;
    assert(platform in EXPECTED_POLICY, `entries[${index}].platform is unsupported`);
    assert(!seen.has(platform), `duplicate platform entry: ${platform}`);
    seen.add(platform);
    assert(
      entry.mode === EXPECTED_POLICY[platform],
      `${platform}.mode must be ${EXPECTED_POLICY[platform]}`,
    );
    assert(
      entry.verification === EXPECTED_VERIFICATION[platform],
      `${platform}.verification must be ${EXPECTED_VERIFICATION[platform]}`,
    );
    validateRelativePath(entry.artifact, `${platform}.artifact`);
    validateRelativePath(entry.evidence, `${platform}.evidence`);
    assert(
      path.extname(entry.artifact).toLowerCase() ===
        EXPECTED_EXTENSIONS[platform],
      `${platform} artifact must use ${EXPECTED_EXTENSIONS[platform]}`,
    );
    assert(
      path.basename(entry.artifact).includes(`-${options.version}`),
      `${platform} artifact filename must contain version ${options.version}`,
    );
    if (options.manifest) {
      assert(
        Number.isSafeInteger(entry.byteLength) && entry.byteLength > 0,
        `${platform}.byteLength must be positive`,
      );
    }
    return entry;
  });
}

async function validateAgainstPubspec(common) {
  const repositoryRoot = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '..',
  );
  const pubspecPath = path.join(repositoryRoot, 'apps', 'client', 'pubspec.yaml');
  const pubspec = await readFile(pubspecPath, 'utf8');
  const match = /^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m.exec(pubspec);
  assert(match, 'could not read version from apps/client/pubspec.yaml');
  assert(
    common.version === match[1] && common.buildNumber === Number(match[2]),
    `release version ${common.version}+${common.buildNumber} does not match pubspec ${match[1]}+${match[2]}`,
  );
}

function validateEvidence(evidence, entry, common, artifact) {
  assert(
    entry.verification === 'RUNTIME'
      ? evidence.verification === undefined || evidence.verification === 'RUNTIME'
      : evidence.verification === 'BUILD_ONLY',
    `${entry.platform} verification evidence type mismatch`,
  );
  assert(
    evidence.platform === entry.platform,
    `${entry.platform} verification evidence platform mismatch`,
  );
  assert(
    evidence.mode === entry.mode,
    `${entry.platform} verification evidence mode mismatch`,
  );
  assert(
    evidence.version === common.version &&
      evidence.buildNumber === common.buildNumber,
    `${entry.platform} verification evidence version mismatch`,
  );
  if (entry.verification === 'RUNTIME') {
    validateRuntimeEvidence(evidence, entry);
  } else {
    validateBuildEvidence(evidence, entry, artifact);
  }
  const checkedAt = Date.parse(evidence.checkedAt);
  assert(Number.isFinite(checkedAt), `${entry.platform}.checkedAt is invalid`);
}

function validateRuntimeEvidence(evidence, entry) {
  assert(
    evidence.format === RUNTIME_EVIDENCE_FORMAT,
    `${entry.platform} runtime evidence format is invalid`,
  );
  assert(evidence.launched === true, `${entry.platform} launch probe failed`);
  assert(
    evidence.firstFrameRendered === true,
    `${entry.platform} first-frame probe failed`,
  );
  assert(
    ALLOWED_RUNTIME_PROBES.has(evidence.probe),
    `${entry.platform} runtime evidence probe is unsupported`,
  );
  assert(
    Number.isInteger(evidence.firstFrameMillis) &&
      evidence.firstFrameMillis >= 0 &&
      evidence.firstFrameMillis <= 60000,
    `${entry.platform} firstFrameMillis must be within 0..60000`,
  );
}

function validateBuildEvidence(evidence, entry, artifact) {
  assert(
    entry.platform === 'android' && entry.mode === 'REAL',
    'BUILD_ONLY verification is restricted to the REAL Android artifact',
  );
  assert(
    evidence.format === BUILD_EVIDENCE_FORMAT,
    'android build evidence format is invalid',
  );
  assert(evidence.probe === BUILD_ONLY_PROBE, 'android build probe is invalid');
  assert(evidence.launched === false, 'android BUILD_ONLY evidence must not claim launch');
  assert(
    evidence.firstFrameRendered === false,
    'android BUILD_ONLY evidence must not claim a rendered frame',
  );
  assert(
    evidence.firstFrameMillis === null,
    'android BUILD_ONLY firstFrameMillis must be null',
  );
  assert(evidence.buildVerified === true, 'android build verification failed');
  assert(evidence.signatureVerified === true, 'android signature verification failed');
  assert(evidence.packageVerified === true, 'android package verification failed');
  assert(
    evidence.limitation === BUILD_ONLY_REASON,
    `android BUILD_ONLY limitation must be ${BUILD_ONLY_REASON}`,
  );
  assert(
    evidence.packageName === 'com.youkdonghun.sprache',
    'android packageName is invalid',
  );
  assert(
    Array.isArray(evidence.abis) &&
      evidence.abis.length === 3 &&
      ['arm64-v8a', 'armeabi-v7a', 'x86_64'].every((abi) =>
        evidence.abis.includes(abi),
      ),
    'android ABI evidence is incomplete',
  );
  assertSha(evidence.artifactSha256, 'android evidence artifactSha256');
  assert(
    evidence.artifactSha256 === artifact.artifactSha256,
    'android build evidence is bound to a different APK SHA-256',
  );
  assert(
    evidence.artifactByteLength === artifact.artifactByteLength,
    'android build evidence is bound to a different APK byte length',
  );
}

function validateManifestVerification(entry) {
  if (entry.verification === 'RUNTIME') {
    assert(entry.launched === true, `${entry.platform} was not launched`);
    assert(
      entry.firstFrameRendered === true,
      `${entry.platform} did not render a first frame`,
    );
    assert(
      Number.isInteger(entry.firstFrameMillis) &&
        entry.firstFrameMillis >= 0 &&
        entry.firstFrameMillis <= 60000,
      `${entry.platform}.firstFrameMillis must be within 0..60000`,
    );
    assert(
      ALLOWED_RUNTIME_PROBES.has(entry.probe),
      `${entry.platform}.probe is unsupported`,
    );
    for (const buildOnlyField of [
      'buildVerified',
      'signatureVerified',
      'packageVerified',
      'limitation',
      'packageName',
      'abis',
    ]) {
      assert(
        entry[buildOnlyField] === undefined,
        `${entry.platform}.${buildOnlyField} is BUILD_ONLY metadata`,
      );
    }
    return;
  }
  assert(entry.probe === BUILD_ONLY_PROBE, 'android manifest build probe is invalid');
  assert(entry.launched === false, 'android manifest must not claim launch');
  assert(
    entry.firstFrameRendered === false,
    'android manifest must not claim a rendered frame',
  );
  assert(entry.firstFrameMillis === null, 'android manifest firstFrameMillis must be null');
  assert(entry.buildVerified === true, 'android manifest build verification failed');
  assert(entry.signatureVerified === true, 'android manifest signature verification failed');
  assert(entry.packageVerified === true, 'android manifest package verification failed');
  assert(
    entry.limitation === BUILD_ONLY_REASON,
    'android manifest limitation is invalid',
  );
}

function validateManifestEvidenceMetadata(entry, evidence) {
  assert(
    evidence.probe === entry.probe &&
      evidence.launched === entry.launched &&
      evidence.firstFrameRendered === entry.firstFrameRendered &&
      new Date(evidence.checkedAt).toISOString() === entry.checkedAt,
    `${entry.platform} verification evidence metadata changed`,
  );
  if (entry.verification === 'RUNTIME') {
    assert(
      evidence.firstFrameMillis === entry.firstFrameMillis,
      `${entry.platform} first-frame evidence metadata changed`,
    );
    return;
  }
  assert(
    evidence.firstFrameMillis === entry.firstFrameMillis &&
      evidence.buildVerified === entry.buildVerified &&
      evidence.signatureVerified === entry.signatureVerified &&
      evidence.packageVerified === entry.packageVerified &&
      evidence.limitation === entry.limitation &&
      evidence.packageName === entry.packageName &&
      JSON.stringify(evidence.abis) === JSON.stringify(entry.abis),
    'android build evidence metadata changed',
  );
}

async function resolveRegularFile(root, relative, label) {
  validateRelativePath(relative, label);
  const candidate = path.resolve(root, relative);
  assertContained(root, candidate, label);
  const fileInfo = await lstat(candidate);
  assert(fileInfo.isFile(), `${label} is not a regular file`);
  assert(!fileInfo.isSymbolicLink(), `${label} must not be a symbolic link`);
  const realRoot = await realpath(root);
  const realCandidate = await realpath(candidate);
  assertContained(realRoot, realCandidate, label);
  return candidate;
}

function validateRelativePath(value, label) {
  assert(typeof value === 'string' && value.length > 0, `${label} is required`);
  assert(!path.isAbsolute(value), `${label} must be relative`);
  const normalized = normalizeRelative(value);
  assert(
    normalized !== '..' && !normalized.startsWith('../'),
    `${label} escapes the release root`,
  );
}

function assertContained(root, candidate, label) {
  const relative = path.relative(path.resolve(root), path.resolve(candidate));
  assert(
    relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative)),
    `${label} escapes the release root`,
  );
}

function normalizeRelative(value) {
  return path.normalize(value).split(path.sep).join('/');
}

async function sha256File(file) {
  return createHash('sha256').update(await readFile(file)).digest('hex');
}

async function readJson(file, label) {
  try {
    const parsed = JSON.parse(await readFile(file, 'utf8'));
    assert(isRecord(parsed), `${label} must contain a JSON object`);
    return parsed;
  } catch (error) {
    throw new Error(`Could not read ${label}: ${error.message}`, { cause: error });
  }
}

function assertSha(value, label) {
  assert(
    typeof value === 'string' && /^[0-9a-f]{64}$/.test(value),
    `${label} must be a lowercase SHA-256`,
  );
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

async function main() {
  const command = process.argv[2];
  if (command === 'create') {
    const specPath = argument('--spec');
    if (!specPath) throw new Error('create requires --spec <path>');
    const result = await createReleaseManifest({
      specPath,
      outputPath: argument('--out'),
      root: argument('--root'),
    });
    process.stdout.write(`Release manifest verified: ${result.outputPath}\n`);
    return;
  }
  if (command === 'verify') {
    const manifestPath = argument('--manifest');
    if (!manifestPath) throw new Error('verify requires --manifest <path>');
    await verifyReleaseManifest({
      manifestPath,
      root: argument('--root'),
    });
    process.stdout.write(`Release bundle verified: ${path.resolve(manifestPath)}\n`);
    return;
  }
  throw new Error(
    'Usage: node tool/release-bundle.mjs <create|verify> --spec/--manifest <path> [--root <directory>] [--out <path>]',
  );
}

if (
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url
) {
  main().catch((error) => {
    process.stderr.write(`Release bundle verification failed: ${error.message}\n`);
    process.exitCode = 1;
  });
}
