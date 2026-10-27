-- Views que o Power BI lê (uma por tabela do modelo). Os nomes de coluna são os do modelo, então o relatório não muda.
-- Reais e simulados entram juntos; o dashboard trata os dois igual. Mudar uma view = nova migração com CREATE OR REPLACE.
-- O usuário powerbi_leitura só enxerga estas views (sem telefone, CPF ou endereço): docs/powerbi/README.md.
--
-- Peça do dashboard = produto + cor (o tamanho não entra): ID_Produto é "id_produto-id_cor".
-- Pedido sem canal, pagamento ou parcelas (site e app) aparece como 'Site', 'A combinar' e 1.

CREATE OR REPLACE VIEW bi_categorias AS
SELECT CAST(c.id_categoria AS CHAR)                       AS ID_Categoria,
       CONCAT(UPPER(LEFT(c.nome, 1)), SUBSTRING(c.nome, 2)) AS Categoria,
       c.id_categoria                                     AS Ordem
FROM categoria c
WHERE EXISTS (SELECT 1 FROM produto p WHERE p.id_categoria = c.id_categoria);

CREATE OR REPLACE VIEW bi_produtos AS
SELECT CONCAT(p.id_produto, '-', pc.id_cor)                                   AS ID_Produto,
       CONCAT(UPPER(LEFT(c.nome, 3)), '-', SUBSTRING_INDEX(p.codigo, '-', -1), '-', UPPER(LEFT(co.nome, 3))) AS SKU,
       p.nome                                                                 AS Produto,
       co.nome                                                                AS Cor,
       (SELECT GROUP_CONCAT(t.nome ORDER BY t.id_tamanho SEPARATOR '/')
        FROM variacao v JOIN tamanho t ON t.id_tamanho = v.id_tamanho
        WHERE v.id_produto = pc.id_produto AND v.id_cor = pc.id_cor)          AS Tamanho,
       CAST(p.id_categoria AS CHAR)                                           AS ID_Categoria,
       p.preco                                                                AS Preco_Venda,
       p.custo                                                                AS Custo_Unitario,
       p.preco - p.custo                                                      AS Margem_Valor,
       IF(p.preco > 0, (p.preco - p.custo) / p.preco, 0)                      AS Margem_Perc,
       IF(p.ativo, 'Sim', 'Não')                                              AS Ativo,
       p.codigo                                                               AS Codigo_Catalogo
FROM produto_cor pc
JOIN produto p   ON p.id_produto = pc.id_produto
JOIN categoria c ON c.id_categoria = p.id_categoria
JOIN cor co      ON co.id_cor = pc.id_cor;

CREATE OR REPLACE VIEW bi_clientes AS
SELECT CAST(id_cliente AS CHAR)                  AS ID_Cliente,
       nome                                      AS Nome,
       COALESCE(cidade, 'Não informada')         AS Cidade,
       COALESCE(uf, '')                          AS UF,
       COALESCE(faixa_etaria, 'Não informada')   AS Faixa_Etaria,
       DATE(criado_em)                           AS Data_Cadastro
FROM cliente;

CREATE OR REPLACE VIEW bi_vendedores AS
SELECT CAST(id_vendedor AS CHAR) AS ID_Vendedor, nome AS Nome, cargo AS Cargo, data_admissao AS Data_Admissao
FROM vendedor;

CREATE OR REPLACE VIEW bi_vendas AS
SELECT x.*,
       x.Valor_Bruto - x.Valor_Desconto                   AS Valor_Liquido,
       x.Quantidade * x.Custo_Unitario                    AS Custo_Total,
       x.Valor_Bruto - x.Valor_Desconto - x.Quantidade * x.Custo_Unitario AS Lucro
FROM (
  SELECT CAST(ip.id_item AS CHAR)              AS ID_Venda,
         CAST(pe.id_pedido AS CHAR)            AS ID_Pedido,
         DATE(pe.data_pedido)                  AS Data,
         CAST(pe.id_cliente AS CHAR)           AS ID_Cliente,
         CONCAT(ip.id_produto, '-', ip.id_cor) AS ID_Produto,
         CAST(pe.id_vendedor AS CHAR)          AS ID_Vendedor,
         COALESCE(pe.canal, 'Site')            AS Canal_Venda,
         COALESCE(pe.forma_pagamento, 'A combinar') AS Forma_Pagamento,
         COALESCE(pe.parcelas, 1)              AS Parcelas,
         CAST(pe.status AS CHAR)               AS Status_Pedido,
         ip.quantidade                         AS Quantidade,
         ip.preco_unitario                     AS Preco_Unitario,
         ip.desconto_perc                      AS Desconto_Perc,
         ip.custo_unitario                     AS Custo_Unitario,
         ip.subtotal                           AS Valor_Bruto,
         ROUND(ip.subtotal * ip.desconto_perc, 2) AS Valor_Desconto
  FROM item_pedido ip
  JOIN pedido pe ON pe.id_pedido = ip.id_pedido
) x;

-- Saídas = peças de pedidos não cancelados no mês (devolução conta como saída, como na planilha antiga).
CREATE OR REPLACE VIEW bi_estoque AS
SELECT y.*,
       CASE WHEN y.Estoque_Final < y.Estoque_Minimo THEN 'Abaixo do mínimo'
            WHEN y.Estoque_Final <= 2 * y.Estoque_Minimo THEN 'Atenção'
            ELSE 'OK' END                       AS Status_Estoque,
       y.Estoque_Final * y.custo                AS Valor_Estoque_Final
FROM (
  SELECT CONCAT(em.id_produto, '-', em.id_cor)  AS ID_Produto,
         em.mes                                 AS Data_Mes,
         DATE_FORMAT(em.mes, '%Y-%m')           AS Ano_Mes,
         em.estoque_inicial                     AS Estoque_Inicial,
         em.entradas                            AS Entradas,
         COALESCE(s.saidas, 0)                  AS Saidas,
         em.estoque_inicial + em.entradas - COALESCE(s.saidas, 0) AS Estoque_Final,
         em.estoque_minimo                      AS Estoque_Minimo,
         p.custo
  FROM estoque_mensal em
  JOIN produto p ON p.id_produto = em.id_produto
  LEFT JOIN (
    SELECT ip.id_produto, ip.id_cor, CAST(DATE_FORMAT(pe.data_pedido, '%Y-%m-01') AS DATE) AS mes,
           SUM(ip.quantidade) AS saidas
    FROM item_pedido ip JOIN pedido pe ON pe.id_pedido = ip.id_pedido
    WHERE pe.status <> 'Cancelado'
    GROUP BY ip.id_produto, ip.id_cor, mes
  ) s ON s.id_produto = em.id_produto AND s.id_cor = em.id_cor AND s.mes = em.mes
) y;

CREATE OR REPLACE VIEW bi_metas AS
SELECT CAST(id_categoria AS CHAR) AS ID_Categoria, mes AS Data_Mes, DATE_FORMAT(mes, '%Y-%m') AS Ano_Mes,
       valor AS Meta_Faturamento
FROM meta_mensal;

-- Um dia por linha, do primeiro mês com pedido, meta ou estoque até o fim do último (até 10 mil dias).
-- Semana_Ano segue o WEEKNUM(data; 2) do Excel: semana começa na segunda e a semana 1 contém 1º de janeiro.
CREATE OR REPLACE VIEW bi_calendario AS
SELECT d.Data,
       YEAR(d.Data)                                    AS Ano,
       QUARTER(d.Data)                                 AS Trimestre_Num,
       CONCAT('T', QUARTER(d.Data))                    AS Trimestre,
       MONTH(d.Data)                                   AS Mes_Num,
       ELT(MONTH(d.Data), 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto',
           'Setembro', 'Outubro', 'Novembro', 'Dezembro') AS Mes_Nome,
       ELT(MONTH(d.Data), 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez') AS Mes_Abrev,
       DATE_FORMAT(d.Data, '%Y-%m')                    AS Ano_Mes,
       DAY(d.Data)                                     AS Dia,
       WEEKDAY(d.Data) + 1                             AS Dia_Semana_Num,
       ELT(WEEKDAY(d.Data) + 1, 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo') AS Dia_Semana,
       FLOOR((DAYOFYEAR(d.Data) + WEEKDAY(MAKEDATE(YEAR(d.Data), 1)) - 1) / 7) + 1 AS Semana_Ano,
       IF(WEEKDAY(d.Data) >= 5, 'Sim', 'Não')          AS Fim_de_Semana,
       CONCAT(YEAR(d.Data), '-T', QUARTER(d.Data))     AS Ano_Trimestre,
       IF(MONTH(d.Data) <= 6, 'S1', 'S2')              AS Semestre,
       YEAR(d.Data) * 100 + MONTH(d.Data)              AS Ano_Mes_Num,
       CONCAT(ELT(MONTH(d.Data), 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'),
              '/', RIGHT(YEAR(d.Data), 2))             AS Mes_Ano
FROM (
  SELECT f.inicio + INTERVAL (a.n + 10 * b.n + 100 * c.n + 1000 * k.n) DAY AS Data, f.fim
  FROM (SELECT CAST(DATE_FORMAT(MIN(u.d), '%Y-%m-01') AS DATE) AS inicio, LAST_DAY(MAX(u.d)) AS fim
        FROM (SELECT DATE(data_pedido) AS d FROM pedido
              UNION ALL SELECT mes FROM meta_mensal
              UNION ALL SELECT mes FROM estoque_mensal) u) f
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
              UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
              UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
              UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
              UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) k
) d
WHERE d.Data <= d.fim;
