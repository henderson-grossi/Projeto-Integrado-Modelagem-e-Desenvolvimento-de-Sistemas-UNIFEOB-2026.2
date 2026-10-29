"""Gera tema, medidas e as 6 páginas do dashboard RV Label no projeto .pbip (formato PBIR + TMDL).
Uso: python -I docs/powerbi/gerar_dashboard.py docs/powerbi/projeto   (precisa de Pillow e das fontes Segoe do Windows)
Depois, abra o .pbip no Power BI Desktop e clique em Atualizar."""
import sys, json, re, shutil
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
def field(f): return {f[0]: {"Expression": {"SourceRef": {"Entity": f[1]}}, "Property": f[2]}}
def proj(f, nome=None, ativo=False):
    p = {"field": field(f), "queryRef": f"{f[1]}.{f[2]}", "nativeQueryRef": f[2]}
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
    obj = {"labels": props(show=lit(rotulos), labelDisplayUnits=lit(1))}
    if rotulos:  # com rótulo em cada barra o eixo de valor só repete informação
        obj["valueAxis"] = props(show=lit(False))
    if tipo == "clusteredBarChart":  # mais espaço para nomes longos ("Cartão de Crédito", nomes das vendedoras)
        obj["categoryAxis"] = props(maxMarginFactor=lit(45))
    ordem = (val, "Descending") if ordem_por_valor else (cat, "Ascending")
    return visual(nome, tipo, x, y, w, h, {"Category": [proj(cat, rotulo_cat, ativo=True)], "Y": [proj(val)]},
                  titulo, ordem, obj)

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

def tabela(nome, x, y, w, h, colunas, titulo, ordem, total=True):
    obj = None if total else {"total": props(totals=lit(False))}
    return visual(nome, "tableEx", x, y, w, h, {"Values": [proj(f, r) for f, r in colunas]}, titulo, ordem, obj)

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
        barras("p2_mensal", "clusteredColumnChart", MX, L1_Y, ESQ_L, L1_H, MES, FAT, "Faturamento mensal", "Mês",
               ordem_por_valor=False, rotulos=False),  # 27 meses: rótulo em cada barra se sobrepunha
        barras("p2_semana", "clusteredBarChart", DIR_X, L1_Y, DIR_L, L1_H, C("dim_Calendario", "Dia_Semana"), FAT,
               "Faturamento por dia da semana", "Dia", ordem_por_valor=False),
        tabela("p2_produtos", MX, L2_Y, ESQ_L, L2_H, [
            (C("dim_Produtos", "Produto"), "Produto"), (C("dim_Produtos", "Cor"), "Cor"),
            (ITENS, "Itens"), (FAT, "Faturamento"), (MARGEM, "Margem")], "Produtos mais vendidos", (FAT, "Descending")),
        barras("p2_categoria_itens", "clusteredBarChart", DIR_X, L2_Y, DIR_L, L2_H, CAT, ITENS,
               "Itens vendidos por categoria"),
    ]),
    ("estoque", "Estoque", "Estoque", "Posição do último mês filtrado",
     [(EST, "Peças em estoque", I_CAIXA), (VAL_EST, "Valor em estoque", I_RECEITA),
      (SKU_AT, "SKUs em atenção", I_ALERTA), (SAI, "Saídas (un.)", I_ATIV)], [
        linhas("p3_fluxo", MX, L1_Y, 560, L1_H, MES, [SAI, ENT], "Saídas x reposições por mês",
               [SERIES[0], SERIES[1]], nomes=["Saídas", "Reposições"]),
        barras("p3_por_cat", "clusteredBarChart", MX, L2_Y, 560, L2_H, CAT, EST, "Peças em estoque por categoria"),
        tabela("p3_situacao", MX + 560 + GAP, TOPO_PAINEIS, 1280 - 2 * MX - 560 - GAP, ALTO_H, [
            (C("dim_Produtos", "SKU"), "SKU"), (C("dim_Produtos", "Produto"), "Produto"),
            (EST, "Estoque"), (EST_MIN, "Mínimo"), (SIT, "Situação"), (VAL_EST, "Valor")],
            "Situação do estoque por SKU", (EST, "Ascending"), total=False),
    ]),
    ("clientes", "Clientes", "Clientes", SUB,
     [(CLI, "Clientes ativos", I_PESSOAS), (PED_E, "Pedidos entregues", I_CAIXA),
      (PED_CLI, "Pedidos por cliente", I_PESSOA), (TICKET, "Ticket médio", I_CARTAO)], [
        barras("p4_cidade", "clusteredBarChart", MX, TOPO_PAINEIS, 600, ALTO_H, C("dim_Clientes", "Cidade"), FAT,
               "Faturamento por cidade", "Cidade"),
        barras("p4_faixa", "clusteredColumnChart", MX + 600 + GAP, L1_Y, 1280 - 2 * MX - 600 - GAP, 230,
               C("dim_Clientes", "Faixa_Etaria"), FAT, "Faturamento por faixa etária", "Faixa etária",
               ordem_por_valor=False),
        tabela("p4_top", MX + 600 + GAP, L1_Y + 230 + GAP, 1280 - 2 * MX - 600 - GAP, FIM - (L1_Y + 230 + GAP), [
            (C("dim_Clientes", "Nome"), "Cliente"), (C("dim_Clientes", "Cidade"), "Cidade"),
            (PED_E, "Pedidos"), (FAT, "Faturamento"), (TICKET, "Ticket médio")],
            "Melhores clientes", (FAT, "Descending")),
    ]),
    ("metas_equipe", "Metas e Equipe", "Metas e equipe", SUB,
     [(META, "Meta", I_BANDEIRA), (FAT, "Faturamento", I_RECEITA), (ATING, "Atingimento da meta", I_META),
      (DEV, "Taxa de devolução", I_TROCA)], [
        visual("p5_matriz", "pivotTable", MX, L1_Y, 1280 - 2 * MX, 276,
               {"Rows": [proj(CAT, "Categoria")], "Columns": [proj(C("dim_Calendario", "Ano_Trimestre"), "Trimestre")],
                "Values": [proj(ATING, "Atingimento")]},
               "Atingimento da meta por categoria e trimestre"),  # por mês eram 27 colunas e a matriz rolava
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

# ---------------- fundos (PNG 2x) no estilo do modelo ----------------
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ESC = 2
FONTES = "C:/Windows/Fonts/"
def fonte(arq, tam): return ImageFont.truetype(FONTES + arq, tam * ESC)
def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
def caixa(x, y, w, h): return [x * ESC, y * ESC, (x + w) * ESC - 1, (y + h) * ESC - 1]

def quadrado_icone(base, x, y, glifo):
    """Quadrado com degradê diagonal do vermelho da marca, sombra suave e ícone branco (como no modelo)."""
    s = ICONE * ESC
    sombra = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(sombra).rounded_rectangle(caixa(x + 3, y + 4, ICONE, ICONE), 9 * ESC, fill=(0, 0, 0, 170))
    base.alpha_composite(sombra.filter(ImageFilter.GaussianBlur(4 * ESC)))
    a, b = rgb("#8E0E18"), rgb("#E5484D")
    grad = Image.new("RGBA", (s, s))
    px = grad.load()
    for i in range(s):
        for j in range(s):
            t = (i + j) / (2 * s - 2)
            px[i, j] = tuple(int(a[k] + (b[k] - a[k]) * t) for k in range(3)) + (255,)
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], 9 * ESC, fill=255)
    base.paste(grad, (x * ESC, y * ESC), mask)
    d = ImageDraw.Draw(base)
    f = fonte("segmdl2.ttf", 20)
    l, t_, r, b_ = d.textbbox((0, 0), glifo, font=f)
    d.text(((x + ICONE / 2) * ESC - (l + r) / 2, (y + ICONE / 2) * ESC - (t_ + b_) / 2), glifo, font=f, fill=rgb(TXT))

def desenhar_navegacao(d, atual):
    """Botões de navegação: ícone + nome centralizados; a página atual em vermelho da marca."""
    f_ico, f_txt, f_txt_b = fonte("segmdl2.ttf", 11), fonte("segoeui.ttf", 10), fonte("segoeuib.ttf", 10)
    for pid, rotulo, glifo, x, y in nav_celulas():
        ativo = pid == atual
        d.rounded_rectangle(caixa(x, y, NAV_CW, NAV_CH), 7 * ESC, fill=rgb("#B3121E" if ativo else PAINEL))
        ft, cor_txt = (f_txt_b, TXT) if ativo else (f_txt, TXT2)
        li, ti, ri, bi = d.textbbox((0, 0), glifo, font=f_ico)
        lt, tt, rt, bt = d.textbbox((0, 0), rotulo, font=ft)
        espaco = 5 * ESC
        x0 = (x + NAV_CW / 2) * ESC - ((ri - li) + espaco + (rt - lt)) / 2
        meio = (y + NAV_CH / 2) * ESC
        d.text((x0 - li, meio - (ti + bi) / 2), glifo, font=f_ico, fill=rgb(cor_txt))
        d.text((x0 + (ri - li) + espaco - lt, meio - (tt + bt) / 2), rotulo, font=ft, fill=rgb(cor_txt))

def desenhar_fundo(titulo, sub, icones, paineis, destino, atual):
    im = Image.new("RGBA", (1280 * ESC, 720 * ESC), rgb(BG) + (255,))
    d = ImageDraw.Draw(im)
    # marca "RV" + título + subtítulo
    # cabeçalho sobe 20 px para caber o navegador de páginas embaixo (y 82 a 126)
    d.rounded_rectangle(caixa(MX, 20, 52, 52), 12 * ESC, fill=rgb("#B3121E"))
    f = fonte("segoeuib.ttf", 20)
    l, t_, r, b_ = d.textbbox((0, 0), "RV", font=f)
    d.text(((MX + 26) * ESC - (l + r) / 2, 46 * ESC - (t_ + b_) / 2), "RV", font=f, fill=rgb(TXT))
    d.text((86 * ESC, 20 * ESC), titulo, font=fonte("segoeuib.ttf", 21), fill=rgb(TXT))
    if sub:  # sem texto fixo, o cartão Período ocupa este lugar
        d.text((86 * ESC, 53 * ESC), sub, font=fonte("segoeui.ttf", 11), fill=rgb(TXT2))
    # fundos dos filtros
    f_rot = fonte("segoeui.ttf", 11)
    for y, rotulo in zip(FILTROS_Y, ("Mês", "Categoria")):
        d.rounded_rectangle(caixa(FILTRO_X, y, FILTRO_W, FILTRO_H), 10 * ESC, fill=rgb(PAINEL))
        l, t_, r, b_ = d.textbbox((0, 0), rotulo, font=f_rot)
        d.text(((FILTRO_X + 12) * ESC, (y + FILTRO_H / 2) * ESC - (t_ + b_) / 2), rotulo, font=f_rot, fill=rgb(TXT2))
    # tiles dos indicadores
    for glifo, (x, y, w, h) in zip(icones, tiles(len(icones))):
        d.rounded_rectangle(caixa(x, y, w, h), 12 * ESC, fill=rgb(PAINEL))
        quadrado_icone(im, x + 12, y + (h - ICONE) // 2, glifo)
        d = ImageDraw.Draw(im)
    desenhar_navegacao(d, atual)
    # linha divisória
    d.line([MX * ESC, 134 * ESC, (1280 - MX) * ESC, 134 * ESC], fill=rgb("#3A3A3F"), width=ESC)
    # painéis dos visuais
    for x, y, w, h in paineis:
        d.rounded_rectangle(caixa(x, y, w, h), 14 * ESC, fill=rgb(PAINEL))
    im.convert("RGB").save(destino, optimize=True)

# ---------------- grava páginas ----------------
PAGES = REP / "definition" / "pages"
reg = REP / "StaticResources" / "RegisteredResources"
reg.mkdir(parents=True, exist_ok=True)
for d in PAGES.iterdir():
    if d.is_dir(): shutil.rmtree(d)
for f in reg.glob("fundo_*.png"):
    f.unlink()
imagens = []
for pid, nome, titulo, sub, indicadores, graficos in paginas:
    img = f"fundo_{pid}.png"
    imagens.append(img)
    desenhar_fundo(titulo, sub, [i for _, _, i in indicadores],
                   [(g["position"]["x"], g["position"]["y"], g["position"]["width"], g["position"]["height"])
                    for g in graficos], reg / img, pid)
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
