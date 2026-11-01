// Talks to the LLM server. Two kinds are supported, picked from the URL:
//   - OpenAI-compatible chat endpoints: AI Studio's front end (/api/llm/chat), llama.cpp, Ollama, LM Studio
//   - BEYOND's own chat API (/api/chat/stream)
// With a fallback configured, whichever server passes its health check is used: AI Studio on the home
// network when the laptop is at home, BEYOND's public address when it's away.
// No Electron imports, so this file can be tested with plain Node.

const NETWORK_ERRORS = ['ECONNREFUSED', 'EHOSTUNREACH', 'ENETUNREACH', 'ETIMEDOUT', 'UND_ERR_CONNECT_TIMEOUT', 'ENOTFOUND', 'ECONNRESET'];
const RECHECK_MS = 15000;

const kindOf = (url) => (new URL(url).pathname.replace(/\/+$/, '').endsWith('/api/chat/stream') ? 'beyond' : 'openai');

function healthUrlFor(url) {
  const u = new URL(url);
  if (kindOf(url) === 'beyond') return new URL('/api/ai-status', u).href;
  // AI Studio's front end reports on /api/llm/status; OpenAI-style servers all have /v1/models.
  if (u.pathname.endsWith('/api/llm/chat')) return new URL(u.pathname.replace(/chat$/, 'status'), u).href;
  return new URL('/v1/models', u).href;
}

/** Splits the user message the renderer builds ("Current directory…\nRecent terminal output…\nQuestion: …"). */
function splitQuestion(content) {
  const i = content.lastIndexOf('\nQuestion: ');
  return i < 0 ? { question: content, context: '' } : { question: content.slice(i + 11), context: content.slice(0, i).trim() };
}

class Llm {
  /** @param {{llmUrl: string, fallbackUrl?: string, healthUrl?: string, model?: string, maxTokens: number}} config */
  constructor(config) {
    this.config = config;
    this.servers = [config.llmUrl, config.fallbackUrl].filter(Boolean);
    this.current = null;
    this.checkedAt = 0;
    this.beyondChatId = null; // one BEYOND chat per window, so questions don't each become a new chat
  }

  async isUp(url) {
    const target = url === this.config.llmUrl && this.config.healthUrl ? this.config.healthUrl : healthUrlFor(url);
    try {
      const res = await fetch(target, { signal: AbortSignal.timeout(4000) });
      const body = await res.json().catch(() => null);
      if (!res.ok) return false;
      // BEYOND: state "ok" once its engine is running. AI Studio: ready:false while its model is stopped/loading.
      return kindOf(url) === 'beyond' ? body?.state === 'ok' : body?.ready !== false;
    } catch {
      return false;
    }
  }

  /** The first server that answers its health check (cached briefly so every question doesn't re-check). */
  async pick(force = false) {
    if (!force && Date.now() - this.checkedAt < RECHECK_MS) return this.current;
    this.current = null;
    for (const url of this.servers) {
      if (await this.isUp(url)) {
        this.current = url;
        break;
      }
    }
    this.checkedAt = Date.now();
    return this.current;
  }

  async health() {
    const url = await this.pick(true);
    return { ok: !!url, url: url || this.servers.join(' or '), kind: url ? kindOf(url) : null };
  }

  /** Forget the BEYOND conversation (the panel's Clear button). */
  reset() {
    this.beyondChatId = null;
  }

  /** Streams an answer; calls onText for each piece. Throws Errors with user-readable messages. */
  async chat(messages, signal, onText) {
    // If nothing passed the health check, still try the main server so the error says why.
    const url = (await this.pick()) || this.config.llmUrl;
    try {
      if (kindOf(url) === 'beyond') await this.chatBeyond(url, messages, signal, onText);
      else await this.chatOpenAI(url, messages, signal, onText);
    } catch (err) {
      if (NETWORK_ERRORS.includes(err.cause?.code)) {
        this.checkedAt = 0; // re-check servers next time
        throw new Error(
          `Cannot reach ${this.servers.join(' or ')}. Is the LLM server running, and can this computer reach it over the network?`,
        );
      }
      throw err;
    }
  }

  async chatOpenAI(url, messages, signal, onText) {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...(this.config.model && { model: this.config.model }),
        messages,
        stream: true,
        temperature: 0.2,
        max_tokens: this.config.maxTokens,
        cache_prompt: true,
      }),
      signal,
    });
    if (!res.ok) throw new Error(`LLM server returned ${res.status}: ${(await res.text().catch(() => '')).slice(0, 300)}`);
    for await (const line of lines(res.body)) {
      if (!line.startsWith('data:')) continue;
      const data = line.slice(5).trim();
      if (data === '[DONE]') continue;
      let obj;
      try { obj = JSON.parse(data); } catch { continue; }
      if (obj.error) throw new Error(obj.error.message || JSON.stringify(obj.error));
      const text = obj.choices?.[0]?.delta?.content;
      if (text) onText(text);
    }
  }

  // BEYOND takes one message per request and keeps the conversation itself (in the chat named by
  // chat_id), so only the newest question is sent. It has no system prompt, so the instructions ride
  // along in the message, after the question so the chat gets a readable title in BEYOND.
  async chatBeyond(url, messages, signal, onText, retried = false) {
    const system = messages.find((m) => m.role === 'system')?.content || '';
    const { question, context } = splitQuestion(messages[messages.length - 1].content);
    const content = [question, '', '---', system, context].join('\n').trim().slice(0, 20000);
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content, chat_id: this.beyondChatId, think_through: false }),
      signal,
    });
    if (res.status === 404 && this.beyondChatId && !retried) {
      this.beyondChatId = null; // the chat was deleted in BEYOND: start a new one
      return this.chatBeyond(url, messages, signal, onText, true);
    }
    if (res.status === 401 || res.status === 403) throw new Error('BEYOND asked for a sign-in; this app can only use it without a password.');
    if (!res.ok) throw new Error(`BEYOND returned ${res.status}: ${(await res.text().catch(() => '')).slice(0, 300)}`);
    for await (const line of lines(res.body)) {
      let obj;
      try { obj = JSON.parse(line); } catch { continue; }
      if (obj.type === 'chat' && obj.id != null) this.beyondChatId = obj.id;
      else if (obj.type === 'token' && obj.text) onText(obj.text);
      else if (obj.type === 'error') throw new Error(obj.message || obj.detail || obj.error || 'BEYOND reported an error');
    }
  }
}

/** Yields the non-empty lines of a streamed response body. */
async function* lines(body) {
  const decoder = new TextDecoder();
  let buffer = '';
  for await (const chunk of body) {
    buffer += decoder.decode(chunk, { stream: true });
    let nl;
    while ((nl = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, nl).trim();
      buffer = buffer.slice(nl + 1);
      if (line) yield line;
    }
  }
  if (buffer.trim()) yield buffer.trim();
}

module.exports = { Llm, kindOf, healthUrlFor };
