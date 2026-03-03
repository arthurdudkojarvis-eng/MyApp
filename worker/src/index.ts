export interface Env {
  MASSIVE_API_KEY: string;
  APP_TOKEN: string;
}

const UPSTREAM = "https://api.massive.com";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // GET-only — all 14 Massive endpoints are GET.
    if (request.method !== "GET") {
      return new Response("Method not allowed", { status: 405 });
    }

    // Validate app token.
    const token = request.headers.get("X-App-Token");
    if (!token || token !== env.APP_TOKEN) {
      return new Response("Unauthorized", { status: 401 });
    }

    // Build upstream URL: preserve path + query, append apiKey.
    const url = new URL(request.url);
    const upstream = new URL(url.pathname + url.search, UPSTREAM);
    upstream.searchParams.set("apiKey", env.MASSIVE_API_KEY);

    const upstreamResponse = await fetch(upstream.toString(), {
      headers: {
        "Accept": "*/*",
        "User-Agent": "MyApp-Worker/1.0",
      },
    });

    // Clone response with cache headers.
    // Images are immutable branding assets — cache for 24 hours.
    // JSON API responses change frequently — cache for 30 seconds.
    const contentType = upstreamResponse.headers.get("Content-Type") ?? "";
    const isImage = contentType.startsWith("image/");
    const headers = new Headers(upstreamResponse.headers);
    headers.set("Cache-Control", isImage ? "public, max-age=86400" : "public, max-age=30");
    // Strip any upstream Set-Cookie or server headers.
    headers.delete("Set-Cookie");

    return new Response(upstreamResponse.body, {
      status: upstreamResponse.status,
      headers,
    });
  },
} satisfies ExportedHandler<Env>;
