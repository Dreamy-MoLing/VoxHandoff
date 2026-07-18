import { readFile, readdir, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(scriptDir, "..");

const excludedDirectories = new Set([
  ".git",
  ".codebase-memory",
  "node_modules",
  "dist",
  "coverage",
  "docs",
]);

const requiredFiles = [
  "AGENTS.md",
  "README.md",
  "package.json",
  "package-lock.json",
  "spec/README.md",
  "spec/PRODUCT.md",
  "spec/ARCHITECTURE.md",
  "spec/DELIVERY.md",
];

const textExtensions = new Set([
  ".cjs",
  ".css",
  ".dart",
  ".html",
  ".js",
  ".json",
  ".jsonl",
  ".md",
  ".mjs",
  ".proto",
  ".py",
  ".sh",
  ".sql",
  ".sse",
  ".toml",
  ".ts",
  ".tsx",
  ".yaml",
  ".yml",
]);

const secretPatterns = [
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/u,
  /\bAKIA[0-9A-Z]{16}\b/u,
  /\bgh[pousr]_[A-Za-z0-9]{20,}\b/u,
  /\bsk-[A-Za-z0-9]{20,}\b/u,
];

const errors = [];

async function exists(relativePath) {
  try {
    await stat(path.join(root, relativePath));
    return true;
  } catch (error) {
    if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") {
      return false;
    }
    throw error;
  }
}

async function collectFiles(directory, prefix = "") {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    if (entry.isDirectory() && excludedDirectories.has(entry.name)) {
      continue;
    }

    const relativePath = path.posix.join(prefix, entry.name);
    const absolutePath = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      files.push(...(await collectFiles(absolutePath, relativePath)));
    } else if (entry.isFile()) {
      files.push(relativePath);
    }
  }

  return files;
}

function isTextFile(relativePath) {
  const basename = path.posix.basename(relativePath);
  return basename === ".gitignore" || textExtensions.has(path.posix.extname(relativePath));
}

function checkText(relativePath, content) {
  if (content.includes("\r")) {
    errors.push(`${relativePath}: use LF line endings`);
  }

  const lines = content.split("\n");
  for (let index = 0; index < lines.length; index += 1) {
    if (/[ \t]+$/u.test(lines[index])) {
      errors.push(`${relativePath}:${index + 1}: trailing whitespace`);
    }
  }

  if (path.posix.basename(relativePath).startsWith(".env")) {
    return;
  }

  if (secretPatterns.some((pattern) => pattern.test(content))) {
    errors.push(`${relativePath}: resembles a committed secret`);
  }
}

function checkWorkflow(relativePath, content) {
  if (!relativePath.startsWith(".github/workflows/")) {
    return;
  }

  if (/^\s*pull_request_target\s*:/mu.test(content)) {
    errors.push(`${relativePath}: pull_request_target is forbidden for untrusted changes`);
  }

  if (!/^permissions:\n  contents: read$/mu.test(content)) {
    errors.push(`${relativePath}: set top-level GITHUB_TOKEN permissions to contents: read`);
  }

  for (const match of content.matchAll(/^\s*uses:\s+([^\s#]+)/gmu)) {
    const reference = match[1];
    if (!reference.startsWith("./") && !/@[0-9a-f]{40}$/u.test(reference)) {
      errors.push(`${relativePath}: action is not pinned to a full commit SHA: ${reference}`);
    }
  }

  if (/actions\/checkout@/u.test(content) && !/^\s*persist-credentials:\s+false$/mu.test(content)) {
    errors.push(`${relativePath}: checkout must disable persisted credentials`);
  }
}

async function checkMarkdownLinks(relativePath, content) {
  const linkPattern = /\[[^\]]*\]\(([^)]+)\)/gu;

  for (const match of content.matchAll(linkPattern)) {
    let target = match[1].trim();
    if (target.startsWith("<") && target.endsWith(">")) {
      target = target.slice(1, -1);
    }

    if (/^(?:https?:|mailto:|#)/u.test(target)) {
      continue;
    }

    const withoutAnchor = target.split("#", 1)[0];
    if (withoutAnchor.length === 0) {
      continue;
    }

    const resolved = path.resolve(root, path.posix.dirname(relativePath), withoutAnchor);
    const relativeResolved = path.relative(root, resolved);
    if (relativeResolved.startsWith("..") || path.isAbsolute(relativeResolved)) {
      errors.push(`${relativePath}: local link escapes repository: ${target}`);
    } else if (!(await exists(relativeResolved))) {
      errors.push(`${relativePath}: broken local link: ${target}`);
    }
  }
}

async function checkWorkspaceVersions() {
  const rootPackage = JSON.parse(await readFile(path.join(root, "package.json"), "utf8"));
  const expectedVersion = rootPackage.version;
  const packageFiles = (await collectFiles(root)).filter(
    (relativePath) => relativePath !== "package.json" && relativePath.endsWith("/package.json"),
  );

  for (const relativePath of packageFiles) {
    const manifest = JSON.parse(await readFile(path.join(root, relativePath), "utf8"));
    if (manifest.version !== expectedVersion) {
      errors.push(
        `${relativePath}: version ${String(manifest.version)} does not match root ${String(expectedVersion)}`,
      );
    }
  }
}

for (const relativePath of requiredFiles) {
  if (!(await exists(relativePath))) {
    errors.push(`${relativePath}: required repository baseline file is missing`);
  }
}

const files = await collectFiles(root);
for (const relativePath of files) {
  if (!isTextFile(relativePath)) {
    continue;
  }

  const content = await readFile(path.join(root, relativePath), "utf8");
  checkText(relativePath, content);
  checkWorkflow(relativePath, content);
  if (relativePath.endsWith(".md")) {
    await checkMarkdownLinks(relativePath, content);
  }
}

await checkWorkspaceVersions();

if (errors.length > 0) {
  for (const error of errors) {
    console.error(error);
  }
  process.exitCode = 1;
} else {
  console.log(`repository consistency: ok (${files.length} files scanned)`);
}
