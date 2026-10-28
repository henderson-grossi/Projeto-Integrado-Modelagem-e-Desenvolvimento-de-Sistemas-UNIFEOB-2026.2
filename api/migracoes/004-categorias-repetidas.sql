-- Junta as categorias repetidas do modelo antigo da atividade (Blusa, Body, Vestido, Acessório) nas do catálogo
-- (blusas, bodys, vestidos, acessorios), que são as que o app usa. Produtos e metas passam para a categoria do
-- catálogo e a repetida é apagada. Só age quando as duas existem: num banco sem repetidas não faz nada.
-- O dashboard mostrava as duas no filtro de Categoria (Blusa e Blusas, Body e Bodys...).

CREATE TEMPORARY TABLE categoria_de_para AS
SELECT de.id_categoria AS de, para.id_categoria AS para
FROM categoria de
JOIN categoria para ON (de.nome, para.nome) IN
  (('Blusa', 'blusas'), ('Body', 'bodys'), ('Vestido', 'vestidos'), ('Acessório', 'acessorios'))
WHERE de.id_categoria <> para.id_categoria;

UPDATE produto p JOIN categoria_de_para m ON m.de = p.id_categoria SET p.id_categoria = m.para;
-- Meta do mesmo mês nas duas: fica a do catálogo.
UPDATE IGNORE meta_mensal mm JOIN categoria_de_para m ON m.de = mm.id_categoria SET mm.id_categoria = m.para;
DELETE mm FROM meta_mensal mm JOIN categoria_de_para m ON m.de = mm.id_categoria;
DELETE c FROM categoria c JOIN categoria_de_para m ON m.de = c.id_categoria;
DROP TEMPORARY TABLE categoria_de_para;

-- No dashboard, o nome com acento que o app mostra (o banco guarda "acessorios").
CREATE OR REPLACE VIEW bi_categorias AS
SELECT CAST(c.id_categoria AS CHAR)                       AS ID_Categoria,
       IF(c.nome = 'acessorios', 'Acessórios',
          CONCAT(UPPER(LEFT(c.nome, 1)), SUBSTRING(c.nome, 2))) AS Categoria,
       c.id_categoria                                     AS Ordem
FROM categoria c
WHERE EXISTS (SELECT 1 FROM produto p WHERE p.id_categoria = c.id_categoria);
