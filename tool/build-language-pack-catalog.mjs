import { createHash } from 'node:crypto';
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const supportedLanguages = new Set(['ko', 'en', 'ja', 'de', 'fr', 'es', 'zh-Hans']);
const packIdPattern = /^[a-z0-9][a-z0-9._-]{0,79}$/;
const maxPackBytes = 20 * 1024 * 1024;
const maxItems = 20_000;

export async function buildLanguagePackCatalog(repositoryRoot) {
  const root = resolve(repositoryRoot);
  const packsDirectory = join(root, 'language-packs', 'packs');
  const names = (await readdir(packsDirectory, { withFileTypes: true }))
    .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith('.json'))
    .map((entry) => entry.name)
    .sort((left, right) => left.localeCompare(right, 'en'));

  const packs = [];
  const ids = new Set();
  for (const name of names) {
    const absolutePath = join(packsDirectory, name);
    const bytes = await readFile(absolutePath);
    if (bytes.length === 0 || bytes.length > maxPackBytes) {
      throw new Error(`${name}: pack size must be between 1 byte and 20MB.`);
    }
    let value;
    try {
      value = JSON.parse(bytes.toString('utf8'));
    } catch (error) {
      throw new Error(`${name}: invalid UTF-8 JSON (${error.message}).`);
    }
    validatePack(value, name);
    if (ids.has(value.id)) {
      throw new Error(`${name}: duplicate pack id ${value.id}.`);
    }
    ids.add(value.id);
    packs.push({
      id: value.id,
      title: value.title,
      description: value.description,
      language: value.language,
      version: value.version,
      revision: value.revision,
      publishedAt: new Date(value.publishedAt).toISOString(),
      license: value.license,
      attribution: value.attribution,
      path: `packs/${name}`,
      itemCount: value.items.length,
      sizeBytes: bytes.length,
      sha256: createHash('sha256').update(bytes).digest('hex'),
    });
  }
  packs.sort((left, right) => {
    const language = left.language.localeCompare(right.language, 'en');
    return language || left.title.localeCompare(right.title, 'ko');
  });
  const updatedAt = packs.length === 0
    ? null
    : packs
      .map((pack) => pack.publishedAt)
      .sort()
      .at(-1);
  return { schemaVersion: 1, updatedAt, packs };
}

export function validatePack(value, fileName = 'language-pack.json') {
  if (!isObject(value)) throw new Error(`${fileName}: root must be an object.`);
  if (value.schemaVersion !== 1) {
    throw new Error(`${fileName}: schemaVersion must be 1.`);
  }
  requireString(value.id, 'id', fileName, 80);
  if (!packIdPattern.test(value.id)) {
    throw new Error(`${fileName}: id must use lowercase letters, numbers, dot, underscore, or hyphen.`);
  }
  requireString(value.title, 'title', fileName, 80);
  requireString(value.description, 'description', fileName, 240);
  requireString(value.language, 'language', fileName, 16);
  if (!supportedLanguages.has(value.language)) {
    throw new Error(`${fileName}: unsupported language ${value.language}.`);
  }
  requireString(value.version, 'version', fileName, 40);
  requireInteger(value.revision, 'revision', fileName, 1);
  requireString(value.publishedAt, 'publishedAt', fileName, 60);
  if (Number.isNaN(Date.parse(value.publishedAt))) {
    throw new Error(`${fileName}: publishedAt must be an ISO 8601 date.`);
  }
  requireString(value.license, 'license', fileName, 120);
  requireString(value.attribution, 'attribution', fileName, 500);
  if (!Array.isArray(value.items) || value.items.length < 1 || value.items.length > maxItems) {
    throw new Error(`${fileName}: items must contain 1 to ${maxItems} rows.`);
  }
  const ids = new Set();
  value.items.forEach((item, index) => {
    if (!isObject(item)) throw new Error(`${fileName}: item ${index + 1} must be an object.`);
    requireString(item.id, `items[${index}].id`, fileName, 160);
    if (ids.has(item.id)) throw new Error(`${fileName}: duplicate item id ${item.id}.`);
    ids.add(item.id);
    requireString(item.type, `items[${index}].type`, fileName, 16);
    if (item.type !== 'word' && item.type !== 'sentence') {
      throw new Error(`${fileName}: item ${index + 1} type must be word or sentence.`);
    }
    requireString(item.term, `items[${index}].term`, fileName, 20_000);
    requireString(item.meaning, `items[${index}].meaning`, fileName, 20_000);
    if (item.language != null && item.language !== value.language) {
      throw new Error(`${fileName}: item ${index + 1} language must match the pack.`);
    }
    if (item.type === 'sentence') {
      requireString(
        item.sentence_tokens,
        `items[${index}].sentence_tokens`,
        fileName,
        20_000,
      );
      if (!item.sentence_tokens.includes('|')) {
        throw new Error(`${fileName}: sentence item ${index + 1} needs explicit | tokens.`);
      }
    }
  });
}

export function serializeLanguagePackCatalog(catalog) {
  return `${JSON.stringify(catalog, null, 2)}\n`;
}

function isObject(value) {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function requireString(value, field, fileName, maxLength) {
  if (typeof value !== 'string' || value.trim() === '' || [...value].length > maxLength) {
    throw new Error(`${fileName}: ${field} must be a non-empty string up to ${maxLength} characters.`);
  }
}

function requireInteger(value, field, fileName, minimum) {
  if (!Number.isInteger(value) || value < minimum) {
    throw new Error(`${fileName}: ${field} must be an integer >= ${minimum}.`);
  }
}

async function main() {
  const scriptPath = fileURLToPath(import.meta.url);
  const repositoryRoot = resolve(dirname(scriptPath), '..');
  const catalogPath = join(repositoryRoot, 'language-packs', 'catalog.json');
  const expected = serializeLanguagePackCatalog(
    await buildLanguagePackCatalog(repositoryRoot),
  );
  if (process.argv.includes('--check')) {
    const current = await readFile(catalogPath, 'utf8');
    if (current !== expected) {
      throw new Error(
        `${relative(repositoryRoot, catalogPath)} is stale. Run node tool/build-language-pack-catalog.mjs.`,
      );
    }
    process.stdout.write('Language-pack catalog is valid and current.\n');
    return;
  }
  await writeFile(catalogPath, expected, 'utf8');
  process.stdout.write(`Updated ${relative(repositoryRoot, catalogPath)}.\n`);
}

if (resolve(process.argv[1] ?? '') === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
