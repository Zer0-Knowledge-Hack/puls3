import assert from 'node:assert/strict';
import { promises as fs } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, it } from 'node:test';
import { inspect } from 'node:util';

import { Puls3ApiError, Puls3NetworkError } from '../src/errors.js';
import {
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
