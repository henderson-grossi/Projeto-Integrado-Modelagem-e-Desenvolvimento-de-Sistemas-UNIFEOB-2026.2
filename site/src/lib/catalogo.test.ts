import { describe, expect, it, vi } from "vitest";
import { normalizarCatalogo, urlFoto } from "./catalogo";
import { COLECOES, pecasDaColecao, primeiraFoto } from "./colecoes";

const peca = (extra: Record<string, unknown> = {}) => ({
  id: "essence-005",
  nome: "Blusa",
  categoria: "blusas",
  preco: 72.9,
  fotos: ["assets/fotos/blusa.jpg"],
  cores: [{ nome: "Preto" }, { nome: "Vinho", tom: "#7A1020" }],
  ...extra,
});

describe("catálogo", () => {
  it("troca o caminho de foto do app pela URL do site", () => {
    expect(urlFoto("assets/fotos/x.jpg")).toBe("/fotos/x.jpg");
    expect(urlFoto("https://exemplo.com/x.jpg")).toBe("https://exemplo.com/x.jpg");
  });

  it("normaliza peça, cores e tamanhos padrão", () => {
    const [p] = normalizarCatalogo({ pecas: [peca()] });
    expect(p.fotos).toEqual(["/fotos/blusa.jpg"]);
    expect(p.cores[1]).toEqual({ nome: "Vinho", hue: 0, tom: "#7A1020" });
    expect(p.tamanhos).toEqual(["P", "M", "G"]);
    expect(p.preco).toBe(72.9);
  });

  it("acessório tem tamanho único e preço ausente vira 'a combinar'", () => {
    const [p] = normalizarCatalogo({ pecas: [peca({ tipo: "acessorio", tamanhos: ["P"], preco: null, cores: [] })] });
    expect(p.tamanhos).toEqual(["Único"]);
    expect(p.preco).toBeNull();
    expect(p.cores).toEqual([{ nome: "Única", hue: 0 }]);
  });

  it("ignora peça com categoria desconhecida em vez de quebrar (caso real: 'Body')", () => {
    const aviso = vi.spyOn(console, "warn").mockImplementation(() => {});
    const pecas = normalizarCatalogo({ pecas: [peca(), peca({ id: "demo-1", categoria: "Body" })] });
    expect(pecas.map((p) => p.id)).toEqual(["essence-005"]);
    aviso.mockRestore();
  });

  it("mostra a peça mesmo com ativo=false no JSON: esse campo é só do app, o site mostra o catálogo inteiro", () => {
    const pecas = normalizarCatalogo({ pecas: [peca({ id: "a", ativo: false }), peca({ id: "b" })] });
    expect(pecas.map((p) => p.id)).toEqual(["a", "b"]);
  });

  it("rejeita JSON sem a lista de peças", () => {
    expect(() => normalizarCatalogo({})).toThrow();
    expect(() => normalizarCatalogo(null)).toThrow();
  });
});

describe("coleções", () => {
  it("toda categoria cai em alguma coleção", () => {
    const cobertas = new Set(COLECOES.flatMap((c) => c.categorias));
    expect([...cobertas].sort()).toEqual(["acessorios", "blusas", "bodys", "shorts", "tops", "vestidos"]);
  });

  it("filtra as peças da coleção e acha a primeira foto", () => {
    const pecas = normalizarCatalogo({
      pecas: [peca({ id: "a", fotos: [] }), peca({ id: "b", categoria: "vestidos" }), peca({ id: "c", categoria: "tops" })],
    });
    const cima = pecasDaColecao(COLECOES[0], pecas);
    expect(cima.map((p) => p.id)).toEqual(["a", "c"]);
    expect(primeiraFoto(cima)).toBe("/fotos/blusa.jpg");
    expect(primeiraFoto([])).toBeUndefined();
  });
});

describe("origem do catálogo", () => {
  /** Carrega o módulo com a API e um fetch falso; `api` responde à rota /produtos (null = API fora do ar). */
  async function carregar(api: unknown, guardado: Record<string, string> = {}) {
    vi.resetModules();
    vi.stubEnv("VITE_API_URL", "http://localhost:3000");
    const pedidos: string[] = [];
    vi.stubGlobal("localStorage", {
      getItem: (k: string) => guardado[k] ?? null,
      setItem: (k: string, v: string) => (guardado[k] = v),
    });
    vi.stubGlobal("fetch", async (url: string) => {
      pedidos.push(String(url));
      if (String(url).endsWith("/produtos")) {
        if (api === null) throw new TypeError("Failed to fetch");
        return new Response(JSON.stringify(api));
      }
      return new Response(JSON.stringify({ pecas: [peca({ id: "so-no-json" })] }));
    });
    const { carregarCatalogo } = await import("./catalogo");
    try {
      return { ids: (await carregarCatalogo()).map((p) => p.id), pedidos, guardado };
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  }

  it("com a API, a vitrine é só o que ela devolve (o que a administradora ativou) e fica guardada", async () => {
    const r = await carregar({ pecas: [peca({ id: "ativa" })] });
    expect(r.ids).toEqual(["ativa"]);
    expect(r.pedidos).toEqual(["http://localhost:3000/produtos"]);
    expect(Object.values(r.guardado)[0]).toContain("ativa");
  });

  it("com a API ativa e nada ativado, a vitrine fica vazia (não cai no catalogo.json)", async () => {
    expect((await carregar({ pecas: [] })).ids).toEqual([]);
  });

  it("API fora do ar: usa a última resposta guardada", async () => {
    const guardado = { "rvlabel:catalogo-api": JSON.stringify({ pecas: [peca({ id: "da-ultima-vez" })] }) };
    expect((await carregar(null, guardado)).ids).toEqual(["da-ultima-vez"]);
  });

  it("API fora do ar e nada guardado: usa o catalogo.json", async () => {
    const r = await carregar(null);
    expect(r.ids).toEqual(["so-no-json"]);
    expect(r.pedidos[1]).toMatch(/catalogo\.json$/);
  });
});
