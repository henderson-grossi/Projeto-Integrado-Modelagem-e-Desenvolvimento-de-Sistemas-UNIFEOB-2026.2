-- O que o dashboard de vendas (Power BI) precisa e o banco ainda não guardava. As views ficam na 003.
-- Aplicada por `npm run migrar`. Só acrescenta colunas e tabelas: nenhuma linha é apagada ou alterada.
--
--   simulado = 1      dado de demonstração do dashboard (docs/powerbi/dados-simulados.sql). A API e o painel da loja
--                     nunca mostram nem reaproveitam essas linhas. Para tirar: docs/powerbi/README.md.
--   pedido.status     ganha 'Entregue' e 'Devolvido' (o faturamento do dashboard conta só os entregues).
--   pedido.canal / forma_pagamento / parcelas / id_vendedor   NULL = não informado (pedidos do site e do app).
--   produto.custo     custo atual da peça; item_pedido.custo_unitario guarda o custo na hora da venda (lucro).
--   item_pedido.desconto_perc  0 a 1. O subtotal continua quantidade × preço, sem o desconto.
--   estoque_mensal    fechamento do estoque de cada cor de peça no mês; as saídas vêm dos pedidos.
-- Banco criado com o schema.sql atual? A linha abaixo faz a ferramenta só anotá-la.
-- ja-aplicada: SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pedido' AND COLUMN_NAME = 'simulado'

CREATE TABLE vendedor (
  id_vendedor   INT          NOT NULL AUTO_INCREMENT,
  nome          VARCHAR(120) NOT NULL,
  cargo         VARCHAR(60)  NOT NULL,
  data_admissao DATE         NOT NULL,
  ativo         TINYINT(1)   NOT NULL DEFAULT 1,
  simulado      TINYINT(1)   NOT NULL DEFAULT 0,
  CONSTRAINT pk_vendedor PRIMARY KEY (id_vendedor)
) ENGINE=InnoDB;

ALTER TABLE cliente
  ADD COLUMN cidade       VARCHAR(80) NULL AFTER endereco,
  ADD COLUMN uf           CHAR(2)     NULL AFTER cidade,
  ADD COLUMN faixa_etaria VARCHAR(10) NULL AFTER uf,
  ADD COLUMN simulado     TINYINT(1)  NOT NULL DEFAULT 0;

ALTER TABLE produto
  ADD COLUMN custo DECIMAL(10,2) NULL AFTER preco,
  ADD CONSTRAINT ck_produto_custo CHECK (custo >= 0);

ALTER TABLE pedido
  MODIFY status ENUM('Recebido','Em separação','Enviado','Entregue','Devolvido','Cancelado') NOT NULL DEFAULT 'Recebido',
  ADD COLUMN id_vendedor     INT         NULL AFTER id_cliente,
  ADD COLUMN canal           VARCHAR(30) NULL,
  ADD COLUMN forma_pagamento VARCHAR(30) NULL,
  ADD COLUMN parcelas        TINYINT     NULL,
  ADD COLUMN simulado        TINYINT(1)  NOT NULL DEFAULT 0,
  ADD CONSTRAINT ck_pedido_parcelas CHECK (parcelas BETWEEN 1 AND 24),
  ADD CONSTRAINT fk_pedido_vendedor FOREIGN KEY (id_vendedor)
    REFERENCES vendedor (id_vendedor) ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE item_pedido
  ADD COLUMN custo_unitario DECIMAL(10,2) NULL,
  ADD COLUMN desconto_perc  DECIMAL(5,4)  NOT NULL DEFAULT 0,
  ADD CONSTRAINT ck_item_custo CHECK (custo_unitario >= 0),
  ADD CONSTRAINT ck_item_desconto CHECK (desconto_perc BETWEEN 0 AND 1);

CREATE TABLE meta_mensal (
  id_categoria INT           NOT NULL,
  mes          DATE          NOT NULL,  -- sempre o dia 1
  valor        DECIMAL(10,2) NOT NULL,
  simulado     TINYINT(1)    NOT NULL DEFAULT 0,
  CONSTRAINT pk_meta_mensal PRIMARY KEY (id_categoria, mes),
  CONSTRAINT ck_meta_mes CHECK (DAY(mes) = 1),
  CONSTRAINT ck_meta_valor CHECK (valor >= 0),
  CONSTRAINT fk_meta_categoria FOREIGN KEY (id_categoria)
    REFERENCES categoria (id_categoria) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE estoque_mensal (
  id_produto      INT        NOT NULL,
  id_cor          INT        NOT NULL,
  mes             DATE       NOT NULL,  -- sempre o dia 1
  estoque_inicial INT        NOT NULL,
  entradas        INT        NOT NULL DEFAULT 0,
  estoque_minimo  INT        NOT NULL DEFAULT 0,
  simulado        TINYINT(1) NOT NULL DEFAULT 0,
  CONSTRAINT pk_estoque_mensal PRIMARY KEY (id_produto, id_cor, mes),
  CONSTRAINT ck_estoque_mes CHECK (DAY(mes) = 1),
  CONSTRAINT ck_estoque_valores CHECK (estoque_inicial >= 0 AND entradas >= 0 AND estoque_minimo >= 0),
  CONSTRAINT fk_estoque_produtocor FOREIGN KEY (id_produto, id_cor)
    REFERENCES produto_cor (id_produto, id_cor) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
