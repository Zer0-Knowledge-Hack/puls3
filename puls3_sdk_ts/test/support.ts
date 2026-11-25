import type { Transport } from '../src/transport.js';

export interface SentRequest {
  url: string;
  headers: Record<string, string>;
  body: unknown;
}

export interface FakeAnswer {
  status: number;
  body: string;
}

/**
 * A `fetch` that records each request and answers from [answers], in order.
 * The last answer repeats.
 */
export function fakeFetch(...answers: FakeAnswer[]): {
  fetch: typeof fetch;
  sent: SentRequest[];
} {
  const sent: SentRequest[] = [];
  let next = 0;
  const fetchImpl = (async (input: string | URL | Request, init?: RequestInit) => {
    const headers: Record<string, string> = {};
    new Headers(init?.headers).forEach((value, key) => {
      headers[key] = value;
    });
    sent.push({
      url: String(input),
      headers,
      body: JSON.parse(String(init?.body)) as unknown,
    });
    const answer = answers[Math.min(next++, answers.length - 1)]!;
    return new Response(answer.body, { status: answer.status });
  }) as typeof fetch;
  return { fetch: fetchImpl, sent };
}

export const ok = (value: unknown): FakeAnswer => ({
  status: 200,
  body: JSON.stringify(value),
});

export const apiException = (
  code: string,
  message: string | null = null,
  details: Record<string, string> | null = null,
): FakeAnswer => ({
  status: 400,
  body: JSON.stringify({
    className: 'Puls3ApiException',
    data: { __className__: 'Puls3ApiException', code, message, details },
  }),
});

export interface Call {
  endpoint: string;
  method: string;
  args: Readonly<Record<string, unknown>>;
  authenticated: boolean;
}

/** A [Transport] that records calls and answers with [answer]. */
export function fakeTransport(answer: (call: Call) => unknown): {
  transport: Transport;
  calls: Call[];
} {
  const calls: Call[] = [];
  return {
    calls,
    transport: {
      async call(endpoint, method, args, options) {
        const call = { endpoint, method, args, authenticated: options?.authenticated !== false };
        calls.push(call);
        return answer(call);
      },
    },
  };
}

export const wallet = 'GBGBQI7OXLGMD3PO3AMFNMXFJ3FYBRVMHXQXM4V6KKG4OF5V4HBOCKIF';

export const agentJson = {
  id: 'agt-001',
  registryId: 30,
  name: 'Soroban Pre-Audit',
  description: 'Reviews a Soroban contract before an audit.',
  skills: ['security'],
  priceUsdcStroops: 5_000_000,
  wallet: 'GDQHKMYJLDOMS5YDOS3MQ2XRTCSKK3VBUYHJAIHR4H7FSPETQCOTNFBB',
  model: 'workers-ai',
  rating: 4.5,
  paidHireCount: 3,
  hireable: true,
};

export const hireJson = {
  id: 21,
  agentId: 30,
  consumer: wallet,
  price: 5_000_000,
  manifestVersion: 1,
  status: null,
  paymentTransaction: null,
  runtimeStatus: null,
  failureReason: null,
  rejectedFrom: null,
  feedbackReference: null,
  subcontractReserve: 0,
  allowRelatedParty: true,
  parentHireId: null,
};

export const preparedJson = (purpose: string) => ({
  preparationId: `prep-${purpose}`,
  purpose,
  signer: wallet,
  networkPassphrase: 'Test SDF Network ; September 2015',
  unsignedTransactionXdr: 'AAAA',
  authorizationEntryXdr: null,
  transaction: 'ab'.repeat(32),
  signatureExpirationLedger: null,
  expiresAt: '2026-11-24T12:15:00.000Z',
});

export const hireDetailJson = {
  hire: { ...hireJson, status: 'submitted' },
  agent: agentJson,
  input: 'Review this contract.',
  result: 'Two findings.',
  payment: null,
  jobId: 35,
  expiresAt: '2026-11-25T12:00:00.000Z',
  approvalDeadline: null,
  runFinished: true,
  submitErrorCode: null,
  rejectReason: null,
  escrowSubmission: {
    preparationId: 'prep-fund',
    purpose: 'fund',
    transaction: 'cd'.repeat(32),
    state: 'confirmed',
    errorCode: null,
    explorerUrl: null,
    updatedAt: '2026-11-24T12:01:00.000Z',
  },
  feedbackSubmission: null,
  feedbackScore: null,
  paymentExplorerUrl: null,
};
