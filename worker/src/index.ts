export interface Env {
  MASSIVE_API_KEY: string;
  FINNHUB_API_KEY: string;
  ANTHROPIC_API_KEY: string;
  APP_TOKEN: string;
}

const MASSIVE_UPSTREAM = "https://api.massive.com";
const FINNHUB_UPSTREAM = "https://finnhub.io/api/v1";
const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";

// Per-ticker 24h cache key prefix for AI reports
const AI_REPORT_CACHE_PREFIX = "ai-report-v1:";

interface AIReportResult {
  bullCase: string[];
  bearCase: string[];
  generatedAt: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // GET-only — all endpoints are GET from the client perspective.
    if (request.method !== "GET") {
      return new Response("Method not allowed", { status: 405 });
    }

    // Validate app token.
    const token = request.headers.get("X-App-Token");
    if (!token || token !== env.APP_TOKEN) {
      return new Response("Unauthorized", { status: 401 });
    }

    const url = new URL(request.url);

    // --- AI Report route ---
    if (url.pathname.startsWith("/ai/report/")) {
      return handleAIReport(url, env);
    }

    // --- Existing proxy routes ---
    let upstream: URL;

    if (url.pathname.startsWith("/finnhub/")) {
      const finnhubPath = url.pathname.slice("/finnhub".length);
      upstream = new URL(FINNHUB_UPSTREAM + finnhubPath + url.search);
      upstream.searchParams.set("token", env.FINNHUB_API_KEY);
    } else {
      upstream = new URL(MASSIVE_UPSTREAM + url.pathname + url.search);
      upstream.searchParams.set("apiKey", env.MASSIVE_API_KEY);
    }

    const upstreamResponse = await fetch(upstream.toString(), {
      headers: {
        "Accept": "*/*",
        "User-Agent": "MyApp-Worker/1.0",
      },
    });

    const contentType = upstreamResponse.headers.get("Content-Type") ?? "";
    const isImage = contentType.startsWith("image/");
    const headers = new Headers(upstreamResponse.headers);
    headers.set("Cache-Control", isImage ? "public, max-age=86400" : "public, max-age=30");
    headers.delete("Set-Cookie");

    return new Response(upstreamResponse.body, {
      status: upstreamResponse.status,
      headers,
    });
  },
} satisfies ExportedHandler<Env>;

// --- AI Report handler ---

async function handleAIReport(url: URL, env: Env): Promise<Response> {
  const rawTicker = url.pathname.split("/ai/report/")[1]?.toUpperCase();
  const ticker = rawTicker ?? "";
  if (!ticker || !/^[A-Z0-9.\-]{1,10}$/.test(ticker)) {
    return new Response(JSON.stringify({ error: "Invalid ticker" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Check per-ticker 24h cache via CF Cache API
  const cacheKey = new Request(
    `https://ai-report-cache.internal/${AI_REPORT_CACHE_PREFIX}${ticker}`,
    { method: "GET" }
  );
  const cache = caches.default;
  const cachedResponse = await cache.match(cacheKey);
  if (cachedResponse) {
    return new Response(cachedResponse.body, {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=86400",
        "X-Cache": "HIT",
      },
    });
  }

  // Fetch context data in parallel
  const [companyData, financialsData, priceTargetData, newsData] = await Promise.allSettled([
    fetchFromMassive(`/v2/reference/tickers/${ticker}`, env),
    fetchFromMassive(`/v2/reference/financials?ticker=${ticker}&limit=1`, env),
    fetchFromFinnhub(`/stock/price-target?symbol=${ticker}`, env),
    fetchFromMassive(`/v2/reference/news?ticker=${ticker}&limit=5`, env),
  ]);

  // Extract context safely
  const company = companyData.status === "fulfilled" ? companyData.value : null;
  const financials = financialsData.status === "fulfilled" ? financialsData.value : null;
  const priceTarget = priceTargetData.status === "fulfilled" ? priceTargetData.value : null;
  const news = newsData.status === "fulfilled" ? newsData.value : null;

  const companyName = company?.results?.name ?? ticker;
  const sector = company?.results?.sic_description ?? "Unknown sector";

  // Extract financials
  const fin = financials?.results?.[0] ?? {};
  const revenue = fin.financials?.income_statement?.revenues?.value ?? "N/A";
  const eps = fin.financials?.income_statement?.basic_earnings_per_share?.value ?? "N/A";

  // Extract price targets
  const targetLow = priceTarget?.targetLow ?? "N/A";
  const targetMean = priceTarget?.targetMean ?? "N/A";
  const targetHigh = priceTarget?.targetHigh ?? "N/A";

  // Extract news headlines
  const headlines = Array.isArray(news?.results)
    ? news.results.slice(0, 5).map((a: any) => a.title ?? a.headline ?? "").filter(Boolean)
    : [];
  const newsStr = headlines.length > 0 ? headlines.join("; ") : "No recent news available";

  // Build prompt
  const prompt = `You are a senior equity analyst. Given the following data for ${ticker} (${companyName}):
- Sector: ${sector}
- Revenue: ${revenue}, EPS: ${eps}
- Analyst price target: Bear $${targetLow}, Consensus $${targetMean}, Bull $${targetHigh}
- Recent news: ${newsStr}

Return ONLY valid JSON with this exact schema:
{"bullCase": ["point1", "point2", "point3"], "bearCase": ["point1", "point2", "point3"], "generatedAt": "${new Date().toISOString()}"}
Each point must be one concise sentence (max 25 words). Provide 3 to 5 points for each case. Do not include disclaimers, markdown, or code fences.`;

  // Call Claude Haiku via raw fetch (SDK has CF Workers compatibility issues)
  let reportJson: AIReportResult | null = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const apiResponse = await fetch(ANTHROPIC_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-haiku-4-5-20251001",
          max_tokens: 1024,
          messages: [{ role: "user", content: prompt }],
        }),
      });

      if (!apiResponse.ok) {
        await apiResponse.text(); // drain response body
        // Only retry on transient errors (5xx, 429)
        if (apiResponse.status >= 500 || apiResponse.status === 429) {
          continue;
        }
        break; // permanent error (4xx), don't retry
      }

      const apiResult: any = await apiResponse.json();
      let text = apiResult.content
        ?.filter((b: any) => b.type === "text")
        ?.map((b: any) => b.text)
        ?.join("") ?? "";

      // Strip markdown code fences if present
      text = text.replace(/^```(?:json)?\s*\n?/i, "").replace(/\n?```\s*$/i, "").trim();

      const parsed = JSON.parse(text);
      if (
        Array.isArray(parsed.bullCase) &&
        Array.isArray(parsed.bearCase) &&
        parsed.bullCase.every((p: unknown) => typeof p === "string") &&
        parsed.bearCase.every((p: unknown) => typeof p === "string")
      ) {
        reportJson = {
          bullCase: parsed.bullCase.slice(0, 5).map((s: string) => s.slice(0, 300)),
          bearCase: parsed.bearCase.slice(0, 5).map((s: string) => s.slice(0, 300)),
          generatedAt: new Date().toISOString(),
        };
        break;
      }
    } catch {
      // Retry once on parse/API failure
    }
  }

  if (!reportJson) {
    return new Response(JSON.stringify({ error: "Failed to generate report" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  const responseBody = JSON.stringify(reportJson);
  const response = new Response(responseBody, {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=86400",
      "X-Cache": "MISS",
    },
  });

  // Store in CF Cache for 24h per-ticker rate limit
  const cacheResponse = new Response(responseBody, {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=86400",
    },
  });
  await cache.put(cacheKey, cacheResponse);

  return response;
}

// --- Helper: Fetch from Massive upstream ---

async function fetchFromMassive(path: string, env: Env): Promise<any> {
  const url = new URL(MASSIVE_UPSTREAM + path);
  url.searchParams.set("apiKey", env.MASSIVE_API_KEY);
  const res = await fetch(url.toString(), {
    headers: { "Accept": "*/*", "User-Agent": "MyApp-Worker/1.0" },
  });
  if (!res.ok) throw new Error(`Massive ${res.status}`);
  return res.json();
}

// --- Helper: Fetch from Finnhub upstream ---

async function fetchFromFinnhub(path: string, env: Env): Promise<any> {
  const url = new URL(FINNHUB_UPSTREAM + path);
  url.searchParams.set("token", env.FINNHUB_API_KEY);
  const res = await fetch(url.toString(), {
    headers: { "Accept": "*/*", "User-Agent": "MyApp-Worker/1.0" },
  });
  if (!res.ok) throw new Error(`Finnhub ${res.status}`);
  return res.json();
}
