"""
Yanler Search API — 轻量级聚合搜索引擎
无需 Docker，直接运行。聚合 Google/Bing/DuckDuckGo/Baidu 等结果。
"""

import asyncio
import re
import time
import hashlib
import random
from urllib.parse import quote_plus, urljoin
from typing import Optional

import httpx
from bs4 import BeautifulSoup
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse
import uvicorn

# ─── 配置 ───────────────────────────────────────────────
HOST = "0.0.0.0"
PORT = 8080
TIMEOUT = 8.0
MAX_RESULTS_PER_ENGINE = 10

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
]

# ─── FastAPI ─────────────────────────────────────────────
app = FastAPI(title="Yanler Search API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _ua() -> str:
    return random.choice(USER_AGENTS)


def _headers() -> dict:
    return {
        "User-Agent": _ua(),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    }


# ─── 搜索引擎解析器 ──────────────────────────────────────

async def search_google(client: httpx.AsyncClient, query: str, lang: str) -> list[dict]:
    """Google 搜索"""
    url = f"https://www.google.com/search?q={quote_plus(query)}&hl={lang}&num={MAX_RESULTS_PER_ENGINE}"
    try:
        resp = await client.get(url, headers=_headers(), follow_redirects=True)
        if resp.status_code != 200:
            return []
        soup = BeautifulSoup(resp.text, "html.parser")
        results = []
        for g in soup.select("div.g"):
            a = g.select_one("a[href^='http']")
            title_el = g.select_one("h3")
            snippet_el = g.select_one("div[data-sncf], div.VwiC3b, span.aCOpRe")
            if a and title_el:
                results.append({
                    "title": title_el.get_text(strip=True),
                    "url": a["href"],
                    "content": snippet_el.get_text(strip=True) if snippet_el else "",
                    "engine": "google",
                })
        return results[:MAX_RESULTS_PER_ENGINE]
    except Exception:
        return []


async def search_bing(client: httpx.AsyncClient, query: str, lang: str) -> list[dict]:
    """Bing 搜索"""
    url = f"https://www.bing.com/search?q={quote_plus(query)}&setlang={lang}&count={MAX_RESULTS_PER_ENGINE}"
    try:
        resp = await client.get(url, headers=_headers(), follow_redirects=True)
        if resp.status_code != 200:
            return []
        soup = BeautifulSoup(resp.text, "html.parser")
        results = []
        for li in soup.select("li.b_algo"):
            a = li.select_one("h2 a")
            snippet_el = li.select_one("p, div.b_caption p")
            if a:
                results.append({
                    "title": a.get_text(strip=True),
                    "url": a["href"],
                    "content": snippet_el.get_text(strip=True) if snippet_el else "",
                    "engine": "bing",
                })
        return results[:MAX_RESULTS_PER_ENGINE]
    except Exception:
        return []


async def search_duckduckgo(client: httpx.AsyncClient, query: str, lang: str) -> list[dict]:
    """DuckDuckGo HTML 搜索"""
    url = f"https://html.duckduckgo.com/html/?q={quote_plus(query)}"
    headers = {**_headers(), "Referer": "https://duckduckgo.com/"}
    try:
        resp = await client.post(url, data={"q": query}, headers=headers, follow_redirects=True)
        if resp.status_code != 200:
            return []
        soup = BeautifulSoup(resp.text, "html.parser")
        results = []
        for r in soup.select(".result"):
            a = r.select_one("a.result__a")
            snippet_el = r.select_one(".result__snippet")
            if a:
                href = a.get("href", "")
                # DuckDuckGo 有时用重定向链接
                if "uddg=" in href:
                    match = re.search(r"uddg=([^&]+)", href)
                    if match:
                        from urllib.parse import unquote
                        href = unquote(match.group(1))
                results.append({
                    "title": a.get_text(strip=True),
                    "url": href,
                    "content": snippet_el.get_text(strip=True) if snippet_el else "",
                    "engine": "duckduckgo",
                })
        return results[:MAX_RESULTS_PER_ENGINE]
    except Exception:
        return []


async def search_baidu(client: httpx.AsyncClient, query: str, lang: str) -> list[dict]:
    """百度搜索"""
    url = f"https://www.baidu.com/s?wd={quote_plus(query)}&rn={MAX_RESULTS_PER_ENGINE}"
    try:
        resp = await client.get(url, headers=_headers(), follow_redirects=True)
        if resp.status_code != 200:
            return []
        soup = BeautifulSoup(resp.text, "html.parser")
        results = []
        for item in soup.select(".result, .c-container"):
            a = item.select_one("h3 a")
            snippet_el = item.select_one(".c-abstract, .content-right_8Zs40")
            if a:
                href = a.get("href", "")
                results.append({
                    "title": a.get_text(strip=True),
                    "url": href,
                    "content": snippet_el.get_text(strip=True) if snippet_el else "",
                    "engine": "baidu",
                })
        return results[:MAX_RESULTS_PER_ENGINE]
    except Exception:
        return []


async def search_sogou(client: httpx.AsyncClient, query: str, lang: str) -> list[dict]:
    """搜狗搜索"""
    url = f"https://www.sogou.com/web?query={quote_plus(query)}"
    try:
        resp = await client.get(url, headers=_headers(), follow_redirects=True)
        if resp.status_code != 200:
            return []
        soup = BeautifulSoup(resp.text, "html.parser")
        results = []
        for item in soup.select(".vrwrap, .rb"):
            a = item.select_one("h3 a")
            snippet_el = item.select_one(".str-text, .star-wiki, p.str_info")
            if a:
                results.append({
                    "title": a.get_text(strip=True),
                    "url": a.get("href", ""),
                    "content": snippet_el.get_text(strip=True) if snippet_el else "",
                    "engine": "sogou",
                })
        return results[:MAX_RESULTS_PER_ENGINE]
    except Exception:
        return []


async def search_wikipedia(client: httpx.AsyncClient, query: str, lang: str) -> list[dict]:
    """Wikipedia API"""
    url = f"https://{lang.split('-')[0]}.wikipedia.org/w/api.php"
    params = {
        "action": "query",
        "list": "search",
        "srsearch": query,
        "srlimit": 5,
        "format": "json",
    }
    try:
        resp = await client.get(url, params=params, headers=_headers())
        if resp.status_code != 200:
            return []
        data = resp.json()
        results = []
        for item in data.get("query", {}).get("search", []):
            title = item.get("title", "")
            snippet = BeautifulSoup(item.get("snippet", ""), "html.parser").get_text()
            results.append({
                "title": title,
                "url": f"https://{lang.split('-')[0]}.wikipedia.org/wiki/{quote_plus(title)}",
                "content": snippet,
                "engine": "wikipedia",
            })
        return results
    except Exception:
        return []


# ─── 聚合 & 排序 ─────────────────────────────────────────

def _url_hash(url: str) -> str:
    """URL 去重用的标准化哈希"""
    clean = re.sub(r"[?#].*$", "", url.strip().lower())
    clean = re.sub(r"^https?://(www\.)?", "", clean)
    return hashlib.md5(clean.encode()).hexdigest()[:12]


def _score_result(result: dict, engine_weights: dict) -> float:
    """给结果打分：标题长度、内容长度、引擎权重"""
    score = engine_weights.get(result["engine"], 1.0)
    title = result.get("title", "")
    content = result.get("content", "")
    # 有内容的加分
    if content and len(content) > 50:
        score += 0.5
    if title and len(title) > 10:
        score += 0.3
    return score


def aggregate_results(all_results: list[dict]) -> list[dict]:
    """去重 + 排序 + 编号"""
    seen_urls = {}
    unique = []

    for r in all_results:
        url = r.get("url", "")
        if not url or url.startswith("javascript:"):
            continue
        h = _url_hash(url)
        if h not in seen_urls:
            seen_urls[h] = r
            unique.append(r)
        else:
            # 合并内容：保留更长的 snippet
            existing = seen_urls[h]
            if len(r.get("content", "")) > len(existing.get("content", "")):
                existing["content"] = r["content"]
            # 记录多引擎来源
            engines = existing.get("engines", [existing["engine"]])
            if r["engine"] not in engines:
                engines.append(r["engine"])
            existing["engines"] = engines

    # 引擎权重
    weights = {
        "google": 3.0,
        "bing": 2.5,
        "duckduckgo": 2.0,
        "baidu": 2.0,
        "sogou": 1.5,
        "wikipedia": 2.5,
    }

    for r in unique:
        r["score"] = round(_score_result(r, weights), 2)

    unique.sort(key=lambda x: x["score"], reverse=True)

    # 编号
    for i, r in enumerate(unique, 1):
        r["position"] = i

    return unique


# ─── API 路由 ────────────────────────────────────────────

@app.get("/search", response_class=None)
async def search(
    q: str = Query(..., description="搜索关键词"),
    engines: Optional[str] = Query(None, description="指定引擎，逗号分隔"),
    language: str = Query("zh-CN", description="语言代码"),
    pageno: int = Query(1, ge=1, description="页码"),
    format: str = Query("json", description="返回格式: json 或 html"),
):
    """
    聚合搜索 API
    - format=json: 返回 JSON 格式
    - format=html: 返回 HTML 页面
    """
    start_time = time.time()

    # 引擎选择
    all_engines = ["google", "bing", "duckduckgo", "baidu", "sogou", "wikipedia"]
    if engines:
        selected = [e.strip().lower() for e in engines.split(",")]
        all_engines = [e for e in selected if e in all_engines]

    engine_map = {
        "google": search_google,
        "bing": search_bing,
        "duckduckgo": search_duckduckgo,
        "baidu": search_baidu,
        "sogou": search_sogou,
        "wikipedia": search_wikipedia,
    }

    # 并发请求所有引擎
    async with httpx.AsyncClient(
        timeout=TIMEOUT,
        verify=False,
        follow_redirects=True,
    ) as client:
        tasks = [
            engine_map[name](client, q, language)
            for name in all_engines
            if name in engine_map
        ]
        engine_results = await asyncio.gather(*tasks)

    # 合并所有结果
    all_results = []
    engine_stats = {}
    for name, results in zip(all_engines, engine_results):
        engine_stats[name] = len(results)
        all_results.extend(results)

    # 聚合排序
    aggregated = aggregate_results(all_results)

    elapsed = round(time.time() - start_time, 3)

    # HTML 格式
    if format.lower() == "html":
        return _render_html(q, aggregated, engine_stats, elapsed)

    # JSON 格式（默认）
    return JSONResponse(content={
        "query": q,
        "number_of_results": len(aggregated),
        "results": aggregated,
        "engines": engine_stats,
        "time_taken": f"{elapsed}s",
        "pageno": pageno,
    })


@app.get("/health")
async def health():
    """健康检查"""
    return {"status": "ok", "service": "Yanler Search API"}


@app.get("/")
async def root():
    """API 信息"""
    return {
        "name": "Yanler Search API",
        "version": "1.0.0",
        "endpoints": {
            "/search?q=关键词": "聚合搜索（支持 &engines=google,bing&language=zh-CN）",
            "/search?q=关键词&format=html": "HTML 格式搜索结果",
            "/test-adblock": "广告拦截测试页面",
            "/health": "健康检查",
        },
        "available_engines": ["google", "bing", "duckduckgo", "baidu", "sogou", "wikipedia"],
    }


@app.get("/test-adblock", response_class=HTMLResponse)
async def test_adblock():
    """广告拦截测试页面"""
    test_html = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Yanler 广告拦截测试</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, sans-serif; background: #1a1a1e; color: #e8e6e3; padding: 20px; }
        h1 { text-align: center; margin-bottom: 20px; background: linear-gradient(135deg, #5B7FFF, #8B5CFF, #FF5C7B); -webkit-background-clip: text; -webkit-text-fill-color: transparent; font-size: 28px; }
        .section { background: #222226; border-radius: 12px; padding: 16px; margin-bottom: 16px; border: 1px solid #2e2e32; }
        .section h2 { font-size: 14px; color: #9e9ea6; margin-bottom: 12px; }
        .test-item { padding: 10px; margin: 6px 0; border-radius: 8px; font-size: 13px; }
        .blocked { background: #2a1a1a; border: 1px solid #ff4444; }
        .allowed { background: #1a2a1a; border: 1px solid #44ff44; }
        .ad-banner { background: linear-gradient(90deg, #ff6b6b, #ffa500); padding: 20px; text-align: center; border-radius: 8px; margin: 8px 0; color: white; font-weight: bold; }
        .status { text-align: center; padding: 16px; font-size: 16px; border-radius: 12px; margin-top: 16px; }
        .status.ok { background: #1a2a1a; border: 2px solid #44ff44; }
        code { background: #323236; padding: 2px 6px; border-radius: 4px; font-size: 12px; }
    </style>
</head>
<body>
    <h1>Yanler 广告拦截测试页</h1>
    <div class="section">
        <h2>测试 1：广告域名脚本（应被拦截）</h2>
        <div class="test-item blocked">Google Ads — <code>pagead2.googlesyndication.com</code>
        <script src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js" onerror="this.parentElement.innerHTML='✓ 已拦截: Google Ads 脚本被阻止'"></script></div>
        <div class="test-item blocked">百度统计 — <code>hm.baidu.com</code>
        <script src="https://hm.baidu.com/hm.js?test123" onerror="this.parentElement.innerHTML='✓ 已拦截: 百度统计脚本被阻止'"></script></div>
        <div class="test-item blocked">腾讯广告 — <code>ad.qq.com</code>
        <script src="https://ad.qq.com/sdk.js" onerror="this.parentElement.innerHTML='✓ 已拦截: 腾讯广告脚本被阻止'"></script></div>
        <div class="test-item blocked">Doubleclick — <code>doubleclick.net</code>
        <script src="https://ad.doubleclick.net/activity" onerror="this.parentElement.innerHTML='✓ 已拦截: Doubleclick 脚本被阻止'"></script></div>
        <div class="test-item blocked">阿里妈妈 — <code>alimama.com</code>
        <script src="https://alimama.com/ad.js" onerror="this.parentElement.innerHTML='✓ 已拦截: 阿里妈妈脚本被阻止'"></script></div>
    </div>
    <div class="section">
        <h2>测试 2：正常内容（应放行）</h2>
        <div class="test-item allowed">正常网页 — <code>https://www.example.com</code></div>
        <div class="test-item allowed">正常 API — <code>https://api.example.com/data</code></div>
    </div>
    <div class="status ok" id="result">
        如果广告域名脚本全部显示 "✓ 已拦截"，说明广告过滤引擎工作正常！<br>
        <small>底部栏盾牌图标会显示已拦截的数量</small>
    </div>
    <script>
        setTimeout(() => {
            const blocked = document.querySelectorAll('.blocked');
            let passed = 0;
            blocked.forEach(el => { if (el.textContent.includes('已拦截')) passed++; });
            document.getElementById('result').innerHTML =
                `测试完成：${passed}/${blocked.length} 个广告资源被成功拦截<br><small>底部栏盾牌图标会显示已拦截的数量</small>`;
        }, 3000);
    </script>
</body>
</html>"""
    return test_html


def _render_html(query: str, results: list[dict], engines: dict, elapsed: float) -> str:
    """渲染 HTML 搜索结果页面"""
    result_html = ""
    for r in results:
        engines_badges = "".join(
            f'<span class="engine">{e}</span>' for e in r.get("engines", [r["engine"]])
        )
        result_html += f"""
        <div class="result">
            <a href="{r['url']}" class="title" target="_blank">{r['title']}</a>
            <div class="url">{r['url'][:80]}{'...' if len(r['url']) > 80 else ''}</div>
            <div class="snippet">{r['content']}</div>
            <div class="meta">{engines_badges}<span class="score">{r['score']}</span></div>
        </div>
        """

    engines_info = " | ".join(f"{k}: {v}" for k, v in engines.items())

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{query} - Yanler Search</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a1e;
            color: #e8e6e3;
            line-height: 1.6;
        }}
        .header {{
            background: linear-gradient(135deg, #5B7FFF 0%, #8B5CFF 50%, #FF5C7B 100%);
            padding: 20px;
            text-align: center;
        }}
        .header h1 {{
            font-size: 24px;
            font-weight: 300;
            letter-spacing: 4px;
            color: white;
        }}
        .search-box {{
            max-width: 600px;
            margin: -25px auto 20px;
            padding: 0 20px;
        }}
        .search-box form {{
            display: flex;
            background: #2a2a2e;
            border-radius: 24px;
            overflow: hidden;
            border: 1px solid #3a3a3e;
        }}
        .search-box input {{
            flex: 1;
            padding: 14px 20px;
            background: transparent;
            border: none;
            color: #e8e6e3;
            font-size: 15px;
            outline: none;
        }}
        .search-box button {{
            padding: 14px 24px;
            background: linear-gradient(135deg, #5B7FFF, #8B5CFF);
            border: none;
            color: white;
            cursor: pointer;
            font-size: 16px;
        }}
        .stats {{
            max-width: 700px;
            margin: 0 auto 20px;
            padding: 0 20px;
            color: #9e9ea6;
            font-size: 13px;
        }}
        .results {{
            max-width: 700px;
            margin: 0 auto;
            padding: 0 20px 40px;
        }}
        .result {{
            background: #222226;
            border-radius: 12px;
            padding: 18px;
            margin-bottom: 14px;
            border: 1px solid #2e2e32;
            transition: all 0.2s;
        }}
        .result:hover {{
            border-color: #5B7FFF;
            transform: translateY(-2px);
        }}
        .result .title {{
            color: #7B9FFF;
            text-decoration: none;
            font-size: 16px;
            font-weight: 500;
            display: block;
            margin-bottom: 6px;
        }}
        .result .title:hover {{ color: #a0b3ff; }}
        .result .url {{
            color: #6b6b73;
            font-size: 12px;
            margin-bottom: 8px;
            word-break: break-all;
        }}
        .result .snippet {{
            color: #c8c6c3;
            font-size: 14px;
            line-height: 1.5;
        }}
        .result .meta {{
            margin-top: 10px;
            display: flex;
            align-items: center;
            gap: 6px;
            flex-wrap: wrap;
        }}
        .engine {{
            background: #323236;
            color: #9e9ea6;
            padding: 2px 8px;
            border-radius: 10px;
            font-size: 11px;
        }}
        .score {{
            color: #8B5CFF;
            font-size: 12px;
            font-weight: 600;
            margin-left: auto;
        }}
        .no-results {{
            text-align: center;
            padding: 60px 20px;
            color: #6b6b73;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>YANLER SEARCH</h1>
    </div>
    <div class="search-box">
        <form action="/search" method="get">
            <input type="text" name="q" value="{query}" placeholder="搜索..." autofocus>
            <input type="hidden" name="format" value="html">
            <button type="submit">→</button>
        </form>
    </div>
    <div class="stats">
        找到 {len(results)} 条结果 — {engines_info} — {elapsed}s
    </div>
    <div class="results">
        {''.join(result_html) if result_html else '<div class="no-results">没有找到结果，请尝试其他关键词</div>'}
    </div>
</body>
</html>"""


# ─── 启动 ────────────────────────────────────────────────

if __name__ == "__main__":
    print(f"""
╔══════════════════════════════════════════════╗
║         Yanler Search API v1.0.0             ║
║   聚合搜索引擎 — Google/Bing/DDG/Baidu/Sogou  ║
║                                              ║
║   API:  http://localhost:{PORT}/search?q=test    ║
║   JSON: http://localhost:{PORT}/search?q=test&format=json ║
╚══════════════════════════════════════════════╝
    """)
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")
