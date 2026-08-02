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

const SPEC_FORMAT = 'sprache-release-spec-v1';
const MANIFEST_FORMAT = 'sprache-release-manifest-v1';
const EVIDENCE_FORMAT = 'sprache-runtime-evidence-v1';
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
const ALLOWED_PROBES = new Set([
  'native-runtime',
  'simulator-runtime',
  'flutter-first-frame',
]);

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
      entry.runtimeEvidence,
      `${entry.platform} runtime evidence`,
    );
    const evidence = await readJson(
      evidencePath,
      `${entry.platform} runtime evidence`,
    );
    validateRuntimeEvidence(evidence, entry, common);
    const artifactInfo = await stat(artifactPath);
    manifestEntries.push({
      platform: entry.platform,
      mode: entry.mode,
      artifact: normalizeRelative(entry.artifact),
      byteLength: artifactInfo.size,
      sha256: await sha256File(artifactPath),
      runtimeEvidence: normalizeRelative(entry.runtimeEvidence),
      runtimeEvidenceSha256: await sha256File(evidencePath),
      runtimeProbe: evidence.probe,
      launched: true,
      firstFrameRendered: true,
      firstFrameMillis: evidence.firstFrameMillis,
      checkedAt: new Date(evidence.checkedAt).toISOString(),
    });
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
      ALLOWED_PROBES.has(entry.runtimeProbe),
      `${entry.platform}.runtimeProbe is unsupported`,
    );
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
      entry.runtimeEvidence,
      `${entry.platform} runtime evidence`,
    );
    assertSha(
      entry.runtimeEvidenceSha256,
      `${entry.platform}.runtimeEvidenceSha256`,
    );
    assert(
      (await sha256File(evidencePath)) === entry.runtimeEvidenceSha256,
      `${entry.platform} runtime evidence SHA-256 mismatch`,
    );
    const evidence = await readJson(
      evidencePath,
      `${entry.platform} runtime evidence`,
    );
    validateRuntimeEvidence(
      evidence,
      {
        platform: entry.platform,
        mode: entry.mode,
        artifact: entry.artifact,
        runtimeEvidence: entry.runtimeEvidence,
      },
      common,
    );
    assert(
      evidence.probe === entry.runtimeProbe &&
        evidence.firstFrameMillis === entry.firstFrameMillis &&
        new Date(evidence.checkedAt).toISOString() === entry.checkedAt,
      `${entry.platform} runtime evidence metadata changed`,
    );
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
    validateRelativePath(entry.artifact, `${platform}.artifact`);
    validateRelativePath(
      entry.runtimeEvidence,
      `${platform}.runtimeEvidence`,
    );
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

function validateRuntimeEvidence(evidence, entry, common) {
  assert(
    evidence.format === EVIDENCE_FORMAT,
    `${entry.platform} runtime evidence format is invalid`,
  );
  assert(
    evidence.platform === entry.platform,
    `${entry.platform} runtime evidence platform mismatch`,
  );
  assert(
    evidence.mode === entry.mode,
    `${entry.platform} runtime evidence mode mismatch`,
  );
  assert(
    evidence.version === common.version &&
      evidence.buildNumber === common.buildNumber,
    `${entry.platform} runtime evidence version mismatch`,
  );
  assert(evidence.launched === true, `${entry.platform} launch probe failed`);
  assert(
    evidence.firstFrameRendered === true,
    `${entry.platform} first-frame probe failed`,
  );
  assert(
    ALLOWED_PROBES.has(evidence.probe),
    `${entry.platform} runtime evidence probe is unsupported`,
  );
  assert(
    Number.isInteger(evidence.firstFrameMillis) &&
      evidence.firstFrameMillis >= 0 &&
      evidence.firstFrameMillis <= 60000,
    `${entry.platform} firstFrameMillis must be within 0..60000`,
  );
  const checkedAt = Date.parse(evidence.checkedAt);
  assert(Number.isFinite(checkedAt), `${entry.platform}.checkedAt is invalid`);
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
