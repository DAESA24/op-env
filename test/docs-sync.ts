/**
 * docs-sync — validates documentation matches code
 * Run: bun test/docs-sync.ts
 */

import { readFileSync } from "fs";

const OP_ENV = readFileSync("bin/op-env", "utf-8");
const README = readFileSync("README.md", "utf-8");
const CHANGELOG = readFileSync("CHANGELOG.md", "utf-8");
const VERSION = readFileSync("version.txt", "utf-8").trim();

let tests = 0;
let failures = 0;

function assert(condition: boolean, message: string) {
  tests++;
  if (!condition) {
    console.error(`FAIL: ${message}`);
    failures++;
  }
}

// --- Test 1: Every flag in bin/op-env has a row in README features table ---

// Extract flags from case statement (lines like "    --check)" or "    -q|--quiet)")
const casePattern = /^\s+([-\w|]+)\)$/gm;
const scriptFlags = new Set<string>();
let match: RegExpExecArray | null;
while ((match = casePattern.exec(OP_ENV)) !== null) {
  const raw = match[1];
  // Split on | for combined flags like "-q|--quiet"
  for (const flag of raw.split("|")) {
    const cleaned = flag.trim();
    // Only include actual flags (start with -)
    if (cleaned.startsWith("-")) {
      scriptFlags.add(cleaned);
    }
  }
}

// Extract flags mentioned in README features table rows
const readmeLines = README.split("\n");
const featureRows = readmeLines.filter(
  (line) => line.startsWith("|") && line.includes("`") && !line.includes("Feature")
);

for (const flag of scriptFlags) {
  // Skip *) which is the default case
  if (flag === "*") continue;
  const documented = featureRows.some((row) => row.includes(flag));
  assert(documented, `${flag} is in bin/op-env case statement but not in README features table`);
}

// --- Test 2: version.txt is not hardcoded in script ---

assert(
  OP_ENV.includes('cat "$SCRIPT_DIR/../version.txt"'),
  "bin/op-env reads version from version.txt (not hardcoded)"
);

// --- Test 3: Script --version output would reference VERSION variable ---

assert(
  OP_ENV.includes('echo "op-env $VERSION"'),
  "--version output uses $VERSION variable"
);

// --- Test 4: CHANGELOG mentions the current version ---

assert(
  CHANGELOG.includes(VERSION),
  `CHANGELOG.md does not mention current version ${VERSION}`
);

// --- Test 5: Help text references $VERSION ---

assert(
  OP_ENV.includes("op-env $VERSION"),
  "Help text includes $VERSION reference"
);

// --- Test 6: version.txt format is valid semver ---

const semverPattern = /^\d+\.\d+\.\d+$/;
assert(
  semverPattern.test(VERSION),
  `version.txt content "${VERSION}" is not valid semver`
);

// --- Results ---

if (failures > 0) {
  console.error(`\nDocs-sync: ${tests - failures}/${tests} passed (${failures} failure(s))`);
  process.exit(1);
} else {
  console.log(`Docs-sync: ${tests}/${tests} checks passed`);
}
