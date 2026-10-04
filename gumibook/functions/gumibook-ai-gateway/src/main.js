/**
 * GumiBook AI Gateway — ONE Appwrite Function for ALL AI/API tasks.
 *
 * Free tier: 2 functions max. Every AI capability routes through here
 * via the `task` parameter. Adding a task = adding a handler in
 * TASK_HANDLERS below. No restructure needed.
 *
 * Secret env vars (Appwrite Console only, never in code/git):
 *   GEMINI_API_KEY   — AI tasks (ocr)
 *   SUGRA_API_KEY    — market price + news (sugra.ai)
 *   LSE_API_KEY      — economic calendar (londonstrategicedge.com)
 *
 * Provider slots: `gemini` active today. Others (openai, etc.) plug in
 * under PROVIDERS when needed — routing stays untouched.
 */

const PROVIDERS = {
  gemini: {
    // Gemini 3 Flash — one model for OCR vision AND text analysis.
    call: callGemini,
    model: 'gemini-3.8-flash',
  },
  // Slot for future providers:
  // openai: { call: callOpenAI, model: '...' },
};

const TASK_HANDLERS = {
  // P1-03 now: MT5 screenshot → structured Trade JSON.
  ocr: {
    provider: 'gemini',
    handler: handleOcr,
  },
  // P2-03: self-service account deletion. The client SDK cannot delete
  // its own account; this runs users.delete with the function's
  // dynamic API key (x-appwrite-key). Caller identity comes from
  // x-appwrite-user-id — a user can only ever delete themself.
  deleteAccount: {
    handler: handleDeleteAccount,
  },
  marketPrice: { handler: handleMarketPrice },
  marketNews: { handler: handleMarketNews },
  marketCalendar: { handler: handleMarketCalendar },
  // P2-06 slot — routing wired, NOT implemented yet:
  // market:  { provider: 'gemini', handler: null },  // AI market summary
};

const OCR_SYSTEM_PROMPT = [
  'You are a strict OCR reader for MT5 trading screenshots.',
  'RULES:',
  '- Read ONLY the numbers and text visibly printed in the image.',
  '- NEVER infer, estimate, complete, or invent any value.',
  '- If a field is not visibly present, return null for it.',
  '- Return JSON only, no markdown, no commentary.',
  'Schema:',
  '{',
  '  "instrument": string|null,',
  '  "direction": "buy"|"sell"|null,',
  '  "entryPrice": number|null,',
  '  "exitPrice": number|null,',
  '  "stopLoss": number|null,',
  '  "takeProfit": number|null,',
  '  "lotSize": number|null,',
  '  "profitLoss": number|null,',
  '  "openTime": string|null (ISO 8601 if visibly shown),',
  '  "closeTime": string|null (ISO 8601 if visibly shown)',
  '}',
].join('\n');

let geminiClient = null;

function getGemini(apiKey) {
  if (!geminiClient) {
    const { GoogleGenerativeAI } = require('@google/generative-ai');
    geminiClient = new GoogleGenerativeAI(apiKey);
  }
  return geminiClient;
}

async function callGemini({ apiKey, prompt, imageBase64, imageMimeType }) {
  const gen = getGemini(apiKey);
  const model = gen.getGenerativeModel({ model: PROVIDERS.gemini.model });
  const parts = [{ text: prompt }];
  if (imageBase64) {
    parts.push({
      inlineData: { data: imageBase64, mimeType: imageMimeType || 'image/png' },
    });
  }
  const result = await model.generateContent(parts);
  const text = result.response.text();
  return { text };
}

async function handleOcr({ payload, apiKey }) {
  const imageBase64 = payload.imageBase64;
  if (!imageBase64) {
    throw new Error('Missing imageBase64 for ocr task');
  }
  const { text } = await PROVIDERS.gemini.call({
    apiKey,
    prompt: OCR_SYSTEM_PROMPT,
    imageBase64,
    imageMimeType: payload.imageMimeType || 'image/png',
  });

  // Strict JSON extraction — Gemini may still wrap in fences.
  const cleaned = text.replace(/```json|```/g, '').trim();
  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    const m = cleaned.match(/\{[\s\S]*\}/);
    if (!m) throw new Error('Gemini returned non-JSON output');
    parsed = JSON.parse(m[0]);
  }
  return parsed;
}

/** Shared strict JSON extraction — Gemini may still wrap in fences. */
function parseModelJson(text) {
  const cleaned = text.replace(/```json|```/g, '').trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const m = cleaned.match(/\{[\s\S]*\}/);
    if (!m) throw new Error('Gemini returned non-JSON output');
    return JSON.parse(m[0]);
  }
}

const SUGRA_BASE = 'https://sugra.ai/api/v1';
const SUGRA_V2 = 'https://sugra.ai/api/v2';

const FUTURES_MAP = {
  NQ: 'NQ', NAS100: 'NQ',
  ES: 'ES', SP500: 'ES', SPX500: 'ES',
  YM: 'YM', DJ30: 'YM', US30: 'YM',
  XAUUSD: 'GC', EURUSD: '6E', GBPUSD: '6B', USDJPY: '6J', USOIL: 'CL',
};
const QUOTE_MAP = {
  // DXY deliberately absent: Sugra has no ICE US Dollar Index (DX-Y.NYB
  // unverified; ^USDOLLAR is the Dow Jones FXCM variant whose ~12k
  // scale clashes with the TVC:DXY chart). App renders no DXY card.
  US10Y: '^TNX',
};
const CRYPTO_MAP = {
  BTCUSD: 'bitcoin',
};
const INVERT_PAIRS = new Set(['USDJPY']);

function requireSugraKey() {
  const k = process.env.SUGRA_API_KEY;
  if (!k) throw new Error('SUGRA_API_KEY missing in Function environment');
  return k;
}

// ---------------------------------------------------------------------------
// Response cache (10 min TTL). Appwrite Functions are ephemeral containers
// (cold starts + parallel instances), so an in-memory Map is unreliable —
// the cache lives in the `gateway_cache` collection via the REST API. Raw
// fetch, not node-appwrite: its bundled fetch shim fails in this runtime
// (same reason handleDeleteAccount uses raw fetch).
// ---------------------------------------------------------------------------

const DB_ID = '6a960b8d0035adcd1c0d';
const CACHE_COLLECTION = 'gateway_cache';
const CACHE_TTL_MS = 10 * 60 * 1000;
// Cloud document limit is 65535 bytes; keep headroom for the envelope.
const MAX_CACHE_BODY = 60000;

function cacheDocId(key) {
  // Appwrite documentIds cap at 36 chars, but the natural cache key
  // (sorted symbol list) is way longer — hash it down. SHA-256 of the
  // key, truncated, keeps lookups exact without collision risk here.
  return require('crypto')
    .createHash('sha256')
    .update(key)
    .digest('hex')
    .slice(0, 36);
}

function cacheDocUrl(key) {
  const base = process.env.APPWRITE_FUNCTION_API_ENDPOINT;
  return `${base}/databases/${DB_ID}/collections/${CACHE_COLLECTION}/documents/${cacheDocId(key)}`;
}

/// POST target is the collection's documents endpoint (the id travels
/// in the body); the /{id} URL above is for GET/PATCH/DELETE only.
function cacheDocsEndpoint() {
  const base = process.env.APPWRITE_FUNCTION_API_ENDPOINT;
  return `${base}/databases/${DB_ID}/collections/${CACHE_COLLECTION}/documents`;
}

function cacheAuthHeaders(req) {
  return {
    'X-Appwrite-Project': process.env.APPWRITE_FUNCTION_PROJECT_ID,
    'X-Appwrite-Key': req.headers['x-appwrite-key'],
  };
}

/**
 * Fresh cached payload, or null on miss/expiry/error. Never throws — a
 * broken cache must not break the section, it only costs an upstream call.
 */
async function cacheRead(req, key, ttlMs = CACHE_TTL_MS, warn = null) {
  const doc = await cacheGetDoc(req, key, warn);
  if (!doc) return null;
  const fetchedAt = Date.parse(doc.fetchedAt || '');
  if (!fetchedAt || Date.now() - fetchedAt > ttlMs) return null;
  try {
    return JSON.parse(doc.value);
  } catch {
    return null;
  }
}

async function cacheGetDoc(req, key, warn = null) {
  try {
    const url = cacheDocUrl(key);
    const res = await fetchJson(url, {
      headers: cacheAuthHeaders(req),
    }, 5000);
    // 404 is the normal cold-cache miss; anything else is worth a log
    // (silently swallowing a 401 here once hid a missing scope).
    if (!res.ok && res.status !== 404) {
      warn?.(`cacheRead ${key}: HTTP ${res.status}`);
    }
    if (!res.ok || res.status === 404) return null;
    return res.body;
  } catch (e) {
    warn?.(`cacheRead ${key}: ${e.message}`);
    return null;
  }
}

async function cacheWrite(req, key, data, warn = null) {
  try {
    const body = {
      fetchedAt: new Date().toISOString(),
      value: JSON.stringify(data),
    };
    if (JSON.stringify(body).length > MAX_CACHE_BODY) return;
    const headers = { ...cacheAuthHeaders(req), 'content-type': 'application/json' };
    const res = await fetch(cacheDocsEndpoint(), {
      method: 'POST',
      headers,
      body: JSON.stringify({ documentId: cacheDocId(key), data: body }),
    });
    const text = await res.text().catch(() => '');
    if (res.status === 409 || res.status === 400) {
      // Exists already (seeded by a parallel invocation) — refresh it.
      const res2 = await fetch(cacheDocUrl(key), {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ data: body }),
      });
      const text2 = await res2.text().catch(() => '');
      warn?.(`cacheWrite ${key}: POST ${res.status} -> PATCH ${res2.status} ${text2.slice(0, 200)}`);
      return;
    }
    if (!res.ok) warn?.(`cacheWrite ${key}: POST ${res.status} url=${cacheDocsEndpoint()} ${text.slice(0, 120)}`);
  } catch (e) {
    warn?.(`cacheWrite ${key}: ${e.message}`);
  }
}

async function fetchJson(url, options = {}, timeoutMs = 12000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    const text = await res.text();
    let body = null;
    try {
      body = JSON.parse(text);
    } catch {
      body = { raw: text.slice(0, 500) };
    }
    return { ok: res.ok, status: res.status, body };
  } finally {
    clearTimeout(timer);
  }
}

/** Retry once on 429/provider hiccups, back off 1s. */
async function fetchJsonWithRetry(url, options = {}) {
  const first = await fetchJson(url, options);
  if (first.status === 429 || first.status >= 500) {
    await new Promise((r) => setTimeout(r, 1000));
    return fetchJson(url, options);
  }
  return first;
}

async function fetchQuote(upper, hdrs, error) {
  try {
    let price = null, prevClose = null;
    if (FUTURES_MAP[upper]) {
      const root = FUTURES_MAP[upper];
      const url = `${SUGRA_V2}/futures/${root}/historical?period=5d&interval=1d`;
      const res = await fetchJsonWithRetry(url, { headers: hdrs });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const bars = res.body?.data?.data || [];
      if (bars.length >= 2) {
        const last = bars[bars.length - 1];
        const prev = bars[bars.length - 2];
        price = last.close;
        prevClose = prev.close;
      } else if (bars.length === 1) {
        price = bars[0].close;
      }
      if (price != null && INVERT_PAIRS.has(upper)) {
        price = 1 / price;
        if (prevClose) prevClose = 1 / prevClose;
      }
    } else if (QUOTE_MAP[upper]) {
      const qsym = encodeURIComponent(QUOTE_MAP[upper]);
      const url = `${SUGRA_V2}/quotes/${qsym}/price`;
      const res = await fetchJsonWithRetry(url, { headers: hdrs });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const d = res.body?.data || {};
      price = d.regularMarketPrice ?? null;
      prevClose = d.regularMarketPreviousClose ?? null;
    } else if (CRYPTO_MAP[upper]) {
      const coin = CRYPTO_MAP[upper];
      const url = `${SUGRA_BASE}/crypto/${coin}/price`;
      const res = await fetchJsonWithRetry(url, { headers: hdrs });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const d = res.body?.data || {};
      price = d.current_price ?? null;
      prevClose = price != null && d.price_change_24h != null
        ? price - d.price_change_24h : null;
    } else {
      throw new Error('Unknown symbol');
    }
    const change = price != null && prevClose != null ? price - prevClose : null;
    const changePercent = change != null && prevClose ? (change / prevClose) * 100 : null;
    return { symbol: upper, price, change, changePercent, previousClose: prevClose };
  } catch (e) {
    // Per-symbol failure: log and degrade, never kill the whole batch.
    error(`marketPrice ${upper}: ${e.message}`);
    return { symbol: upper, error: e.message };
  }
}

async function handleMarketPrice({ payload, error, req, log }) {
  const apiKey = requireSugraKey();
  const symbols = Array.isArray(payload.symbols) ? payload.symbols : [];
  if (symbols.length === 0) return { quotes: [] };

  const cacheKey = 'price:' + symbols
    .slice(0, 20).map((s) => String(s).toUpperCase()).sort().join(',');
  const hit = await cacheRead(req, cacheKey, CACHE_TTL_MS, error);
  if (hit) return hit;

  const hdrs = { 'x-api-key': apiKey };
  // Parallel: a sequential 11-symbol loop could blow the 15s function
  // timeout when Sugra is slow or 429s retry once each.
  const quotes = await Promise.all(
    symbols.slice(0, 20).map((s) => fetchQuote(s.toUpperCase(), hdrs, error)),
  );
  const result = { quotes };
  // Cache only useful rows: drop per-symbol errors so a half-failed
  // batch never serves stale error rows for 10 minutes. All-error
  // batches (e.g. Sugra 429) stay fully uncached — next pull retries.
  if (quotes.some((q) => q.price != null)) {
    await cacheWrite(req, cacheKey, {
      quotes: quotes.filter((q) => q.price != null),
    }, error);
  }
  return result;
}

async function handleMarketNews({ payload, error, req }) {
  const apiKey = requireSugraKey();
  const category = (payload.category || 'business').toLowerCase();
  const limit = Math.min(parseInt(payload.limit, 10) || 20, 50);
  const query = String(payload.query || '');

  const cacheKey = `news:${category}:${limit}:${query}`;
  const hit = await cacheRead(req, cacheKey, CACHE_TTL_MS, error);
  if (hit) return hit;

  const url = `${SUGRA_BASE}/news/latest?category=${encodeURIComponent(category)}&limit=${limit}`;
  const res = await fetchJsonWithRetry(url, {
    headers: { 'x-api-key': apiKey },
  });
  if (!res.ok) {
    error(`marketNews: HTTP ${res.status}`);
    throw new Error(`News unavailable (HTTP ${res.status})`);
  }
  const items = res.body?.data?.items || [];
  let sentiment = null;
  if (query) {
    try {
      const sUrl = `${SUGRA_BASE}/gdelt/sentiment?q=${encodeURIComponent(query)}&timespan=1day`;
      const sRes = await fetchJsonWithRetry(sUrl, { headers: { 'x-api-key': apiKey } });
      if (sRes.ok && sRes.body?.data) sentiment = sRes.body.data;
    } catch (e) {
      error(`marketNews sentiment: ${e.message}`);
    }
  }
  const result = {
    news: (Array.isArray(items) ? items : []).slice(0, limit).map((n) => ({
      title: n.title ?? null,
      snippet: n.description ?? null,
      source: n.source_name ?? n.source ?? null,
      publishedAt: n.published ?? null,
      link: n.link ?? null,
    })),
    sentiment,
  };
  if (result.news.length > 0) {
    await cacheWrite(req, cacheKey, result, error);
  }
  return result;
}

async function handleMarketCalendar({ error, now = Date.now }) {
  const apiKey = process.env.LSE_API_KEY;
  if (!apiKey) {
    throw new Error('LSE_API_KEY missing in Function environment');
  }
  // LSE `end` is EXCLUSIVE (verified live: start=X&end=X returns 0).
  // `datetime` in the payload is UTC-naive (US 08:30 ET arrives as
  // 12:30). The app re-filters to the user's LOCAL day, which can sit
  // up to a day away from the UTC day, so fetch a 3-day UTC window
  // (yesterday/today/tomorrow) and let the app cut it down. `now` is
  // injectable purely for tests — production passes no argument.
  const dayMs = 86400000;
  const iso = (offsetDays) =>
    new Date(now() + offsetDays * dayMs).toISOString().slice(0, 10);
  const start = iso(-1);
  const end = iso(2);
  const res = await fetchJsonWithRetry(
    'https://api.londonstrategicedge.com/vault/ref/economic_calendar' +
      `?start=${start}&end=${end}`,
    { headers: { 'x-api-key': apiKey } },
  );
  if (!res.ok) {
    error(`marketCalendar: HTTP ${res.status}`);
    throw new Error(`Calendar unavailable (HTTP ${res.status})`);
  }
  // Raw list of events; shape: array or { events: [...] }.
  const events = Array.isArray(res.body) ? res.body : res.body.events || [];
  return { events, window: { start, end } };
}

function jsonRes(res, code, body) {
  return res.json(body, code);
}

/**
 * P2-03: delete the caller's own account. Identity is taken ONLY from
 * the Appwrite-provided headers — never from the request body, so a
 * user can never delete another user. Server SDK auth uses the
 * function's dynamic API key (x-appwrite-key).
 */
async function handleDeleteAccount({ req, log, error }) {
  const userId = req.headers['x-appwrite-user-id'];
  const dynamicKey = req.headers['x-appwrite-key'];
  if (!userId) {
    throw new Error('Missing x-appwrite-user-id (unauthenticated call)');
  }
  if (!dynamicKey) {
    throw new Error('Missing x-appwrite-key (dynamic key unavailable)');
  }
  // Raw fetch instead of node-appwrite: its bundled fetch shim fails
  // with "fetch failed" in this runtime. One DELETE call, no SDK dep.
  const url = process.env.APPWRITE_FUNCTION_API_ENDPOINT
    + '/users/' + encodeURIComponent(userId);
  const res = await fetch(url, {
    method: 'DELETE',
    headers: {
      'X-Appwrite-Project': process.env.APPWRITE_FUNCTION_PROJECT_ID,
      'X-Appwrite-Key': dynamicKey,
      'content-type': 'application/json',
    },
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    error('users.delete failed: HTTP ' + res.status + ' ' + text.slice(0, 200));
    throw new Error('Account deletion failed');
  }
  return { deleted: userId };
}

module.exports = async ({ req, res, log, error }) => {
  if (req.method === 'GET') {
    return jsonRes(res, 200, { ok: true, service: 'gumibook-ai-gateway' });
  }
  if (req.method !== 'POST') {
    return jsonRes(res, 405, { ok: false, error: 'Method not allowed' });
  }

  let body = {};
  try {
    // bodyJson getter THROWS on non-JSON bodies — probe inside try.
    const bj = req.bodyJson;
    body = typeof bj === 'object' && bj !== null ? bj : JSON.parse(req.bodyText || '{}');
  } catch {
    try {
      body = JSON.parse(req.bodyText || '{}');
    } catch {
      return jsonRes(res, 400, { ok: false, error: 'Invalid JSON body' });
    }
  }

  const { task, payload = {} } = body;
  if (!task || !TASK_HANDLERS[task]) {
    return jsonRes(res, 400, {
      ok: false,
      error: `Unknown or missing task. Supported: ${Object.keys(TASK_HANDLERS).join(', ')}`,
    });
  }
  if (!TASK_HANDLERS[task].handler) {
    return jsonRes(res, 501, {
      ok: false,
      error: `Task '${task}' is registered but not implemented yet.`,
    });
  }

  // Only the AI tasks need GEMINI_API_KEY; deletion does not.
  const needsApiKey = task === 'ocr';
  const apiKey = process.env.GEMINI_API_KEY;
  if (needsApiKey && !apiKey) {
    error('GEMINI_API_KEY missing in Function environment');
    return jsonRes(res, 500, { ok: false, error: 'AI provider not configured' });
  }

  try {
    const data = await TASK_HANDLERS[task].handler({ payload, apiKey, log, error, req });
    return jsonRes(res, 200, { ok: true, task, data });
  } catch (e) {
    const msg = e && e.message ? e.message : String(e);
    // Missing market keys = not configured yet (distinct from down).
    if (msg.includes('missing in Function environment')) {
      error(`${task} failed: ${msg}`);
      return jsonRes(res, 500, { ok: false, error: 'Market data provider not configured' });
    }
    if (msg.includes('HTTP 429')) {
      return jsonRes(res, 429, { ok: false, error: 'Market data rate limited. Try again shortly.' });
    }
    error(`Task '${task}' failed: ${msg}`);
    return jsonRes(res, 502, { ok: false, error: 'Task request failed' });
  }
};
