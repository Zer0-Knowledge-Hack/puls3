import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  Puls3ApiError,
  Puls3HttpError,
  Puls3NetworkError,
  Puls3ProtocolError,
} from '../src/errors.js';
import {
  HttpTransport,
  normalizeApiUrl,
  type AuthProvider,
  type RefreshResult,
} from '../src/transport.js';
import { apiException, fakeFetch, ok } from './support.js';

const api = 'http://localhost:8080/';

class FakeAuth implements AuthProvider {
  refreshes: boolean[] = [];
  constructor(
    private tokens: string[],
    private refreshResult: RefreshResult = 'success',
  ) {}
  async authorization() {
    return `Bearer ${this.tokens[0]}`;
  }
  async refresh(force: boolean) {
    this.refreshes.push(force);
    if (this.refreshResult === 'success') this.tokens.shift();
    return this.refreshResult;
  }
}

describe('HttpTransport', () => {
  it('posts the named arguments as JSON to <api><endpoint>/<method>', async () => {
    const { fetch, sent } = fakeFetch(ok({ hireId: 1 }));
    const transport = new HttpTransport(api, { fetch, auth: new FakeAuth(['t1']) });

    const result = await transport.call('hire', 'getHire', { hireId: 7, consumer: 'G' });

    assert.deepEqual(result, { hireId: 1 });
    assert.equal(sent.length, 1);
    assert.equal(sent[0]!.url, 'http://localhost:8080/hire/getHire');
    assert.deepEqual(sent[0]!.body, { hireId: 7, consumer: 'G' });
    assert.equal(sent[0]!.headers['content-type'], 'application/json; charset=utf-8');
    assert.equal(sent[0]!.headers['authorization'], 'Bearer t1');
  });

  it('sends a left-out argument as null, as the Dart client does', async () => {
    const { fetch, sent } = fakeFetch(ok(null));
    const transport = new HttpTransport(api, { fetch });

    await transport.call('hire', 'createHire', { reserve: undefined, other: null });

    assert.deepEqual(sent[0]!.body, { reserve: null, other: null });
  });

  it('sends no Authorization on an anonymous call', async () => {
    const { fetch, sent } = fakeFetch(ok([]));
    const auth = new FakeAuth(['t1']);
    const transport = new HttpTransport(api, { fetch, auth });

    await transport.call('agent', 'list', {}, { authenticated: false });

    assert.equal(sent[0]!.headers['authorization'], undefined);
    assert.deepEqual(auth.refreshes, []);
  });

  it('reads an empty 200 as null', async () => {
    const { fetch } = fakeFetch({ status: 200, body: '' });
    assert.equal(await new HttpTransport(api, { fetch }).call('a', 'b', {}), null);
  });

  it('reports a 200 that is not JSON as Puls3ProtocolError, not a raw SyntaxError (#424)', async () => {
    const { fetch } = fakeFetch({ status: 200, body: '<html>maintenance</html>' });
    await assert.rejects(new HttpTransport(api, { fetch }).call('a', 'b', {}), (e: unknown) => {
      assert.ok(e instanceof Puls3ProtocolError, `expected Puls3ProtocolError, got ${String(e)}`);
      return true;
    });
  });

  it('turns a Puls3ApiException into a Puls3ApiError with its code and details', async () => {
    const { fetch } = fakeFetch(
      apiException('InvalidHireTransition', 'hire 4 is open', { purpose: 'complete' }),
    );
    const transport = new HttpTransport(api, { fetch });

    await assert.rejects(transport.call('hire', 'prepareComplete', { hireId: 4 }), (error) => {
      assert.ok(error instanceof Puls3ApiError);
      assert.equal(error.code, 'InvalidHireTransition');
      assert.equal(error.message, 'hire 4 is open');
      assert.deepEqual(error.details, { purpose: 'complete' });
      return true;
    });
  });

  it('names another typed exception by its class, without the module', async () => {
    const { fetch } = fakeFetch(
      {
        status: 400,
        body: JSON.stringify({
          className: 'AgentUnavailable',
          data: { agentId: 30 },
        }),
      },
      {
        status: 400,
        body: JSON.stringify({
          className: 'serverpod_auth_core.RefreshTokenExpiredException',
          data: {},
        }),
      },
    );
    const transport = new HttpTransport(api, { fetch });

    await assert.rejects(transport.call('hire', 'createHire', {}), (error) => {
      assert.ok(error instanceof Puls3ApiError);
      assert.equal(error.code, 'AgentUnavailable');
      assert.deepEqual(error.details, { agentId: '30' });
      return true;
    });
    await assert.rejects(transport.call('jwtRefresh', 'refreshAccessToken', {}), {
      name: 'Puls3ApiError',
      code: 'RefreshTokenExpiredException',
      details: null,
    });
  });

  it('keeps any other status as a Puls3HttpError', async () => {
    const { fetch } = fakeFetch(
      { status: 400, body: 'Missing required query parameter: hireId' },
      { status: 404, body: '' },
      { status: 500, body: 'stack trace' },
    );
    const transport = new HttpTransport(api, { fetch });

    await assert.rejects(transport.call('hire', 'getHire', {}), {
      name: 'Puls3HttpError',
      status: 400,
      message: 'Missing required query parameter: hireId',
    });
    await assert.rejects(transport.call('nope', 'x', {}), { status: 404 });
    await assert.rejects(transport.call('hire', 'getHire', {}), (error) => {
      assert.ok(error instanceof Puls3HttpError);
      assert.equal(error.message, 'The server answered HTTP 500', 'no server body');
      return true;
    });
  });

  it('refreshes once after a 401 and retries with the new token', async () => {
    const { fetch, sent } = fakeFetch({ status: 401, body: '' }, ok(true));
    const auth = new FakeAuth(['old', 'new']);
    const transport = new HttpTransport(api, { fetch, auth });

    assert.equal(await transport.call('studio', 'listDrafts', {}), true);

    assert.deepEqual(auth.refreshes, [true]);
    assert.deepEqual(
      sent.map((r) => r.headers['authorization']),
      ['Bearer old', 'Bearer new'],
    );
  });

  it('does not retry when the refresh fails, and reports the 401', async () => {
    const { fetch, sent } = fakeFetch({ status: 401, body: '' });
    const auth = new FakeAuth(['old'], 'failedUnauthorized');
    const transport = new HttpTransport(api, { fetch, auth });

    await assert.rejects(transport.call('studio', 'listDrafts', {}), { status: 401 });
    assert.equal(sent.length, 1);
  });

  it('reports an unreachable server as Puls3NetworkError, without the URL or body', async () => {
    const failing = (async () => {
      throw new TypeError('fetch failed: secret-token');
    }) as typeof fetch;
    const transport = new HttpTransport(api, { fetch: failing });

    await assert.rejects(transport.call('hire', 'getHire', { token: 'x' }), (error) => {
      assert.ok(error instanceof Puls3NetworkError);
      assert.equal(error.message, 'Could not reach the puls3 server');
      return true;
    });
  });
});

describe('normalizeApiUrl', () => {
  it('adds the trailing slash the endpoint paths need', () => {
    assert.equal(normalizeApiUrl('https://api.example.com'), 'https://api.example.com/');
    assert.equal(normalizeApiUrl('https://api.example.com/v1'), 'https://api.example.com/v1/');
    assert.equal(normalizeApiUrl('http://localhost:8080/'), 'http://localhost:8080/');
  });

  it('refuses what is not an absolute http or https URL, or has a query', () => {
    for (const bad of ['localhost:8080', '/api', 'ftp://x.org/', 'https://x.org/?a=1', 'https://x.org/#f', '']) {
      assert.throws(() => normalizeApiUrl(bad), TypeError, bad);
    }
  });
});
