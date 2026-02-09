import { build, type BunPlugin } from "bun";
import { rm } from "fs/promises";

console.log("Cleaning dist...");
await rm("./dist", { recursive: true, force: true });

// Plugin to ignore CSS imports in JS (since we handle CSS via Tailwind CLI)
const removeCssPlugin: BunPlugin = {
  name: "remove-css",
  setup(build) {
    build.onLoad({ filter: /\.css$/ }, () => ({
      contents: "",
      loader: "js",
    }));
  },
};

console.log("Building JS...");
await build({
  entrypoints: ["./src/main.tsx"],
  outdir: "./dist",
  target: "browser",
  minify: true,
  naming: "[dir]/[name].[ext]", // ensure main.js
  plugins: [removeCssPlugin],
});

console.log("Building CSS...");
const tailwindProc = Bun.spawn(["bun", "x", "tailwindcss", "-i", "./src/index.css", "-o", "./dist/index.css", "--minify"]);
await tailwindProc.exited;

console.log("Copying HTML...");
const html = await Bun.file("./index.html").text();
const newHtml = html
  .replace('<script type="module" src="/src/main.tsx"></script>', '<script src="/main.js"></script>')
  .replace('</head>', '<link rel="stylesheet" href="/index.css"></head>');

await Bun.write("./dist/index.html", newHtml);

console.log("Build complete! Output in ./dist");
