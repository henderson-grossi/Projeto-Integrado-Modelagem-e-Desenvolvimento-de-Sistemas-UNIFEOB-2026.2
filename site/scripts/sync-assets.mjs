// Copia do app (rvlabel_app) o que o site reaproveita: catálogo, fotos, fontes e ícones.
// Uso: npm run sync            (o app é a pasta de cima, ou ../rvlabel_app se o site estiver solto)
//      RVLABEL_APP=D:\caminho\rvlabel_app npm run sync
import { cpSync, existsSync, mkdirSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const aqui = path.dirname(fileURLToPath(import.meta.url));
const site = path.resolve(aqui, "..");
const dentroDoApp = existsSync(path.join(site, "..", "assets", "catalogo.json"));
const app = path.resolve(process.env.RVLABEL_APP ?? path.join(site, "..", dentroDoApp ? "" : "rvlabel_app"));
const publico = path.join(site, "public");

if (!existsSync(path.join(app, "assets", "catalogo.json"))) {
  console.error(`Não achei o app em ${app}. Aponte com RVLABEL_APP=<pasta do rvlabel_app>.`);
  process.exit(1);
}

const copiar = (de, para) => {
  mkdirSync(path.dirname(para), { recursive: true });
  cpSync(de, para);
  console.log("copiado:", path.relative(site, para));
};

copiar(path.join(app, "assets", "catalogo.json"), path.join(publico, "catalogo.json"));

const fotos = path.join(app, "assets", "fotos");
for (const f of readdirSync(fotos).filter((n) => /\.(jpe?g|png|webp)$/i.test(n))) {
  copiar(path.join(fotos, f), path.join(publico, "fotos", f));
}

const fontes = path.join(app, "assets", "fonts");
for (const f of readdirSync(fontes)) copiar(path.join(fontes, f), path.join(publico, "fonts", f));

copiar(path.join(app, "web", "favicon.png"), path.join(publico, "favicon.png"));
copiar(path.join(app, "web", "icons", "Icon-192.png"), path.join(publico, "icon-192.png"));
copiar(path.join(app, "web", "icons", "Icon-512.png"), path.join(publico, "icon-512.png"));
copiar(path.join(app, "assets", "icon", "og.png"), path.join(publico, "og.png"));
