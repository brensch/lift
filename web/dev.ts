import { build, type BunPlugin } from "bun";
import { mkdir } from "fs/promises";

console.log("Starting dev server...");

// Ensure dist exists for tailwind
await mkdir("./dist", { recursive: true });

// Plugin to ignore CSS imports in JS
const removeCssPlugin: BunPlugin = {
  name: "remove-css",
  setup(build) {
    build.onLoad({ filter: /\.css$/ }, () => ({
      contents: "",
      loader: "js",
    }));
  },
};

// 1. Start Tailwind watcher
// Output to ./dist/index.css so the server can serve it.
// Use process.argv[0] to ensure we use the current bun executable
const bunExe = process.argv[0];
console.log(`Starting Tailwind with: ${bunExe} x tailwindcss...`);

const tailwindProc = Bun.spawn([bunExe, "x", "tailwindcss", "-i", "./src/index.css", "-o", "./dist/index.css", "--watch"], {
    stdout: "inherit",
    stderr: "inherit",
    onExit(proc, exitCode, signalCode, error) {
        if (exitCode !== 0) {
            console.error(`Tailwind process exited with code ${exitCode} and signal ${signalCode}`);
            if (error) console.error("Tailwind error:", error);
        }
    },
});

// 2. Start Server
const server = Bun.serve({
  port: 5173,
  async fetch(req) {
    const url = new URL(req.url);
    
    // Serve index.html (modified)
    if (url.pathname === "/" || url.pathname === "/index.html") {
        const html = await Bun.file("./index.html").text();
        // Inject script and css
        const newHtml = html
            .replace('<script type="module" src="/src/main.tsx"></script>', '<script src="/main.js"></script>')
            .replace('</head>', '<link rel="stylesheet" href="/index.css"></head>');
        return new Response(newHtml, { headers: { "Content-Type": "text/html" } });
    }

    // Serve main.js (built on fly)
    if (url.pathname === "/main.js") {
        const result = await build({
            entrypoints: ["./src/main.tsx"],
            target: "browser",
            plugins: [removeCssPlugin],
        });
        return new Response(result.outputs[0]);
    }

    // Serve CSS (from tailwind watcher)
    if (url.pathname === "/index.css") {
        const file = Bun.file("./dist/index.css");
        if (await file.exists()) return new Response(file);
        // If not ready yet
        return new Response("/* building css */", { headers: { "Content-Type": "text/css" } });
    }

    // Fallback to static files
    const file = Bun.file("." + url.pathname);
    if (await file.exists()) return new Response(file);
    
    // SPA Fallback
    // If not found and is not an asset (basic heuristic), return index.html
    if (!url.pathname.includes(".")) {
         const html = await Bun.file("./index.html").text();
        const newHtml = html
            .replace('<script type="module" src="/src/main.tsx"></script>', '<script src="/main.js"></script>')
            .replace('</head>', '<link rel="stylesheet" href="/index.css"></head>');
        return new Response(newHtml, { headers: { "Content-Type": "text/html" } });
    }

    return new Response("Not Found", { status: 404 });
  },
});

console.log(`Listening on http://localhost:${server.port}`);
