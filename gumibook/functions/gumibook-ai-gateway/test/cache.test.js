const { test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

const gateway = require('../src/main.js');

const docIdOf = (key) =>
  crypto.createHash('sha256').update(key).digest('hex').slice(0, 36);

/// Cache contract: a fresh cache hit serves the payload WITHOUT calling
/// Sugra again; an expired (or absent) entry triggers a real upstream
/// fetch. fetch() is fully faked — no network in CI.
function makeFetchFake({ sugra, docs }) {
  const calls = { sugra: 0, cacheRead: 0, cacheWrite: 0 };
  const fake = async (url, options = {}) => {
    const isSugra = url.startsWith('https://sugra.ai/');
    if (isSugra) {
      calls.sugra++;
      return sugra(url, options);
    }
    const method = (options.method || 'GET').toUpperCase();
    if (method === 'POST') {
      calls.cacheWrite++;
      const body = JSON.parse(options.body);
      const key = body.documentId;
      if (docs.has(key)) {
        return { ok: false, status: 409, text: async () => '{}' };
      }
      docs.set(key, { ...body.data });
      return { ok: true, status: 201, text: async () => '{}' };
    }
    // GET/PATCH carry the id in the URL.
    const key = decodeURIComponent(url.split('/documents/')[1]);
    if (method === 'GET') {
      calls.cacheRead++;
      const doc = docs.get(key);
      if (!doc) return { ok: false, status: 404, text: async () => '{}' };
      return { ok: true, status: 200, text: async () => JSON.stringify(doc) };
    }
    calls.cacheWrite++;
    docs.set(key, { ...JSON.parse(options.body).data });
    return { ok: true, status: 200, text: async () => '{}' };
  };
  return { fake, calls };
}

function makeReq(payload) {
  return {
    method: 'POST',
    headers: { 'x-appwrite-key': 'fake-dynamic-key' },
    bodyJson: { task: payload.task, payload: payload.payload },
  };
}

function makeRes() {
  const out = { code: null, body: null };
  return {
    json(body, code) {
      out.code = code;
      out.body = body;
    },
    get out() {
      return out;
    },
  };
}

const ENV = {
  SUGRA_API_KEY: 'fake-sugra-key',
  APPWRITE_FUNCTION_PROJECT_ID: 'fake-project',
  APPWRITE_FUNCTION_API_ENDPOINT: 'https://fra.cloud.appwrite.io/v1',
};

test('cache miss calls Sugra; a follow-up within TTL does not', async () => {
  const docs = new Map();
  const sugra = async () => ({
    ok: true,
    status: 200,
    text: async () =>
      JSON.stringify({
        data: {
          root: 'NQ',
          data: [
            { date: '2026-09-14', close: 29152.25 },
            { date: '2026-09-15', close: 29356.0 },
          ],
        },
      }),
  });
  const { fake, calls } = makeFetchFake({ sugra, docs });
  const original = global.fetch;
  global.fetch = fake;
  const originalEnv = { ...process.env };
  Object.assign(process.env, ENV);
  try {
    const log = () => {};
    const error = () => {};

    const res1 = makeRes();
    await gateway({
      req: makeReq({ task: 'marketPrice', payload: { symbols: ['NQ'] } }),
      res: res1,
      log,
      error,
    });
    assert.equal(res1.out.code, 200);
    assert.equal(res1.out.body.data.quotes[0].price, 29356.0);
    assert.equal(calls.sugra, 1, 'first call must hit Sugra');
    assert.equal(calls.cacheWrite, 1, 'miss must seed the cache');

    const res2 = makeRes();
    await gateway({
      req: makeReq({ task: 'marketPrice', payload: { symbols: ['NQ'] } }),
      res: res2,
      log,
      error,
    });
    assert.equal(calls.sugra, 1, 'cache hit must NOT hit Sugra again');
    assert.equal(calls.cacheRead, 2, 'both calls read the cache');
    assert.deepEqual(
      res2.out.body.data.quotes,
      res1.out.body.data.quotes,
      'cache hit returns the same payload',
    );
  } finally {
    global.fetch = original;
    process.env = originalEnv;
  }
});

test('expired cache triggers a fresh Sugra fetch', async () => {
  const docs = new Map([
    [
      docIdOf('price:NQ'),
      {
        // 30 minutes old — past the 10 min TTL.
        fetchedAt: new Date(Date.now() - 30 * 60 * 1000).toISOString(),
        value: JSON.stringify({ quotes: [{ symbol: 'NQ', price: 1 }] }),
      },
    ],
  ]);
  const sugra = async () => ({
    ok: true,
    status: 200,
    text: async () =>
      JSON.stringify({
        data: {
          root: 'NQ',
          data: [
            { date: '2026-09-14', close: 29152.25 },
            { date: '2026-09-15', close: 29356.0 },
          ],
        },
      }),
  });
  const { fake, calls } = makeFetchFake({ sugra, docs });
  const original = global.fetch;
  global.fetch = fake;
  const originalEnv = { ...process.env };
  Object.assign(process.env, ENV);
  try {
    const res = makeRes();
    await gateway({
      req: makeReq({ task: 'marketPrice', payload: { symbols: ['NQ'] } }),
      res,
      log: () => {},
      error: () => {},
    });
    assert.equal(res.out.code, 200);
    assert.equal(res.out.body.data.quotes[0].price, 29356.0);
    assert.equal(calls.sugra, 1, 'stale entry must be refreshed upstream');
    // POST hits 409 (entry exists) then PATCH rewrites it = 2 writes.
    assert.equal(calls.cacheWrite, 2, 'refresh rewrites the cache entry');
  } finally {
    global.fetch = original;
    process.env = originalEnv;
  }
});

test('cache key is order-independent across the symbol list', async () => {
  const docs = new Map();
  let lastKey = null;
  const sugra = async () => ({
    ok: true,
    status: 200,
    text: async () =>
      JSON.stringify({
        data: { root: 'NQ', data: [{ close: 1 }, { close: 2 }] },
      }),
  });
  const { fake } = makeFetchFake({ sugra, docs });
  const original = global.fetch;
  global.fetch = async (url, options) => {
    if (String(url).includes('/documents/')) lastKey = url;
    return fake(url, options);
  };
  const originalEnv = { ...process.env };
  Object.assign(process.env, ENV);
  try {
    for (const symbols of [
      ['NQ', 'ES'],
      ['ES', 'NQ'],
    ]) {
      const res = makeRes();
      await gateway({
        req: makeReq({ task: 'marketPrice', payload: { symbols } }),
        res,
        log: () => {},
        error: () => {},
      });
    }
    assert.ok(
      decodeURIComponent(lastKey).includes(docIdOf('price:ES,NQ')),
      'both call orders must resolve to the same cache document',
    );
  } finally {
    global.fetch = original;
    process.env = originalEnv;
  }
});
