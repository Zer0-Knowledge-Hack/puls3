import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { promises as fs } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { afterEach, beforeEach, describe, it } from 'node:test';
import { inspect } from 'node:util';

import { Puls3ApiError, Puls3NetworkError } from '../src/errors.js';
import {
  acrossProcesses,
  CliSession,
  defaultSessionFile,
  type RefreshCall,
  type RefreshedTokens,
} from '../src/session.js';
import { fakeFetch, ok } from './support.js';

const hour = 3_600_000;
const now = new Date('2026-11-24T12:00:00.000Z');

let dir: string;
let file: string;

beforeEach(async () => {
  dir = await fs.mkdtemp(join(tmpdir(), 'puls3-session-'));
  file = join(dir, 'puls3', 'node-session.json');
});

afterEach(async () => {
  await fs.rm(dir, { recursive: true, force: true });
});

describe('the cross-process session lock (#424)', () => {
  const lockDir = () => `${file}.lock.d`;
  const old = new Date(Date.now() - 5 * 60_000);

  /** A lock left by a program that died: its directory, five minutes old. */
  async function staleLock(): Promise<void> {
    await fs.mkdir(lockDir(), { recursive: true });
    await fs.writeFile(join(lockDir(), 'owner'), 'dead-program');
    await fs.utimes(join(lockDir(), 'owner'), old, old);
    await fs.utimes(lockDir(), old, old);
  }

  it('lets only one program take over a stale lock, even when several find it at once', async () => {
    await fs.mkdir(dirname(file), { recursive: true });
    await staleLock();
    const log = join(dir, 'log.txt');
    // The compiled module next to this compiled test (build-test/src/session.js).
    const session = new URL('../src/session.js', import.meta.url).href;
    const script = join(dir, 'holder.mjs');
    await fs.writeFile(
      script,
      [
        `import { appendFile } from 'node:fs/promises';`,
        `import { acrossProcesses } from ${JSON.stringify(session)};`,
        `const [file, log, id, start] = process.argv.slice(2);`,
        // All programs reach the stale lock at the same moment.
        `await new Promise((r) => setTimeout(r, Number(start) - Date.now()));`,
        `await acrossProcesses(file, async () => {`,
        `  await appendFile(log, 'in ' + id + '\\n');`,
        `  await new Promise((r) => setTimeout(r, 150));`,
        `  await appendFile(log, 'out ' + id + '\\n');`,
        `});`,
      ].join('\n'),
    );
    const start = String(Date.now() + 2_000);
    const programs = Array.from({ length: 6 }, (_, id) =>
      new Promise<number>((resolve, reject) => {
        const child = spawn(process.execPath, [script, file, log, String(id), start], { stdio: 'inherit' });
        child.on('error', reject);
        child.on('exit', (code) => resolve(code ?? 1));
      }),
    );
    assert.deepEqual(await Promise.all(programs), [0, 0, 0, 0, 0, 0]);

    const lines = (await fs.readFile(log, 'utf8')).trim().split('\n');
    assert.equal(lines.length, 12);
    for (let i = 0; i < lines.length; i += 2) {
      const [inside, id] = lines[i]!.split(' ');
      assert.equal(inside, 'in', `line ${i}: ${lines.join(' | ')}`);
      assert.equal(lines[i + 1], `out ${id}`, `two programs held the lock at once: ${lines.join(' | ')}`);
    }
  });

  it('never takes the lock from a holder that is still alive, however long it runs', async () => {
    await fs.mkdir(dirname(file), { recursive: true });
    const timing = { staleMs: 300, heartbeatMs: 50, waitMs: 5_000 };
    const events: string[] = [];
    const holder = acrossProcesses(
      file,
      async () => {
        events.push('a in');
        await new Promise((r) => setTimeout(r, 1_000));
        events.push('a out');
      },
      timing,
    );
    await new Promise((r) => setTimeout(r, 50));
    const waiter = acrossProcesses(file, async () => void events.push('b in'), timing);
    await Promise.all([holder, waiter]);
    assert.deepEqual(events, ['a in', 'a out', 'b in']);
  });

  it('a holder whose lock was taken over leaves the new owner’s lock in place', async () => {
    await fs.mkdir(dirname(file), { recursive: true });
    await acrossProcesses(file, async () => {
      // Another program took the lock over (as after a stale takeover).
      await fs.rm(lockDir(), { recursive: true, force: true });
      await fs.mkdir(lockDir());
      await fs.writeFile(join(lockDir(), 'owner'), 'another-program');
    });
    assert.equal(await fs.readFile(join(lockDir(), 'owner'), 'utf8'), 'another-program');
  });
});

/** A server that rotates `rt-N` to `rt-N+1` and gives `at-N+1`. */
function rotatingServer(): { refresh: RefreshCall; presented: string[] } {
  const presented: string[] = [];
  return {
    presented,
    refresh: async (token): Promise<RefreshedTokens> => {
      presented.push(token);
      const n = Number(token.split('-')[1]) + 1;
      return {
        accessToken: `at-${n}`,
        accessTokenExpiresAt: new Date(now.getTime() + hour),
        refreshToken: `rt-${n}`,
      };
    },
  };
}

async function saved(): Promise<Record<string, unknown>> {
  return JSON.parse(await fs.readFile(file, 'utf8')) as Record<string, unknown>;
}

describe('CliSession', () => {
  it('is null with neither a seed nor a saved session', async () => {
    assert.equal(await CliSession.load(file, { refresh: rotatingServer().refresh }), null);
  });

  it('seeds the file, refreshes on first use and saves the rotated token as 0600', async () => {
    const server = rotatingServer();
    const session = (await CliSession.load(file, { seed: 'rt-0', refresh: server.refresh, now: () => now }))!;

    assert.equal(await session.authorization(), 'Bearer at-1');

    assert.deepEqual(server.presented, ['rt-0']);
    assert.deepEqual(await saved(), {
      seed: 'rt-0',
      refreshToken: 'rt-1',
      accessToken: 'at-1',
      accessTokenExpiresAt: new Date(now.getTime() + hour).toISOString(),
    });
    if (process.platform !== 'win32') {
      assert.equal((await fs.stat(file)).mode & 0o777, 0o600);
    }
  });

  it('keeps a valid access token, and refreshes one about to expire', async () => {
    const server = rotatingServer();
    let clock = now;
    const session = (await CliSession.load(file, { seed: 'rt-0', refresh: server.refresh, now: () => clock }))!;

    await session.authorization();
    await session.authorization();
    assert.deepEqual(server.presented, ['rt-0']);

    clock = new Date(now.getTime() + hour - 10_000);
    assert.equal(await session.authorization(), 'Bearer at-2');
    assert.deepEqual(server.presented, ['rt-0', 'rt-1']);
  });

  it('presents each refresh token once when calls race', async () => {
    const server = rotatingServer();
    const session = (await CliSession.load(file, { seed: 'rt-0', refresh: server.refresh, now: () => now }))!;

    const headers = await Promise.all([
      session.authorization(),
      session.authorization(),
      session.refresh(true),
    ]);

    assert.equal(headers[0], 'Bearer at-1');
    assert.equal(new Set(server.presented).size, server.presented.length, 'no token presented twice');
  });

  it('takes the tokens another program rotated instead of reusing its own', async () => {
    const server = rotatingServer();
    const a = (await CliSession.load(file, { seed: 'rt-0', refresh: server.refresh, now: () => now }))!;
    const b = (await CliSession.load(file, { refresh: server.refresh, now: () => now }))!;

    await a.authorization();
    assert.equal(await b.authorization(), 'Bearer at-1');

    assert.deepEqual(server.presented, ['rt-0']);
  });

  it('resumes from the file after a restart', async () => {
    const server = rotatingServer();
    await (await CliSession.load(file, { seed: 'rt-0', refresh: server.refresh, now: () => now }))!.authorization();

    const later = new Date(now.getTime() + 2 * hour);
    const restarted = (await CliSession.load(file, { seed: 'rt-0', refresh: server.refresh, now: () => later }))!;

    assert.equal(await restarted.authorization(), 'Bearer at-2');
    assert.deepEqual(server.presented, ['rt-0', 'rt-1'], 'the old seed is not presented again');
  });

  it('a new seed replaces the saved session', async () => {
    const server = rotatingServer();
    await (await CliSession.load(file, { seed: 'rt-0', refresh: server.refresh, now: () => now }))!.authorization();

    const reseeded = (await CliSession.load(file, { seed: 'rt-10', refresh: server.refresh, now: () => now }))!;

    assert.equal(await reseeded.authorization(), 'Bearer at-11');
  });

  it('a refused session removes the file and stops refreshing', async () => {
    let calls = 0;
    const refresh: RefreshCall = async () => {
      calls++;
      throw new Puls3ApiError('RefreshTokenExpiredException', null, null);
    };
    const session = (await CliSession.load(file, { seed: 'rt-0', refresh, now: () => now }))!;

    assert.equal(await session.refresh(false), 'failedUnauthorized');
    assert.equal(session.isUsable, false);
    assert.equal(await session.authorization(), null);
    assert.equal(calls, 1);
    await assert.rejects(fs.stat(file), { code: 'ENOENT' });
  });

  it('an unreachable server keeps the session for the next try', async () => {
    let fail = true;
    const server = rotatingServer();
    const refresh: RefreshCall = async (token) => {
      if (fail) throw new Puls3NetworkError('Could not reach the puls3 server');
      return server.refresh(token);
    };
    const session = (await CliSession.load(file, { seed: 'rt-0', refresh, now: () => now }))!;

    assert.equal(await session.refresh(false), 'failedOther');
    assert.equal(session.isUsable, true);
    fail = false;
    assert.equal(await session.authorization(), 'Bearer at-1');
  });

  it('shows no token in toString, JSON or inspect', async () => {
    const session = (await CliSession.load(file, { seed: 'rt-secret-0', refresh: rotatingServer().refresh, now: () => now }))!;
    await session.authorization().catch(() => undefined);

    for (const text of [String(session), JSON.stringify({ session }), inspect(session, { showHidden: true, depth: 5 })]) {
      assert.doesNotMatch(text, /rt-|at-/, text);
    }
  });

  it('open() refreshes through jwtRefresh.refreshAccessToken, anonymously', async () => {
    const { fetch, sent } = fakeFetch(
      ok({
        authStrategy: 'jwt',
        token: 'at-1',
        tokenExpiresAt: new Date(Date.now() + hour).toISOString(),
        refreshToken: 'rt-1',
        authUserId: '00000000-0000-0000-0000-000000000000',
        scopeNames: [],
      }),
    );
    const session = (await CliSession.open('http://localhost:8080', {
      environment: { PULS3_NODE_SESSION_FILE: file, PULS3_REFRESH_TOKEN: 'rt-0' },
      fetch,
    }))!;

    assert.equal(await session.authorization(), 'Bearer at-1');
    assert.equal(sent[0]!.url, 'http://localhost:8080/jwtRefresh/refreshAccessToken');
    assert.deepEqual(sent[0]!.body, { refreshToken: 'rt-0' });
    assert.equal(sent[0]!.headers['authorization'], undefined);
  });

  it('open() treats a refused refresh token as the end of the session', async () => {
    const { fetch: refusing } = fakeFetch({
      status: 400,
      body: JSON.stringify({ className: 'serverpod_auth_core.RefreshTokenInvalidSecretException', data: {} }),
    });
    const session = (await CliSession.open('http://localhost:8080', {
      environment: { PULS3_NODE_SESSION_FILE: file, PULS3_REFRESH_TOKEN: 'rt-0' },
      fetch: refusing,
    }))!;

    assert.equal(await session.refresh(true), 'failedUnauthorized');
    assert.equal(session.isUsable, false);
  });
});

describe('defaultSessionFile', () => {
  it('prefers PULS3_NODE_SESSION_FILE, then XDG_CONFIG_HOME, then HOME', () => {
    assert.equal(defaultSessionFile({ PULS3_NODE_SESSION_FILE: '/x/s.json', HOME: '/h' }, 'linux'), '/x/s.json');
    assert.equal(defaultSessionFile({ XDG_CONFIG_HOME: '/c', HOME: '/h' }, 'linux'), join('/c', 'puls3', 'node-session.json'));
    assert.equal(defaultSessionFile({ HOME: '/h' }, 'linux'), join('/h', '.config', 'puls3', 'node-session.json'));
    assert.equal(defaultSessionFile({}, 'linux'), null);
  });

  it('is not the Dart CLI session file', () => {
    assert.doesNotMatch(defaultSessionFile({ HOME: '/h' }, 'linux')!, /[/\\]session\.json$/);
    assert.equal(defaultSessionFile({ PULS3_SESSION_FILE: '/dart/session.json' }, 'linux'), null);
  });

  it('uses APPDATA on Windows', () => {
    assert.equal(defaultSessionFile({ APPDATA: 'C:\\U\\AppData' }, 'win32'), join('C:\\U\\AppData', 'puls3', 'node-session.json'));
  });
});
