const { test } = require('node:test');
const assert = require('node:assert/strict');

const gateway = require('../src/main.js');

/// handleMarketCalendar must derive its UTC day window from the moment
/// of execution (Date.now), never from a hardcoded date. Patching
/// global Date.now injects different "todays" and the window must move
/// with them: start = yesterday, end = tomorrow + 1 (exclusive).
function makeLseFake({ captured }) {
  return async (url) => {
    if (String(url).startsWith('https://api.londonstrategicedge.com/')) {
      captured.push(String(url));
      return {
        ok: true,
        status: 200,
        text: async () =>
          JSON.stringify([
            { event: 'A', date: '2026-09-15', datetime: '2026-09-15 04:30:00' },
            { event: 'B', date: '2026-09-16', datetime: '2026-09-16 09:00:00' },
          ]),
      };
    }
    return { ok: false, status: 404, text: async () => '{}' };
  };
}

function makeReq() {
  return {
    method: 'POST',
    headers: { 'x-appwrite-key': 'fake-dynamic-key' },
    bodyJson: { task: 'marketCalendar', payload: {} },
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

async function runOnce(req, res) {
  await gateway({
    req,
    res,
    log: () => {},
    error: () => {},
  });
  assert.equal(res.out.code, 200, 'gateway must answer 200');
  return res.out.body;
}

test('calendar window follows the execution time dynamically', async () => {
  const captured = [];
  const original = global.fetch;
  global.fetch = makeLseFake({ captured });
  const originalEnv = { ...process.env };
  process.env.LSE_API_KEY = 'fake-lse-key';
  const originalNow = Date.now;
  try {
    // "Today" = 2026-09-15 10:00:00Z.
    Date.now = () => Date.UTC(2026, 8, 15, 10, 0, 0);
    const body1 = await runOnce(makeReq(), makeRes());
    assert.ok(
      captured[0].includes('start=2026-09-14&end=2026-09-17'),
      `yesterday/tomorrow+1 window expected, got ${captured[0]}`,
    );
    assert.deepEqual(body1.data.window, { start: '2026-09-14', end: '2026-09-17' });

    // Five days later — the same code path must produce a new window.
    Date.now = () => Date.UTC(2026, 8, 20, 10, 0, 0);
    const body2 = await runOnce(makeReq(), makeRes());
    assert.ok(
      captured[1].includes('start=2026-09-19&end=2026-09-22'),
      `window must move with the execution date, got ${captured[1]}`,
    );
    assert.deepEqual(body2.data.window, { start: '2026-09-19', end: '2026-09-22' });
    assert.notEqual(body1.data.window.start, body2.data.window.start);
  } finally {
    global.fetch = original;
    Date.now = originalNow;
    process.env = originalEnv;
  }
});
