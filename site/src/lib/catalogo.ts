import { API_URL, getJson } from "./api";

/** Categorias do catálogo (mesmos nomes do app: lib/models/categoria.dart). */
export const CATEGORIAS = {
  blusas: "Blusas",
  vestidos: "Vestidos",
  tops: "Tops",
  bodys: "Bodys",
  shorts: "Shorts",
  acessorios: "Acessórios",
} as const;
export type Categoria = keyof typeof CATEGORIAS;

/** Uma cor da peça: a foto original é recolorida (hue gira o matiz; tom pinta mantendo a luz). */
export interface Cor {
  nome: string;
  hue: number;
  tom?: string;
}

export interface Peca {
  id: string;
  nome: string;
  categoria: Categoria;
  tipo: "peca" | "acessorio";
  descricao: string;
  preco: number | null; // null = "preço a combinar"
  fotos: string[];
  fotoCostas?: string;
  cores: Cor[];
  tamanhos: string[];
  material?: string;
}

const BASE = import.meta.env.BASE_URL;

/** "assets/fotos/x.jpg" (caminho do app) -> URL pública do site. */
export function urlFoto(caminho: string): string {
  if (/^https?:\/\//.test(caminho)) return caminho;
  return `${BASE}${caminho.replace(/^\/?assets\//, "").replace(/^\//, "")}`;
}

const texto = (v: unknown): string => (typeof v === "string" ? v : "");

function normalizarPeca(j: Record<string, unknown>): Peca {
  const categoria = texto(j.categoria);
  if (!(categoria in CATEGORIAS)) throw new Error(`categoria desconhecida: "${categoria}"`);
  const id = texto(j.id);
  const nome = texto(j.nome);
  if (!id || !nome) throw new Error("peça sem id ou nome");

  const tipo = j.tipo === "acessorio" ? "acessorio" : "peca";
  const cores: Cor[] = (Array.isArray(j.cores) ? j.cores : [])
    .map((c: Record<string, unknown>) => ({
      nome: texto(c.nome),
      hue: Number(c.hue ?? 0) || 0,
      tom: typeof c.tom === "string" ? c.tom : undefined,
    }))
    .filter((c) => c.nome);
  const tamanhos =
    tipo === "acessorio"
      ? ["Único"]
      : Array.isArray(j.tamanhos) && j.tamanhos.length
        ? j.tamanhos.map(String)
        : ["P", "M", "G"];
  const preco = j.preco == null || j.preco === "" ? null : Number(j.preco);

  return {
    id,
    nome,
    categoria: categoria as Categoria,
    tipo,
    descricao: texto(j.descricao),
    preco: preco != null && Number.isFinite(preco) ? preco : null,
    fotos: (Array.isArray(j.fotos) ? j.fotos : []).map(String).map(urlFoto),
    fotoCostas: typeof j.fotoCostas === "string" ? urlFoto(j.fotoCostas) : undefined,
    cores: cores.length ? cores : [{ nome: "Única", hue: 0 }],
    tamanhos,
    material: typeof j.material === "string" ? j.material : undefined,
  };
}

/**
 * Monta o catálogo a partir do JSON. Peça inválida (ex.: categoria desconhecida) é ignorada, não derruba o site.
 * O campo `ativo` do catalogo.json é ignorado: quem decide o que está ativo é a API.
 */
export function normalizarCatalogo(dados: unknown): Peca[] {
  const lista = dados && typeof dados === "object" ? (dados as { pecas?: unknown }).pecas : null;
  if (!Array.isArray(lista)) throw new Error("catálogo inválido: falta a lista 'pecas'");
  const pecas: Peca[] = [];
  for (const p of lista) {
    try {
      pecas.push(normalizarPeca(p as Record<string, unknown>));
    } catch (e) {
      console.warn("Peça ignorada:", (p as { id?: unknown })?.id, e);
    }
  }
  return pecas;
}

const CHAVE_CACHE = "rvlabel:catalogo-api";

function lerCache(): unknown {
  try {
    const t = localStorage.getItem(CHAVE_CACHE);
    return t ? JSON.parse(t) : null;
  } catch {
    return null;
  }
}

function guardarCache(dados: unknown): void {
  try {
    localStorage.setItem(CHAVE_CACHE, JSON.stringify(dados));
  } catch {
    // navegador sem armazenamento (aba privada, cota cheia): segue sem cópia
  }
}

/**
 * Catálogo do site, com a mesma lógica do app (lib/services/catalogo_repository.dart):
 * 1. Com a API, a vitrine é o `GET /produtos`, que só traz o que a administradora ativou no painel. A resposta
 *    fica guardada no navegador.
 * 2. Se a API não responder, usa a última resposta guardada.
 * 3. Sem API configurada, ou sem nenhuma resposta guardada, usa o catalogo.json inteiro (ignora `ativo`).
 * O Render gratuito dorme e pode levar perto de um minuto para acordar; com cópia guardada, espera menos.
 */
export async function carregarCatalogo(): Promise<Peca[]> {
  if (API_URL) {
    const cache = lerCache();
    try {
      const dados = await getJson(`${API_URL}/produtos`, cache ? 8000 : 60000);
      const pecas = normalizarCatalogo(dados);
      guardarCache(dados);
      return pecas;
    } catch (e) {
      console.warn("API do catálogo indisponível:", e);
      if (cache) {
        try {
          return normalizarCatalogo(cache);
        } catch {
          // cópia estragada: cai no catalogo.json
        }
      }
    }
  }
  return normalizarCatalogo(await getJson(`${BASE}catalogo.json`, 10000));
}

export const precoTexto = (p: Peca, formatar: (v: number) => string): string =>
  p.preco == null ? "Preço a combinar" : formatar(p.preco);
