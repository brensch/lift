import { build, type BunPlugin } from "bun";
import { watch } from "fs";
import { mkdir } from "fs/promises";

console.log("Starting dev server...");

await mkdir("./dist", { recursive: true });

const removeCssPlugin: BunPlugin = {
  name: "remove-css",
  setup(build) {
    build.onLoad({ filter: /\.css$/ }, () => ({ contents: "", loader: "js" }));
  },
};

// Start Tailwind watcher
Bun.spawn([process.argv[0], "x", "tailwindcss", "-i", "./src/index.css", "-o", "./dist/index.css", "--watch"], {
  stdout: "inherit",
  stderr: "inherit",
});

// Build logic
async function buildMain() {
  console.log("Building main.js...");
  const result = await build({
    entrypoints: ["./src/main.tsx"],
    target: "browser",
    plugins: [removeCssPlugin],
  });
  if (!result.success) {
    console.error("Build failed:", result.logs);
    return null;
  }
  return result.outputs[0];
}

let currentBuild = await buildMain();
let subscribers: Array<(val: any) => void> = [];

// Watch for changes and rebuild
watch("./src", { recursive: true }, async (event, filename) => {
  console.log(`File ${filename} changed, rebuilding...`);
  currentBuild = await buildMain();
  subscribers.forEach((s) => s("reload"));
});

// Dev server
const server = Bun.serve({
  port: 5173,
  async fetch(req, server) {
    const url = new URL(req.url);

    if (url.pathname === "/ws") {
      if (server.upgrade(req)) return;
      return new Response("Upgrade failed", { status: 400 });
    }

    // Proxy API requests
    if (url.pathname.startsWith("/workout.v1.")) {
      try {
        const res = await fetch("http://localhost:50051" + url.pathname + url.search, {
          method: req.method,
          headers: req.headers,
          body: req.body,
        });
        return new Response(res.body, { status: res.status, headers: res.headers });
      } catch {
        return new Response("Backend unavailable", { status: 502 });
      }
    }

    // Serve index.html (SPA fallback)
    if (url.pathname === "/" || url.pathname === "/index.html" || !url.pathname.includes(".")) {
      const html = await Bun.file("./index.html").text();
      const newHtml = html
        .replace(
          '<script type="module" src="/src/main.tsx"></script>',
          `<script src="/main.js"></script>
                <script>
                    const ws = new WebSocket('ws://' + location.host + '/ws');
                    ws.onmessage = (e) => { if (e.data === 'reload') location.reload(); };
                    ws.onclose = () => setTimeout(() => location.reload(), 2000);
                </script>`
        )
        .replace("</head>", '<link rel="stylesheet" href="/index.css"></head>');
      return new Response(newHtml, { headers: { "Content-Type": "text/html" } });
    }

    if (url.pathname === "/main.js") {
      if (!currentBuild) return new Response("Build failed", { status: 500 });
      return new Response(currentBuild);
    }

    if (url.pathname === "/index.css") {
      const file = Bun.file("./dist/index.css");
      if (await file.exists()) return new Response(file);
      return new Response("/* building css */", { headers: { "Content-Type": "text/css" } });
    }

    const file = Bun.file("." + url.pathname);
    if (await file.exists()) return new Response(file);

    return new Response("Not Found", { status: 404 });
  },
  websocket: {
    open(ws) {
      const cb = (msg: any) => ws.send(msg);
      (ws as any).cb = cb;
      subscribers.push(cb);
    },
    close(ws) {
      subscribers = subscribers.filter((s) => s !== (ws as any).cb);
    },
    message() {},
  },
});

console.log(`Listening on http://localhost:${server.port}`);
