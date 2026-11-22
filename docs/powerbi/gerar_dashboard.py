"""Gera tema, medidas, o template visual (PowerPoint) e as 6 páginas do dashboard RV Label no projeto .pbip
(formato PBIR + TMDL). O fundo de cada página é um slide do template exportado como imagem pelo PowerPoint.
Uso: python -I docs/powerbi/gerar_dashboard.py docs/powerbi/projeto
(Windows com PowerPoint e as fontes Segoe; pip install python-pptx). Depois, abra o .pbip no Power BI e clique em Atualizar."""
import sys, json, re, shutil, subprocess, tempfile
from pathlib import Path

raiz = Path(sys.argv[1])
REP = raiz / "Rv_label-simulacao.Report"
MOD = raiz / "Rv_label-simulacao.SemanticModel" / "definition" / "tables"

# ---------------- identidade (docs/DESIGN.md) + paleta validada (dataviz, modo escuro) ----------------
BG, SURF, RAISED, BORDA = "#0B0B0C", "#141416", "#1C1C1F", "#2A2A2E"
TXT, TXT2, TXT3 = "#F4F1EE", "#A8A3A0", "#6E6A68"
SERIES = ["#D9363E", "#3987E5", "#199E70", "#C98500", "#9085E9", "#D55181"]
OK, ATENCAO, RUIM = "#2E9E6A", "#D9A441", "#E5484D"
FONTE, FONTE_FORTE = "Segoe UI", "Segoe UI Semibold"
PAINEL, PAINEL_ALT, PAINEL_CAB = RAISED, "#202023", "#26262A"  # painéis do fundo (modelo do usuário)

def solid(c): return {"solid": {"color": c}}
tema = {
    "name": "RV Label Escuro",
    "dataColors": SERIES,
    "background": BG, "foreground": TXT, "tableAccent": SERIES[0],
    "good": OK, "neutral": ATENCAO, "bad": RUIM,
    "maximum": SERIES[0], "center": TXT3, "minimum": SERIES[1],
    "textClasses": {
        "callout": {"fontFace": "Segoe UI Light", "fontSize": 26, "color": TXT},
        "title": {"fontFace": FONTE_FORTE, "fontSize": 12, "color": TXT},
        "header": {"fontFace": FONTE_FORTE, "fontSize": 12, "color": TXT},
        "label": {"fontFace": FONTE, "fontSize": 10, "color": TXT2},
    },
    "visualStyles": {
        "*": {"*": {
            # painel arredondado vem da imagem de fundo da página; o visual fica transparente por cima
            "background": [{"show": False}],
            "border": [{"show": False}],
            "padding": [{"top": 12, "bottom": 12, "left": 16, "right": 16}],
            "title": [{"show": True, "fontColor": solid(TXT), "fontSize": 12, "fontFamily": FONTE_FORTE}],
            "categoryAxis": [{"labelColor": solid(TXT2), "titleColor": solid(TXT2), "showAxisTitle": False,
                              "gridlineShow": False}],
            "valueAxis": [{"labelColor": solid(TXT2), "titleColor": solid(TXT2), "showAxisTitle": False,
                           "gridlineColor": solid(BORDA), "gridlineStyle": "dotted"}],
            "legend": [{"labelColor": solid(TXT2), "position": "Top"}],
            "labels": [{"color": solid(TXT)}],
            "visualHeader": [{"background": solid(PAINEL), "foreground": solid(TXT2), "border": solid(PAINEL)}],
            "visualTooltip": [{"background": solid(RAISED), "titleFontColor": solid(TXT2), "valueFontColor": solid(TXT)}],
        }},
        "page": {"*": {
            "background": [{"color": solid(BG), "transparency": 0}],
            "outspace": [{"color": solid(BG), "transparency": 0}],
        }},
        "card": {"*": {
            "labels": [{"color": solid(TXT), "fontSize": 24, "fontFamily": FONTE_FORTE}],
            "categoryLabels": [{"show": True, "color": solid(TXT2), "fontSize": 10, "fontFamily": FONTE}],
        }},
        "tableEx": {"*": {
            "grid": [{"gridVertical": False, "gridHorizontal": True, "gridHorizontalColor": solid(BORDA),
                      "outlineColor": solid(BORDA), "rowPadding": 4}],
            "columnHeaders": [{"fontColor": solid(TXT2), "backColor": solid(PAINEL_CAB), "fontFamily": FONTE_FORTE}],
            "values": [{"fontColorPrimary": solid(TXT), "backColorPrimary": solid(PAINEL),
                        "fontColorSecondary": solid(TXT), "backColorSecondary": solid(PAINEL_ALT)}],
            "total": [{"fontColor": solid(TXT), "backColor": solid(PAINEL_CAB)}],
        }},
        "pivotTable": {"*": {
            "grid": [{"gridVertical": False, "gridHorizontal": True, "gridHorizontalColor": solid(BORDA),
                      "outlineColor": solid(BORDA), "rowPadding": 4}],
            "columnHeaders": [{"fontColor": solid(TXT2), "backColor": solid(PAINEL_CAB)}],
            "rowHeaders": [{"fontColor": solid(TXT), "backColor": solid(PAINEL)}],
            "values": [{"fontColorPrimary": solid(TXT), "backColorPrimary": solid(PAINEL),
                        "fontColorSecondary": solid(TXT), "backColorSecondary": solid(PAINEL_ALT)}],
            "subTotals": [{"fontColor": solid(TXT), "backColor": solid(PAINEL_CAB)}],
        }},
        "slicer": {"*": {
            "header": [{"fontColor": solid(TXT2), "fontFamily": FONTE, "textSize": 9}],
            "items": [{"fontColor": solid(TXT), "background": solid(PAINEL_CAB), "outlineColor": solid(BORDA)}],
        }},
        "textbox": {"*": {
            "background": [{"show": False}], "border": [{"show": False}],
        }},
    },
}

# ---------------- medidas (TMDL) ----------------
REAIS = r'"R$"\ #,0.00;-"R$"\ #,0.00;"R$"\ #,0.00'
PCT = "0.0%;-0.0%;0.0%"
ENTREGUE = 'fato_Vendas[Status_Pedido] = "Entregue"'
ULTIMO_MES = "LASTNONBLANK(dim_Calendario[Data], CALCULATE(COUNTROWS(fato_Estoque)))"
novas = {
    "fato_Vendas": [
        ("'Pedidos Entregues'", f"CALCULATE([Pedidos], {ENTREGUE})", "0"),
        ("'Itens Vendidos'", f"CALCULATE(SUM(fato_Vendas[Quantidade]), {ENTREGUE})", "#,0"),
        ("'Clientes Ativos'", f"CALCULATE(DISTINCTCOUNT(fato_Vendas[ID_Cliente]), {ENTREGUE})", "0"),
        ("'Pedidos por Cliente'", "DIVIDE([Pedidos Entregues], [Clientes Ativos])", "0.0"),
        ("'Desconto Concedido'", f"CALCULATE(SUM(fato_Vendas[Valor_Desconto]), {ENTREGUE})", REAIS),
        ("'Taxa de Cancelamento'", 'DIVIDE(CALCULATE(COUNTROWS(fato_Vendas), fato_Vendas[Status_Pedido] = "Cancelado"), COUNTROWS(fato_Vendas))', PCT),
        # Curva ABC: % do faturamento que as peças iguais ou maiores que esta somam (A até 80%, B até 95%)
        ("'% Acumulado'", "VAR f = [Faturamento] VAR tot = CALCULATE([Faturamento], ALLSELECTED(dim_Produtos)) "
                          "RETURN IF(NOT ISBLANK(f), DIVIDE(SUMX(FILTER(ALLSELECTED(dim_Produtos), [Faturamento] >= f), "
                          "[Faturamento]), tot))", PCT),
        ("'Classe ABC'", 'VAR p = [% Acumulado] RETURN IF(ISBLANK(p), BLANK(), IF(p <= 0.8, "A", IF(p <= 0.95, "B", "C")))', None),
        ("'Peças Classe A'", 'COUNTROWS(FILTER(ALLSELECTED(dim_Produtos), [Classe ABC] = "A")) + 0', "0"),
        # Fidelização: cliente novo = primeira compra entregue dentro do período filtrado
        ("'Clientes Novos'", f"VAR ini = MIN(dim_Calendario[Data]) RETURN COUNTROWS(FILTER("
                             f"CALCULATETABLE(VALUES(fato_Vendas[ID_Cliente]), {ENTREGUE}), "
                             f"CALCULATE(MIN(fato_Vendas[Data]), ALL(dim_Calendario), {ENTREGUE}) >= ini)) + 0", "0"),
        ("'Clientes Recorrentes'", "[Clientes Ativos] - [Clientes Novos]", "0"),
        ("'% Recorrentes'", "DIVIDE([Clientes Recorrentes], [Clientes Ativos])", PCT),
        # % das clientes do período que fizeram 2 ou mais pedidos entregues nele (no período todo, toda cliente é "nova")
        ("'% Recompra'", f"DIVIDE(COUNTROWS(FILTER(CALCULATETABLE(VALUES(fato_Vendas[ID_Cliente]), {ENTREGUE}), "
                         f"CALCULATE([Pedidos Entregues]) >= 2)), [Clientes Ativos])", PCT),
        # Reativação: dias desde a última compra entregue até a data mais recente com pedido
        ("'Última Compra'", f"CALCULATE(MAX(fato_Vendas[Data]), ALL(dim_Calendario), {ENTREGUE})", "dd/mm/yyyy"),
        ("'Dias sem Comprar'", "VAR u = [Última Compra] RETURN IF(NOT ISBLANK(u), "
                               "DATEDIFF(u, CALCULATE(MAX(fato_Vendas[Data]), ALL(fato_Vendas)), DAY))", "0"),
        ("'Clientes a Reativar'", "COUNTROWS(FILTER(VALUES(dim_Clientes[ID_Cliente]), [Dias sem Comprar] >= 90)) + 0", "0"),
        ("'Última Compra (reativar)'", "IF([Dias sem Comprar] >= 90, [Última Compra])", "dd/mm/yyyy"),
        ("'Dias sem Comprar (reativar)'", "IF([Dias sem Comprar] >= 90, [Dias sem Comprar])", "0"),
        ("'Gasto Total (reativar)'", "IF([Dias sem Comprar] >= 90, CALCULATE([Faturamento], ALL(dim_Calendario)))", REAIS),
    ],
    "fato_Metas": [
        ("Meta", "SUM(fato_Metas[Meta_Faturamento])", REAIS),
    ],
    "fato_Estoque": [
        ("'Valor em Estoque'", f"CALCULATE(SUM(fato_Estoque[Valor_Estoque_Final]), {ULTIMO_MES})", REAIS),
        ("'Entradas (un.)'", "SUM(fato_Estoque[Entradas])", "#,0"),
        ("'Saídas (un.)'", "SUM(fato_Estoque[Saidas])", "#,0"),
        ("'SKUs em Atenção'", f'CALCULATE(COUNTROWS(fato_Estoque), fato_Estoque[Status_Estoque] <> "OK", {ULTIMO_MES}) + 0', "0"),
        ("'Estoque Mínimo'", f"CALCULATE(SUM(fato_Estoque[Estoque_Minimo]), {ULTIMO_MES})", "0"),
        ("'Situação'", 'VAR e = [Estoque Final] VAR m = [Estoque Mínimo] RETURN IF(ISBLANK(e), BLANK(), '
                     'IF(e < m, "Abaixo do mínimo", IF(e <= 2 * m, "Atenção", "OK")))', None),
    ],
    # subtítulo das páginas: acompanha o que há no banco e o filtro de mês
    "dim_Calendario": [
        ("'Período'", 'LOWER(FORMAT(MIN(dim_Calendario[Data]), "mmm/yyyy") & " a " & '
                      'FORMAT(MAX(dim_Calendario[Data]), "mmm/yyyy"))', None),
    ],
}
for tabela, medidas in novas.items():
    arq = MOD / f"{tabela}.tmdl"
    txt = arq.read_text(encoding="utf-8")
    # idempotente: remove versões anteriores (o Power BI regrava o nome sem aspas quando dá)
    nomes = "|".join("'?" + re.escape(n.strip("'")) + "'?" for n, _, _ in medidas)
    txt = re.sub(rf"(?m)^\tmeasure ({nomes}) =.*?(?=^\t(?:measure|column|partition)|\Z)", "", txt, flags=re.S)
    bloco = "".join(f"\tmeasure {n} = {e}\n" + (f"\t\tformatString: {f}\n" if f else "") + "\n" for n, e, f in medidas)
    txt, n = re.subn(r"(?m)^(table \S+\n\tlineageTag: [^\n]+\n(?:\t[^\n]+\n)*\n)", lambda m: m.group(1) + bloco, txt, count=1)
    assert n == 1, tabela  # cabeçalho da tabela pode ter dataCategory etc. depois do lineageTag
    # formatos fixos: R$ com 2 casas e % com 1 casa (o padrão do Power BI deixava casas variáveis)
    txt = txt.replace(r'"R$"\ #,0.###############;-"R$"\ #,0.###############;"R$"\ #,0.###############', REAIS)
    txt = txt.replace("formatString: 0.00%;-0.00%;0.00%", f"formatString: {PCT}")
    arq.write_text(txt, encoding="utf-8")

# ---------------- helpers PBIR ----------------
def lit(v):
    if isinstance(v, bool): return {"expr": {"Literal": {"Value": "true" if v else "false"}}}
    if isinstance(v, (int, float)): return {"expr": {"Literal": {"Value": f"{v}D"}}}
    return {"expr": {"Literal": {"Value": "'" + str(v).replace("'", "''") + "'"}}}
def cor(c): return {"solid": {"color": lit(c)}}
def props(**kw): return [{"properties": {k: v for k, v in kw.items()}}]

def M(ent, prop): return ("Measure", ent, prop)
def C(ent, prop): return ("Column", ent, prop)
def H(ent, hier, nivel): return ("Hierarchy", ent, hier, nivel)  # nível de hierarquia do modelo (drill-down)
def field(f):
    if f[0] == "Hierarchy":
        return {"HierarchyLevel": {"Expression": {"Hierarchy": {"Expression": {"SourceRef": {"Entity": f[1]}},
                                                                "Hierarchy": f[2]}}, "Level": f[3]}}
    return {f[0]: {"Expression": {"SourceRef": {"Entity": f[1]}}, "Property": f[2]}}
def proj(f, nome=None, ativo=False):
    p = {"field": field(f), "queryRef": ".".join(f[1:]), "nativeQueryRef": " ".join(f[2:])}
    if nome: p["displayName"] = nome
    if ativo: p["active"] = True
    return p

SCHEMA_VIS = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.4.0/schema.json"
def visual(nome, tipo, x, y, w, h, papeis, titulo=None, ordem=None, objetos=None, padding=None):
    q = {"queryState": {papel: {"projections": ps} for papel, ps in papeis.items()}}
    if ordem:
        q["sortDefinition"] = {"sort": [{"field": field(ordem[0]), "direction": ordem[1]}], "isDefaultSort": True}
    vco = {"title": props(show=lit(False))} if titulo is None else {"title": props(show=lit(True), text=lit(titulo))}
    if padding is not None:  # (topo, baixo, esq, dir) — cartões e filtros precisam de menos respiro que o tema
        vco["padding"] = props(top=lit(padding[0]), bottom=lit(padding[1]), left=lit(padding[2]), right=lit(padding[3]))
    v = {"visualType": tipo, "query": q, "visualContainerObjects": vco, "drillFilterOtherVisuals": True}
    if not papeis:  # botões e navegador não têm campos
        del v["query"]
    if objetos: v["objects"] = objetos
    return {"$schema": SCHEMA_VIS, "name": nome,
            "position": {"x": x, "y": y, "z": 0, "height": h, "width": w, "tabOrder": 0}, "visual": v}

# ---------------- grade da página (modelo "Background Editável", 1280 x 720) ----------------
MX, GAP = 20, 16                      # margem lateral e espaço entre painéis
TOPO_PAINEIS, FIM = 150, 704          # abaixo da linha divisória (y = 134)
L1_Y, L1_H = TOPO_PAINEIS, 262        # primeira linha de painéis
L2_Y = L1_Y + L1_H + GAP              # segunda linha
L2_H = FIM - L2_Y
ALTO_H = FIM - TOPO_PAINEIS           # painel que ocupa as duas linhas
TILE_X0, TILE_Y, TILE_H, TILE_GAP, ICONE = 476, 22, 92, 12, 42

def tiles(n=4):
    w = (1280 - MX - TILE_X0 - TILE_GAP * (n - 1)) // n
    return [(TILE_X0 + i * (w + TILE_GAP), TILE_Y, w, TILE_H) for i in range(n)]

FILTRO_X, FILTRO_W, FILTRO_H = 296, 168, 44
FILTROS_Y = (TILE_Y, TILE_Y + TILE_H - FILTRO_H)  # Mês alinhado ao topo dos cartões, Categoria à base
FILTRO_ROTULO_W, CAIXA_H = 72, 30  # rótulo desenhado no fundo à esquerda; caixa de seleção à direita

def slicer(nome, y, f, rotulo):
    return visual(nome, "slicer", FILTRO_X + FILTRO_ROTULO_W, y + (FILTRO_H - CAIXA_H) // 2 - 4,  # o dropdown desenha a caixa no pé do visual; -4 alinha com o rótulo
                  FILTRO_W - FILTRO_ROTULO_W - 8, CAIXA_H, {"Values": [proj(f, rotulo, ativo=True)]},
                  objetos={"data": props(mode=lit("Dropdown")), "header": props(show=lit(False)),
                           "items": props(textSize=lit(9))}, padding=(0, 0, 0, 0))

def kpis(prefixo, medidas):
    """Cartões dentro dos tiles do cabeçalho; o ícone e o tile são desenhados no fundo."""
    out = []
    for i, ((m, rotulo, _icone), (x, y, w, h)) in enumerate(zip(medidas, tiles(len(medidas)))):
        tx = x + 12 + ICONE + 4
        out.append(visual(f"{prefixo}_kpi{i}", "card", tx, y + 8, x + w - tx - 4, h - 16, {"Values": [proj(m, rotulo)]},
                          objetos={"labels": props(labelDisplayUnits=lit(1), fontSize=lit(14)),
                                   "categoryLabels": props(show=lit(True), fontSize=lit(9))}, padding=(0, 0, 0, 0)))
    return out

def barras(nome, tipo, x, y, w, h, cat, val, titulo, rotulo_cat=None, ordem_por_valor=True, rotulos=True):
    """cat pode ser uma lista de campos: o eixo vira hierarquia e o visual ganha as setas de drill-down."""
    cats = cat if isinstance(cat, list) else [cat]
    obj = {"labels": props(show=lit(rotulos), labelDisplayUnits=lit(1))}
    if rotulos:  # com rótulo em cada barra o eixo de valor só repete informação
        obj["valueAxis"] = props(show=lit(False))
    if tipo == "clusteredBarChart":  # mais espaço para nomes longos ("Cartão de Crédito", nomes das vendedoras)
        obj["categoryAxis"] = props(maxMarginFactor=lit(45))
    ordem = (val, "Descending") if ordem_por_valor else (cats[0], "Ascending")
    return visual(nome, tipo, x, y, w, h,
                  {"Category": [proj(c, rotulo_cat if i == 0 else None, ativo=i == 0) for i, c in enumerate(cats)],
                   "Y": [proj(val)]}, titulo, ordem, obj)

def linhas(nome, x, y, w, h, cat, series, titulo, cores, tracejada=None, nomes=None):
    obj = {"dataPoint": [{"properties": {"fill": cor(c)}, "selector": {"metadata": f"{s[1]}.{s[2]}"}}
                         for s, c in zip(series, cores)],
           "lineStyles": props(strokeWidth=lit(2), showMarker=lit(True)),
           "categoryAxis": props(preferredCategoryWidth=lit(8))}  # cabe o período todo sem barra de rolagem
    if tracejada:
        obj["lineStyles"].append({"properties": {"lineStyle": lit("dashed")},
                                  "selector": {"metadata": f"{tracejada[1]}.{tracejada[2]}"}})
    return visual(nome, "lineChart", x, y, w, h,
                  {"Category": [proj(cat, "Mês", ativo=True)],
                   "Y": [proj(s, n) for s, n in zip(series, nomes or [None] * len(series))]},
                  titulo, (cat, "Ascending"), obj)

def tabela(nome, x, y, w, h, colunas, titulo, ordem, total=True, larguras=None):
    """larguras: px de cada coluna, para a tabela ocupar o painel todo (sem isso o Power BI ajusta ao conteúdo)."""
    obj = {} if total else {"total": props(totals=lit(False))}
    if larguras:
        obj["columnWidth"] = [{"properties": {"value": lit(l)}, "selector": {"metadata": f"{f[1]}.{f[2]}"}}
                              for (f, _), l in zip(colunas, larguras)]
    return visual(nome, "tableEx", x, y, w, h, {"Values": [proj(f, r) for f, r in colunas]}, titulo, ordem, obj or None)

# ---------------- campos ----------------
FAT, LUCRO, MARGEM = M("fato_Vendas", "Faturamento"), M("fato_Vendas", "Lucro Total"), M("fato_Vendas", "Margem %")
PED, PED_E, TICKET = M("fato_Vendas", "Pedidos"), M("fato_Vendas", "Pedidos Entregues"), M("fato_Vendas", "Ticket Médio")
ATING, META = M("fato_Vendas", "Atingimento da Meta %"), M("fato_Metas", "Meta")
ITENS, DESC = M("fato_Vendas", "Itens Vendidos"), M("fato_Vendas", "Desconto Concedido")
DEV = M("fato_Vendas", "Taxa de Devolução")
CLI, PED_CLI = M("fato_Vendas", "Clientes Ativos"), M("fato_Vendas", "Pedidos por Cliente")
EST, VAL_EST, SKU_AT = M("fato_Estoque", "Estoque Final"), M("fato_Estoque", "Valor em Estoque"), M("fato_Estoque", "SKUs em Atenção")
ENT, SAI, EST_MIN, SIT = (M("fato_Estoque", "Entradas (un.)"), M("fato_Estoque", "Saídas (un.)"),
                          M("fato_Estoque", "Estoque Mínimo"), M("fato_Estoque", "Situação"))
MES, CAT = C("dim_Calendario", "Mes_Ano"), C("dim_Categorias", "Categoria")

# ícones da fonte Segoe MDL2 Assets
I_RECEITA, I_GRAFICO, I_CAIXA, I_META, I_SACOLA = "\uE825", "\uE9D2", "\uE7B8", "\uEC4A", "\uE719"
I_CARTAO, I_ETIQUETA, I_ALERTA, I_ATIV, I_PESSOAS = "\uE8C7", "\uE8EC", "\uE7BA", "\uE9D9", "\uE716"
I_PESSOA, I_BANDEIRA, I_TROCA = "\uE77B", "\uE7C1", "\uE8AB"

SUB = None  # período vem do banco: cartão com a medida Período no lugar do texto fixo

def periodo(p):
    # o cartão clássico centraliza o valor: caixa um pouco maior que "out/2025 a out/2026" (com 132 o texto era
    # cortado; com 200 ficava solto à direita) para ele começar alinhado ao título (x = 86)
    # y 48: o texto começa ~5 px abaixo das letras que descem do título ("ç", "g" terminam em y 48)
    return visual(f"{p}_periodo", "card", 76, 48, 150, 24, {"Values": [proj(M("dim_Calendario", "Período"))]},
                  objetos={"labels": props(fontSize=lit(11), fontFamily=lit(FONTE), color=cor(TXT2)),
                           "categoryLabels": props(show=lit(False))}, padding=(0, 0, 0, 0))
def filtros(p):
    return [slicer(f"{p}_fmes", FILTROS_Y[0], MES, "Mês"), slicer(f"{p}_fcat", FILTROS_Y[1], CAT, "Categoria")]

# Botões de navegação sob o título, em grade 3 x 2: o ícone e o nome são desenhados no fundo (página atual em
# vermelho da marca); por cima de cada um, um botão transparente leva à página e clareia ao passar o mouse.
NAV_X, NAV_Y, NAV_W, NAV_H, NAV_GAP = MX, 80, FILTRO_X - MX - 8, 48, 4
NAV_CW, NAV_CH = (NAV_W - 2 * NAV_GAP) // 3, (NAV_H - NAV_GAP) // 2
# página -> (rótulo curto, ícone da Segoe MDL2 Assets)
NAV_ROTULOS = {"visao_geral": ("Visão geral", ""), "vendas": ("Vendas", ""), "estoque": ("Estoque", ""),
               "clientes": ("Clientes", ""), "metas_equipe": ("Metas", ""),
               "produtos_clientes": ("Produtos", "")}
def nav_celulas():
    return [(pid, *NAV_ROTULOS[pid], NAV_X + (i % 3) * (NAV_CW + NAV_GAP), NAV_Y + (i // 3) * (NAV_CH + NAV_GAP))
            for i, pid in enumerate(p[0] for p in paginas)]

def navegacao(p):
    botoes = []
    for pid, rotulo, _, x, y in nav_celulas():
        v = visual(f"{p}_nav_{pid}", "actionButton", x, y, NAV_CW, NAV_CH, {}, objetos={
            "icon": [{"properties": {"shapeType": lit("blank")}, "selector": {"id": "default"}}],
            "fill": [{"properties": {"show": lit(False)}, "selector": {"id": "default"}},
                     {"properties": {"show": lit(True), "fillColor": cor("#FFFFFF"), "transparency": lit(88)},
                      "selector": {"id": "hover"}}],
            "outline": [{"properties": {"show": lit(False)}}],
        }, padding=(0, 0, 0, 0))
        v["visual"]["visualContainerObjects"]["visualLink"] = props(
            show=lit(True), type=lit("PageNavigation"), navigationSection=lit(pid), tooltip=lit(rotulo))
        botoes.append(v)
    return botoes

# colunas de painéis usadas nas páginas
ESQ_L, DIR_X = 744, MX + 744 + GAP           # 2/3 + 1/3
DIR_L = 1280 - MX - DIR_X
TERCO = (1280 - 2 * MX - 2 * GAP) // 3

paginas = [
    ("visao_geral", "Visão Geral", "Visão geral da loja", SUB,
     [(FAT, "Faturamento", I_RECEITA), (LUCRO, "Lucro", I_GRAFICO), (PED_E, "Pedidos entregues", I_CAIXA),
      (ATING, "Atingimento da meta", I_META)], [
        linhas("p1_fat_meta", MX, L1_Y, ESQ_L, L1_H, MES, [FAT, META], "Faturamento x meta por mês",
               [SERIES[0], TXT3], tracejada=META),
        barras("p1_categoria", "clusteredBarChart", DIR_X, L1_Y, DIR_L, L1_H, CAT, FAT, "Faturamento por categoria"),
        barras("p1_canal", "clusteredBarChart", MX, L2_Y, TERCO, L2_H, C("fato_Vendas", "Canal_Venda"), FAT,
               "Faturamento por canal"),
        barras("p1_pagto", "clusteredBarChart", MX + TERCO + GAP, L2_Y, TERCO, L2_H, C("fato_Vendas", "Forma_Pagamento"),
               FAT, "Faturamento por forma de pagamento"),
        barras("p1_status", "clusteredColumnChart", MX + 2 * (TERCO + GAP), L2_Y, TERCO, L2_H,
               C("fato_Vendas", "Status_Pedido"), PED, "Pedidos por status"),
    ]),
    ("vendas", "Vendas", "Vendas", SUB,
     [(FAT, "Faturamento", I_RECEITA), (ITENS, "Itens vendidos", I_SACOLA), (TICKET, "Ticket médio", I_CARTAO),
      (DESC, "Descontos concedidos", I_ETIQUETA)], [
        # hierarquia Calendário: abre por ano e desce para trimestre e mês (drill-down)
        barras("p2_mensal", "clusteredColumnChart", MX, L1_Y, ESQ_L, L1_H,
               [H("dim_Calendario", "Calendário", n) for n in ("Ano", "Trimestre", "Mês")], FAT,
               "Faturamento por ano, trimestre e mês (drill-down)", ordem_por_valor=False),
        barras("p2_semana", "clusteredBarChart", DIR_X, L1_Y, DIR_L, L1_H, C("dim_Calendario", "Dia_Semana"), FAT,
               "Faturamento por dia da semana", "Dia", ordem_por_valor=False),
        tabela("p2_produtos", MX, L2_Y, ESQ_L, L2_H, [
            (C("dim_Produtos", "Produto"), "Produto"), (C("dim_Produtos", "Cor"), "Cor"),
            (ITENS, "Itens"), (FAT, "Faturamento"), (MARGEM, "Margem")], "Produtos mais vendidos", (FAT, "Descending"),
            larguras=[250, 140, 80, 130, 90]),  # 690 px: painel de 744 menos respiro e barra de rolagem
        barras("p2_categoria_itens", "clusteredBarChart", DIR_X, L2_Y, DIR_L, L2_H, [CAT, C("dim_Produtos", "Produto")],
               ITENS, "Itens vendidos por categoria e produto"),
    ]),
    ("estoque", "Estoque", "Estoque", "Posição do último mês filtrado",
     [(EST, "Peças em estoque", I_CAIXA), (VAL_EST, "Valor em estoque", I_RECEITA),
      (SKU_AT, "SKUs em atenção", I_ALERTA), (SAI, "Saídas (un.)", I_ATIV)], [
        linhas("p3_fluxo", MX, L1_Y, 560, L1_H, MES, [SAI, ENT], "Saídas x reposições por mês",
               [SERIES[0], TXT2], nomes=["Saídas", "Reposições"]),
        barras("p3_por_cat", "clusteredBarChart", MX, L2_Y, 560, L2_H, CAT, EST, "Peças em estoque por categoria"),
        tabela("p3_situacao", MX + 560 + GAP, TOPO_PAINEIS, 1280 - 2 * MX - 560 - GAP, ALTO_H, [
            (C("dim_Produtos", "SKU"), "SKU"), (C("dim_Produtos", "Produto"), "Produto"),
            (EST, "Estoque"), (EST_MIN, "Mínimo"), (SIT, "Situação"), (VAL_EST, "Valor")],
            "Situação do estoque por SKU", (EST, "Ascending"), total=False),
    ]),
    ("clientes", "Clientes", "Clientes", SUB,
     [(CLI, "Clientes ativos", I_PESSOAS), (PED_E, "Pedidos entregues", I_CAIXA),
      (PED_CLI, "Pedidos por cliente", I_PESSOA), (TICKET, "Ticket médio", I_CARTAO)], [
        # mapa padrão (o Azure Maps depende de liberação no locatário); a coluna Local ("Cidade, UF, Brasil",
        # categoria Local) evita que o mapa ache a cidade em outro país
        visual("p4_mapa", "map", MX, TOPO_PAINEIS, 600, ALTO_H,
               {"Category": [proj(C("dim_Clientes", "Local"), "Cidade", ativo=True)], "Size": [proj(FAT)],
                "Tooltips": [proj(CLI, "Clientes ativos"), proj(PED_E, "Pedidos entregues")]},
               "Faturamento por cidade",
               objetos={"mapStyles": props(mapTheme=lit("canvasDark")),
                        "dataPoint": props(defaultColor=cor(SERIES[0]))}),
        barras("p4_geo", "clusteredBarChart", MX + 600 + GAP, L1_Y, 304, 230,
               [H("dim_Clientes", "Geografia", n) for n in ("Região", "UF", "Cidade")], FAT,
               "Por região, UF e cidade (drill-down)"),
        barras("p4_faixa", "clusteredColumnChart", MX + 600 + GAP + 304 + GAP, L1_Y, 1280 - MX - (MX + 600 + GAP + 304 + GAP),
               230, C("dim_Clientes", "Faixa_Etaria"), FAT, "Por faixa etária", "Faixa etária",
               ordem_por_valor=False),
        tabela("p4_top", MX + 600 + GAP, L1_Y + 230 + GAP, 1280 - 2 * MX - 600 - GAP, FIM - (L1_Y + 230 + GAP), [
            (C("dim_Clientes", "Nome"), "Cliente"), (C("dim_Clientes", "Cidade"), "Cidade"),
            (PED_E, "Pedidos"), (FAT, "Faturamento"), (TICKET, "Ticket médio")],
            "Melhores clientes", (FAT, "Descending")),
    ]),
    ("metas_equipe", "Metas e Equipe", "Metas e equipe", SUB,
     [(META, "Meta", I_BANDEIRA), (FAT, "Faturamento", I_RECEITA), (ATING, "Atingimento da meta", I_META),
      (DEV, "Taxa de devolução", I_TROCA)], [
        visual("p5_matriz", "pivotTable", MX, L1_Y, 760, 276,
               {"Rows": [proj(CAT, "Categoria")], "Columns": [proj(C("dim_Calendario", "Ano_Trimestre"), "Trimestre")],
                "Values": [proj(ATING, "Atingimento")]},
               "Atingimento da meta por categoria e trimestre"),  # por mês eram 27 colunas e a matriz rolava
        # ao lado da matriz (que ocupa ~750 px com 10 trimestres): o valor em R$ por trás do atingimento
        visual("p5_trimestre", "clusteredColumnChart", MX + 760 + GAP, L1_Y, 1280 - 2 * MX - 760 - GAP, 276,
               {"Category": [proj(C("dim_Calendario", "Ano_Trimestre"), "Trimestre", ativo=True)],
                "Y": [proj(FAT), proj(META)]},
               "Faturamento x meta por trimestre", (C("dim_Calendario", "Ano_Trimestre"), "Ascending"),
               {"dataPoint": [{"properties": {"fill": cor(c)}, "selector": {"metadata": m}}
                              for m, c in (("fato_Vendas.Faturamento", SERIES[0]), ("fato_Metas.Meta", TXT3))],
                "legend": props(show=lit(True)), "labels": props(show=lit(False))}),
        tabela("p5_vendedoras", MX, L1_Y + 276 + GAP, 600, FIM - (L1_Y + 276 + GAP), [
            (C("dim_Vendedores", "Nome"), "Vendedora"), (C("dim_Vendedores", "Cargo"), "Cargo"),
            (PED_E, "Pedidos"), (FAT, "Faturamento"), (TICKET, "Ticket médio"), (DEV, "Devoluções")],
            "Desempenho da equipe", (FAT, "Descending")),
        barras("p5_ating_cat", "clusteredBarChart", MX + 600 + GAP, L1_Y + 276 + GAP, 304, FIM - (L1_Y + 276 + GAP),
               CAT, ATING, "Atingimento por categoria"),
        barras("p5_vend_bar", "clusteredBarChart", MX + 600 + GAP + 304 + GAP, L1_Y + 276 + GAP,
               1280 - MX - (MX + 600 + GAP + 304 + GAP), FIM - (L1_Y + 276 + GAP),
               C("dim_Vendedores", "Nome"), FAT, "Faturamento por vendedora", "Vendedora"),
    ]),
    # Rentabilidade das peças (curva ABC) + fidelização das clientes
    ("produtos_clientes", "Produtos e Clientes", "Produtos e clientes", SUB,
     [(MARGEM, "Margem", I_ETIQUETA), (M("fato_Vendas", "Peças Classe A"), "Peças classe A", I_GRAFICO),
      (M("fato_Vendas", "% Recompra"), "Compraram 2+ vezes", I_PESSOAS),
      (M("fato_Vendas", "Clientes a Reativar"), "Clientes a reativar", I_ALERTA)], [
        visual("p6_abc", "lineClusteredColumnComboChart", MX, L1_Y, ESQ_L, L1_H,
               {"Category": [proj(C("dim_Produtos", "SKU"), "Peça", ativo=True)], "Y": [proj(FAT)],
                "Y2": [proj(M("fato_Vendas", "% Acumulado"), "% acumulado")]},
               "Curva ABC: faturamento por peça e % acumulado", (FAT, "Descending"),
               {"dataPoint": [{"properties": {"fill": cor(c)}, "selector": {"metadata": f"fato_Vendas.{m}"}}
                              for m, c in (("Faturamento", SERIES[0]), ("% Acumulado", TXT2))],
                "legend": props(show=lit(True))}),
        tabela("p6_rent", DIR_X, L1_Y, DIR_L, L1_H, [
            (C("dim_Produtos", "SKU"), "Peça"), (ITENS, "Itens"), (LUCRO, "Lucro"), (MARGEM, "Margem"),
            (M("fato_Vendas", "Classe ABC"), "Classe")], "Rentabilidade por peça", (LUCRO, "Descending")),
        visual("p6_novos", "columnChart", MX, L2_Y, ESQ_L, L2_H,
               {"Category": [proj(MES, "Mês", ativo=True)],
                "Y": [proj(M("fato_Vendas", "Clientes Novos"), "Novas"),
                      proj(M("fato_Vendas", "Clientes Recorrentes"), "Recorrentes")]},
               "Clientes novas x recorrentes por mês", (MES, "Ascending"),
               {"dataPoint": [{"properties": {"fill": cor(c)}, "selector": {"metadata": f"fato_Vendas.{m}"}}
                              # paleta da loja: vermelho da marca (como as outras barras) e cinza (como a Meta)
                              for m, c in (("Clientes Novos", TXT2), ("Clientes Recorrentes", SERIES[0]))],
                "legend": props(show=lit(True))}),
        tabela("p6_reativar", DIR_X, L2_Y, DIR_L, L2_H, [
            (C("dim_Clientes", "Nome"), "Cliente"), (M("fato_Vendas", "Última Compra (reativar)"), "Última compra"),
            (M("fato_Vendas", "Dias sem Comprar (reativar)"), "Dias"),
            (M("fato_Vendas", "Gasto Total (reativar)"), "Já gastou")],
            "Clientes para reativar (90+ dias sem comprar)", (M("fato_Vendas", "Gasto Total (reativar)"), "Descending"),
            total=False),
    ]),
]

# ---------------- template visual (PowerPoint) -> imagens de fundo ----------------
# O template fica em docs/powerbi/template/: um slide de guia (cores, fontes, estrutura) e, para cada página, um slide
# de layout (o que vai em cada área) e um slide de fundo. O PowerPoint exporta o slide de fundo em PNG e ele vira a
# imagem de fundo da página no Power BI; os visuais, transparentes, ficam por cima dos painéis desenhados nele.
from pptx import Presentation
from pptx.util import Emu, Pt
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.oxml.ns import qn

TEMPLATE = raiz.parent / "template"
VERMELHO, FONTE_ICONES = "#B3121E", "Segoe MDL2 Assets"
def emu(px): return Emu(round(px * 9525))  # slide de 1280 x 720 px a 96 dpi (1 px = 9525 EMU)
def rgbc(h): return RGBColor.from_string(h[1:])

def forma(sl, x, y, w, h, cor_hex, raio=0, nome=None, borda=None):
    s = sl.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if raio else MSO_SHAPE.RECTANGLE,
                            emu(x), emu(y), emu(w), emu(h))
    if raio:
        s.adjustments[0] = raio / min(w, h)
    s.fill.solid()
    s.fill.fore_color.rgb = rgbc(cor_hex)
    if borda:
        s.line.color.rgb, s.line.width = rgbc(borda), emu(1)
    else:
        s.line.fill.background()
    s.shadow.inherit = False  # o estilo padrão da forma traria a sombra do tema
    if nome:
        s.name = nome
    return s

def texto(sl, x, y, w, h, partes, cor_hex, alinhar=PP_ALIGN.LEFT, meio=False, nome=None):
    """Uma linha de texto; partes = [(texto, fonte, tamanho em px, negrito)] (1 px do Power BI = 0,75 pt)."""
    tb = sl.shapes.add_textbox(emu(x), emu(y), emu(w), emu(h))
    tf = tb.text_frame
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.word_wrap = False
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE if meio else MSO_ANCHOR.TOP
    p = tf.paragraphs[0]
    p.alignment = alinhar
    for t, f, tam, negrito in partes:
        r = p.add_run()
        r.text = t
        r.font.size, r.font.bold, r.font.name = Pt(tam * 0.75), negrito, f
        r.font.color.rgb = rgbc(cor_hex)
        if f == FONTE_ICONES:  # os ícones ficam na área de uso privado do Unicode, desenhada com a fonte "sym"
            latin = r._r.rPr.find(qn("a:latin"))
            for tag in ("a:sym", "a:cs", "a:ea"):
                latin.addnext(latin.makeelement(qn(tag), {"typeface": f}))
    if nome:
        tb.name = nome
    return tb

def sombra(s):
    """Sombra suave para baixo e à direita (3 px, 4 px), 8 px de desfoque."""
    eff = s._element.spPr.find(qn("a:effectLst"))
    sh = eff.makeelement(qn("a:outerShdw"), {"blurRad": str(emu(8)), "dist": str(emu(5)), "dir": "3180000",
                                             "algn": "tl", "rotWithShape": "0"})
    clr = sh.makeelement(qn("a:srgbClr"), {"val": "000000"})
    clr.append(clr.makeelement(qn("a:alpha"), {"val": "67000"}))
    sh.append(clr)
    eff.append(sh)

def quadrado_icone(sl, x, y, glifo):
    """Quadrado com degradê diagonal do vermelho da marca, sombra suave e ícone branco."""
    s = forma(sl, x, y, ICONE, ICONE, VERMELHO, 9, "Ícone")
    s.fill.gradient()
    s.fill.gradient_angle = 315  # escuro no canto superior esquerdo, claro no inferior direito
    a, b = s.fill.gradient_stops
    a.position, b.position = 0, 1
    a.color.rgb, b.color.rgb = rgbc("#8E0E18"), rgbc("#E5484D")
    sombra(s)
    texto(sl, x, y, ICONE, ICONE, [(glifo, FONTE_ICONES, 20, False)], TXT, PP_ALIGN.CENTER, meio=True)

def novo_slide(prs):
    sl = prs.slides.add_slide(prs.slide_layouts[6])  # layout em branco
    sl.background.fill.solid()
    sl.background.fill.fore_color.rgb = rgbc(BG)
    return sl

def marca(sl, x, y):
    forma(sl, x, y, 52, 52, VERMELHO, 12, "Marca")
    texto(sl, x, y, 52, 52, [("RV", FONTE, 20, True)], TXT, PP_ALIGN.CENTER, meio=True)

NOMES_VISUAL = {"lineChart": "Gráfico de linhas", "clusteredBarChart": "Gráfico de barras",
                "clusteredColumnChart": "Gráfico de colunas", "columnChart": "Colunas empilhadas",
                "tableEx": "Tabela", "pivotTable": "Matriz", "lineClusteredColumnComboChart": "Colunas e linha",
                "map": "Mapa"}

def titulo_visual(v):
    t = v["visualContainerObjects"]["title"][0]["properties"].get("text")
    return t["expr"]["Literal"]["Value"][1:-1].replace("''", "'") if t else ""

def slide_pagina(prs, pid, titulo, sub, indicadores, graficos, layout):
    """Fundo da página; com layout=True também escreve o que vai em cada área (slide de layout do template)."""
    sl = novo_slide(prs)
    marca(sl, MX, 20)
    texto(sl, 86, 20, 205, 30, [(titulo, FONTE, 21, True)], TXT, nome="Título da página")
    if sub:
        texto(sl, 86, 53, 205, 16, [(sub, FONTE, 11, False)], TXT2, nome="Subtítulo")
    elif layout:  # sem texto fixo, o cartão Período (medida DAX) ocupa este lugar
        texto(sl, 86, 52, 205, 16, [("[período: mmm/aaaa a mmm/aaaa]", FONTE, 10, False)], TXT3)
    # filtros: o rótulo fica no fundo e a caixa da segmentação, à direita
    for y, rotulo in zip(FILTROS_Y, ("Mês", "Categoria")):
        forma(sl, FILTRO_X, y, FILTRO_W, FILTRO_H, PAINEL, 10, f"Filtro {rotulo}")
        texto(sl, FILTRO_X + 12, y, FILTRO_ROTULO_W, FILTRO_H, [(rotulo, FONTE, 11, False)], TXT2, meio=True)
        if layout:
            texto(sl, FILTRO_X + FILTRO_ROTULO_W, y, FILTRO_W - FILTRO_ROTULO_W - 8, FILTRO_H,
                  [("segmentação ▾", FONTE, 9, False)], TXT3, meio=True)
    # indicadores: tile + quadrado do ícone; o cartão com o número fica por cima, à direita do ícone
    for (_, rotulo, glifo), (x, y, w, h) in zip(indicadores, tiles(len(indicadores))):
        forma(sl, x, y, w, h, PAINEL, 12, f"Indicador {rotulo}")
        quadrado_icone(sl, x + 12, y + (h - ICONE) // 2, glifo)
        if layout:
            tx = x + 12 + ICONE + 10
            texto(sl, tx, y + 24, x + w - tx - 4, 24, [("[valor]", FONTE, 16, True)], TXT3)
            texto(sl, tx, y + 50, x + w - tx - 4, 16, [(f"KPI: {rotulo}", FONTE, 9, False)], TXT2)
    # navegação: ícone + nome centralizados; a página atual em vermelho da marca
    for p_id, rotulo, glifo, x, y in nav_celulas():
        ativo = p_id == pid
        forma(sl, x, y, NAV_CW, NAV_CH, VERMELHO if ativo else PAINEL, 7, f"Botão {rotulo}")
        texto(sl, x, y, NAV_CW, NAV_CH, [(glifo, FONTE_ICONES, 11, False), ("  ", FONTE, 10, False),
                                         (rotulo, FONTE, 10, ativo)], TXT if ativo else TXT2, PP_ALIGN.CENTER, meio=True)
    ln = sl.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, emu(MX), emu(134), emu(1280 - MX), emu(134))
    ln.line.color.rgb, ln.line.width, ln.name = rgbc("#3A3A3F"), emu(1), "Divisória"
    # painéis dos visuais
    for g in graficos:
        x, y, w, h = (g["position"][k] for k in ("x", "y", "width", "height"))
        forma(sl, x, y, w, h, PAINEL, 14, f"Painel {g['name']}")
        if layout:
            v = g["visual"]
            drill = len(v["query"]["queryState"].get("Category", {}).get("projections", [])) > 1
            tipo = NOMES_VISUAL.get(v["visualType"], v["visualType"]) + ("  ·  drill-down" if drill else "")
            texto(sl, x, y + h / 2 - 24, w, 22, [(tipo, FONTE, 11, False)], TXT3, PP_ALIGN.CENTER, meio=True)
            texto(sl, x, y + h / 2, w, 22, [(titulo_visual(v), FONTE, 13, True)], TXT2, PP_ALIGN.CENTER, meio=True)
    return sl

def slide_guia(prs):
    """Guia do template: estrutura da página, cores e tipografia."""
    sl = novo_slide(prs)
    marca(sl, 40, 32)
    texto(sl, 108, 30, 700, 34, [("Template visual do dashboard", FONTE, 26, True)], TXT)
    texto(sl, 108, 66, 1100, 20, [("RV Label  ·  páginas de 1280 × 720 px  ·  tema escuro  ·  cada slide de fundo "
                                   "é exportado em PNG e importado como imagem de fundo da página no Power BI",
                                   FONTE, 12, False)], TXT2)
    # estrutura da página, em miniatura (50%)
    ox, oy, k = 40, 136, 0.5
    texto(sl, ox, oy - 28, 400, 20, [("Estrutura de cada página", FONTE, 14, True)], TXT)
    forma(sl, ox, oy, 1280 * k, 720 * k, BG, 6, "Página", borda="#3A3A3F")
    areas = [("1", "Marca, título da página e período filtrado", (MX, 20, 256, 54)),
             ("2", "Navegação entre as 6 páginas (botões)", (NAV_X, NAV_Y, NAV_W, NAV_H)),
             ("3", "Filtros e segmentações (mês e categoria)", (FILTRO_X, TILE_Y, FILTRO_W, TILE_H)),
             ("4", "Indicadores (KPIs em DAX) com ícone", (TILE_X0, TILE_Y, 1280 - MX - TILE_X0, TILE_H)),
             ("5", "Gráficos, tabelas, matriz e mapa em painéis", (MX, TOPO_PAINEIS, 1280 - 2 * MX, FIM - TOPO_PAINEIS))]
    for n, _, (x, y, w, h) in areas:
        forma(sl, ox + x * k, oy + y * k, w * k, h * k, PAINEL, 5, f"Área {n}")
        texto(sl, ox + x * k, oy + y * k, w * k, h * k, [(n, FONTE, 22 if n == "5" else 14, True)],
              SERIES[0], PP_ALIGN.CENTER, meio=True)
    ln = sl.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, emu(ox + MX * k), emu(oy + 134 * k),
                                 emu(ox + (1280 - MX) * k), emu(oy + 134 * k))
    ln.line.color.rgb, ln.line.width = rgbc("#3A3A3F"), emu(1)
    for i, (n, desc, _) in enumerate(areas):
        y = oy + 720 * k + 18 + i * 24
        texto(sl, ox, y, 24, 20, [(n, FONTE, 13, True)], SERIES[0])
        texto(sl, ox + 24, y, 600, 20, [(desc, FONTE, 13, False)], TXT2)
    texto(sl, ox, 654, 640, 18, [(f"Grade: margem {MX} px  ·  espaço entre painéis {GAP} px  ·  cantos 14 px (painéis), "
                                 "12 px (indicadores), 10 px (filtros), 7 px (botões)", FONTE, 11, False)], TXT3)
    texto(sl, ox, 676, 640, 18, [("Visuais sem fundo nem borda: o painel arredondado vem da imagem de fundo.",
                                  FONTE, 11, False)], TXT3)
    # cores
    cx = 730
    texto(sl, cx, oy - 28, 400, 20, [("Cores", FONTE, 14, True)], TXT)
    cores = [("Fundo", BG), ("Painel", PAINEL), ("Cabeçalho de tabela", PAINEL_CAB), ("Borda e grade", BORDA),
             ("Marca", VERMELHO), ("Texto", TXT), ("Texto secundário", TXT2), ("Texto auxiliar", TXT3)]
    for i, (nome, c) in enumerate(cores):
        x, y = cx + (i // 4) * 260, oy + (i % 4) * 36
        forma(sl, x, y, 28, 28, c, 6, f"Cor {nome}", borda="#3A3A3F")
        texto(sl, x + 40, y, 210, 28, [(nome, FONTE, 12, False), (f"   {c}", FONTE, 11, False)], TXT2, meio=True)
    texto(sl, cx, oy + 158, 500, 20, [("Séries dos gráficos e status (bom, atenção, ruim)", FONTE, 14, True)], TXT)
    for i, c in enumerate(SERIES + [OK, ATENCAO, RUIM]):
        x = cx + i * 56 + (16 if i >= len(SERIES) else 0)
        forma(sl, x, oy + 188, 40, 28, c, 6, f"Série {c}")
        texto(sl, x - 8, oy + 220, 56, 14, [(c, FONTE, 9, False)], TXT3, PP_ALIGN.CENTER)
    # tipografia
    texto(sl, cx, oy + 254, 500, 20, [("Tipografia", FONTE, 14, True)], TXT)
    fontes = [("Título da página", FONTE, 21, True, "Segoe UI Bold 21 px"),
              ("Título dos visuais", FONTE_FORTE, 12, False, "Segoe UI Semibold 12 px"),
              ("Rótulos, eixos e filtros", FONTE, 11, False, "Segoe UI 10–11 px"),
              ("R$ 12.345", "Segoe UI Light", 26, False, "Segoe UI Light 26 px (números)")]
    for i, (amostra, f, tam, negrito, desc) in enumerate(fontes):
        y = oy + 284 + i * 40
        texto(sl, cx, y, 260, 34, [(amostra, f, tam, negrito)], TXT, meio=True)
        texto(sl, cx + 270, y, 240, 34, [(desc, FONTE, 11, False)], TXT3, meio=True)
    y = oy + 284 + 4 * 40
    texto(sl, cx, y, 260, 34, [("    ".join((I_RECEITA, I_GRAFICO, I_CAIXA, I_META, I_PESSOAS, I_ALERTA)),
                                FONTE_ICONES, 18, False)], TXT, meio=True)
    texto(sl, cx + 270, y, 240, 34, [("Segoe MDL2 Assets (ícones)", FONTE, 11, False)], TXT3, meio=True)

def exportar_slides(pptx, destinos):
    """O PowerPoint exporta cada slide em PNG 2560 x 1440 (2x, nítido em telas de alta densidade)."""
    with tempfile.TemporaryDirectory() as tmp:
        ps = ("$ErrorActionPreference = 'Stop'\n"
              "$app = New-Object -ComObject PowerPoint.Application\n"
              f"$p = $app.Presentations.Open('{pptx.resolve()}', -1, 0, 0)\n"  # só leitura, sem janela
              "try { foreach ($i in 1..$p.Slides.Count) { "
              f"$p.Slides.Item($i).Export((Join-Path '{tmp}' \"slide$i.png\"), 'PNG', 2560, 1440) }} }}\n"
              # não fecha o PowerPoint se a pessoa estiver com outra apresentação aberta
              "finally { $p.Close(); if ($app.Presentations.Count -eq 0) { $app.Quit() } }")
        subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps], check=True)
        assert len(list(Path(tmp).glob("slide*.png"))) == len(destinos), "o PowerPoint não exportou todos os slides"
        for i, destino in enumerate(destinos, 1):
            shutil.move(str(Path(tmp) / f"slide{i}.png"), destino)

def gerar_template(reg):
    TEMPLATE.mkdir(exist_ok=True)
    for f in TEMPLATE.glob("*.png"):
        f.unlink()
    prs = Presentation()
    prs.slide_width, prs.slide_height = emu(1280), emu(720)
    slide_guia(prs)
    destinos = [TEMPLATE / "0-guia.png"]
    for i, (pid, _, titulo, sub, indicadores, graficos) in enumerate(paginas, 1):
        slide_pagina(prs, pid, titulo, sub, indicadores, graficos, layout=True)
        slide_pagina(prs, pid, titulo, sub, indicadores, graficos, layout=False)
        destinos += [TEMPLATE / f"{i}-layout-{pid}.png", reg / f"fundo_{pid}.png"]
    arq = TEMPLATE / "Template-Dashboard-RV-Label.pptx"
    prs.save(arq)
    exportar_slides(arq, destinos)

# ---------------- grava páginas ----------------
PAGES = REP / "definition" / "pages"
reg = REP / "StaticResources" / "RegisteredResources"
reg.mkdir(parents=True, exist_ok=True)
for d in PAGES.iterdir():
    if d.is_dir(): shutil.rmtree(d)
for f in reg.glob("fundo_*.png"):
    f.unlink()
gerar_template(reg)
imagens = []
for pid, nome, titulo, sub, indicadores, graficos in paginas:
    img = f"fundo_{pid}.png"
    imagens.append(img)
    visuais = filtros(pid) + kpis(pid, indicadores) + graficos + ([] if sub else [periodo(pid)]) + navegacao(pid)
    pdir = PAGES / pid
    (pdir / "visuals").mkdir(parents=True)
    fundo_img = {"image": {"image": {
        "name": lit(img),
        "url": {"expr": {"ResourcePackageItem": {"PackageName": "RegisteredResources", "PackageType": 1, "ItemName": img}}},
        "scaling": lit("Fit")}}, "transparency": lit(0)}
    (pdir / "page.json").write_text(json.dumps({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
        "name": pid, "displayName": nome, "displayOption": "FitToPage", "height": 720, "width": 1280,
        "objects": {"background": [{"properties": fundo_img}],
                    "outspace": [{"properties": {"color": cor(BG), "transparency": lit(0)}}]}},
        ensure_ascii=False, indent=2), encoding="utf-8")
    for i, v in enumerate(visuais):
        v["position"]["tabOrder"] = i * 1000; v["position"]["z"] = i * 1000
        vd = pdir / "visuals" / v["name"]; vd.mkdir()
        (vd / "visual.json").write_text(json.dumps(v, ensure_ascii=False, indent=2), encoding="utf-8")
(PAGES / "pages.json").write_text(json.dumps({
    "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json",
    "pageOrder": [p[0] for p in paginas], "activePageName": paginas[0][0]}, indent=2), encoding="utf-8")

# ---------------- tema e imagens registrados ----------------
(reg / "RvLabelEscuro.json").write_text(json.dumps(tema, ensure_ascii=False, indent=2), encoding="utf-8")
rj = REP / "definition" / "report.json"
rep = json.loads(rj.read_text(encoding="utf-8"))
base = rep["themeCollection"]["baseTheme"]
rep["themeCollection"]["customTheme"] = {"name": "RvLabelEscuro.json",
                                         "reportVersionAtImport": base["reportVersionAtImport"],
                                         "type": "RegisteredResources"}
rep["resourcePackages"] = [p for p in rep["resourcePackages"] if p["type"] != "RegisteredResources"] + [
    {"name": "RegisteredResources", "type": "RegisteredResources",
     "items": [{"name": "RvLabelEscuro.json", "path": "RvLabelEscuro.json", "type": "CustomTheme"}]
              + [{"name": i, "path": i, "type": "Image"} for i in imagens]}]
rj.write_text(json.dumps(rep, ensure_ascii=False, indent=2), encoding="utf-8")
print("ok:", [(p[1], len(p[5]) + len(p[4]) + 2) for p in paginas])
