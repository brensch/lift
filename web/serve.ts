import { serve } from "bun";

const backendUrl = process.env.BACKEND_URL || "http://localhost:50051";

serve({
  port: 4173,
  async fetch(req) {
    const url = new URL(req.url);

    // Proxy API requests to backend (gRPC-Web)
    if (url.pathname.startsWith("/workout.v1.")) {
        // Construct backend URL
        const target = backendUrl + url.pathname + url.search;
        console.log(`Proxying ${url.pathname} to ${target}`);
        
        try {
            const backendRes = await fetch(target, {
                method: req.method,
                headers: req.headers,
                body: req.body,
            });
            return new Response(backendRes.body, {
                status: backendRes.status,
                headers: backendRes.headers,
            });
        } catch (e) {
            console.error("Proxy error:", e);
            return new Response("Backend unavailable", { status: 502 });
        }
    }

    let path = url.pathname;
    if (path === "/") path = "/index.html";
    
    let file = Bun.file(`./dist${path}`);
    
    // SPA fallback
    // Check if file exists, if not serve index.html
    // Note: checking existence sync or async.
    // Bun.file doesn't block.
    // But we need to know if it exists.
    
    // Simple logic: if extension is missing, assume route -> index.html
    if (!path.split("/").pop()?.includes(".")) {
        return new Response(Bun.file("./dist/index.html"));
    }
    
    return new Response(file);
  }
});
console.log(`Preview server running on http://localhost:4173, proxying to ${backendUrl}`);
