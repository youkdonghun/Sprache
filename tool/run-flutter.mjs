import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, "..");
const clientRoot = join(repositoryRoot, "apps", "client");
const isWindows = process.platform === "win32";
const executableName = isWindows ? "flutter.bat" : "flutter";

const candidates = [
  process.env.FLUTTER_PATH,
  isWindows && process.env.LOCALAPPDATA
    ? join(
        process.env.LOCALAPPDATA,
        "Programs",
        "flutter",
        "bin",
        "flutter.bat",
      )
    : undefined,
].filter(Boolean);

const flutterExecutable =
  candidates.find((candidate) => existsSync(candidate)) ?? executableName;
const result = spawnSync(flutterExecutable, process.argv.slice(2), {
  cwd: clientRoot,
  env: process.env,
  shell: isWindows,
  stdio: "inherit",
  windowsHide: true,
});

if (result.error) {
  console.error(
    `Flutter 실행 파일을 시작하지 못했습니다: ${result.error.message}`,
  );
  console.error(
    "FLUTTER_PATH를 flutter 실행 파일의 절대 경로로 지정해 주세요.",
  );
  process.exit(1);
}

process.exit(result.status ?? 1);
