// Runs the compiled tests (build-test/test/*.test.js) with `node --test`.
//
// The files are listed here instead of passing a glob, because `node --test`
// expands globs only from Node 21, and `engines` allows Node 20. A directory
// argument is no way out either: Node 20 also runs the helpers in `test/` as
// test files, and Node 22 and later refuse a directory (#424).
import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { join } from 'node:path';

const dir = join('build-test', 'test');
const files = readdirSync(dir)
  .filter((name) => name.endsWith('.test.js'))
  .sort()
  .map((name) => join(dir, name));
if (files.length === 0) {
  console.error(`No compiled tests in ${dir}. Run tsc -p tsconfig.test.json first.`);
  process.exit(1);
}
const run = spawnSync(process.execPath, ['--test', ...files], { stdio: 'inherit' });
process.exit(run.status ?? 1);
