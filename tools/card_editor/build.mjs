// index.src.html 의 인라인 표시를 card_model.js 내용으로 바꿔 dist/card-editor.html 하나로 만든다.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const MARK = "<!-- @inline card_model.js -->";
const src = readFileSync(join(here, "index.src.html"), "utf8");
if (!src.includes(MARK)) throw new Error("inline marker missing in index.src.html");
const model = readFileSync(join(here, "card_model.js"), "utf8");
mkdirSync(join(here, "dist"), { recursive: true });
writeFileSync(join(here, "dist", "card-editor.html"), src.replace(MARK, () => `<script>\n${model}\n</script>`));
console.log("built dist/card-editor.html");
