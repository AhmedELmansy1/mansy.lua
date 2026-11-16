// Cloudflare Worker - Full Reverse Proxy for Mansy Lua / LuciVIP
// انسخ هذا الكود بالكامل وضعه في Cloudflare Dashboard -> Workers -> mansy-lua -> Quick Edit

const TARGET_HOST = 'lucivip.com';

const COMMON_HEADERS = Object.freeze({
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, User-Agent, Accept',
  'Access-Control-Max-Age': '86400',
});

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const method = request.method.toUpperCase();

    // 1. التعامل مع طلبات Preflight CORS
    if (method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: COMMON_HEADERS,
      });
    }

    // 2. فحص صحة عمل البروكسي (Health Check)
    if (url.pathname === '/health') {
      return new Response(
        JSON.stringify({
          ok: true,
          mode: 'reverse_proxy',
          target: TARGET_HOST,
          timestamp: Date.now(),
        }),
        {
          status: 200,
          headers: {
            ...COMMON_HEADERS,
            'Content-Type': 'application/json; charset=utf-8',
          },
        }
      );
    }

    // 3. قراءة البيانات في حال وجود POST
    let bodyBuffer = null;
    if (method === 'POST') {
      bodyBuffer = await request.arrayBuffer();
    }

    // 4. توجيه الطلب كـ Reverse Proxy إلى lucivip.com
    const targetUrl = new URL(request.url);
    targetUrl.protocol = 'https:';
    targetUrl.hostname = TARGET_HOST;
    targetUrl.port = '443';

    const forwardHeaders = new Headers(request.headers);
    forwardHeaders.set('Host', TARGET_HOST);

    const forwardRequest = new Request(targetUrl.toString(), {
      method: method,
      headers: forwardHeaders,
      body: bodyBuffer,
      redirect: 'follow',
    });

    try {
      const response = await fetch(forwardRequest);

      const responseHeaders = new Headers(response.headers);
      responseHeaders.set('Access-Control-Allow-Origin', '*');
      responseHeaders.set('Access-Control-Allow-Methods', 'GET, HEAD, POST, OPTIONS');
      responseHeaders.set('Access-Control-Allow-Headers', 'Content-Type, User-Agent, Accept');

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders,
      });
    } catch (err) {
      return new Response(`Reverse Proxy Error: ${err.message}`, {
        status: 502,
        headers: {
          ...COMMON_HEADERS,
          'Content-Type': 'text/plain; charset=utf-8',
        },
      });
    }
  },
};
