# Dashboard de vendas (Power BI)

O dashboard (`Rv_label-simulacao.pbix`, 5 páginas: Visão Geral, Vendas, Estoque, Clientes, Metas e Equipe) lê o banco
da loja, `Rv_Label`, pelas views `bi_*`. Elas devolvem as mesmas colunas que o modelo do Power BI espera, então
mudar o banco por dentro não quebra o relatório. As views são criadas pela migração `api/migracoes/003-painel-bi-views.sql`.

| View | Tabela no modelo | O que tem |
|---|---|---|
| `bi_vendas` | `fato_Vendas` | um item de pedido por linha, com valor bruto, desconto, líquido, custo e lucro |
| `bi_estoque` | `fato_Estoque` | estoque de cada peça (produto + cor) por mês; as saídas vêm dos pedidos |
| `bi_metas` | `fato_Metas` | meta de faturamento por categoria e mês |
| `bi_produtos` | `dim_Produtos` | peça = produto + cor (o tamanho não entra no dashboard) |
| `bi_categorias`, `bi_clientes`, `bi_vendedores` | `dim_*` | cadastros, sem telefone, CPF ou endereço |
| `bi_calendario` | `dim_Calendario` | um dia por linha, do primeiro ao último mês com dados |

O faturamento conta só pedidos **Entregue**. Na loja, marque o pedido como "Entregue" no painel quando a cliente receber.

## Primeira vez
1. **Banco:** em `api/`, `npm run migrar` (aplica a 002, que cria as tabelas e colunas, e a 003, que cria as views).
2. **Dados de demonstração (opcional):**
   `mysql --default-character-set=utf8mb4 -u root -p Rv_Label < docs/powerbi/dados-simulados.sql`.
   São 489 pedidos de out/2025 a set/2026, com metas e estoque; entram com `simulado = 1`. Rodar de novo recarrega.
3. **Usuário só de leitura**, para o Power BI não ver telefone, CPF nem as outras tabelas (no MySQL, como root):
   ```sql
   CREATE USER 'powerbi_leitura'@'localhost' IDENTIFIED BY 'uma senha forte';
   GRANT SELECT ON rv_label.bi_calendario TO 'powerbi_leitura'@'localhost';
   GRANT SELECT ON rv_label.bi_categorias TO 'powerbi_leitura'@'localhost';
   GRANT SELECT ON rv_label.bi_clientes   TO 'powerbi_leitura'@'localhost';
   GRANT SELECT ON rv_label.bi_estoque    TO 'powerbi_leitura'@'localhost';
   GRANT SELECT ON rv_label.bi_metas      TO 'powerbi_leitura'@'localhost';
   GRANT SELECT ON rv_label.bi_produtos   TO 'powerbi_leitura'@'localhost';
   GRANT SELECT ON rv_label.bi_vendas     TO 'powerbi_leitura'@'localhost';
   GRANT SELECT ON rv_label.bi_vendedores TO 'powerbi_leitura'@'localhost';
   ```
   Guarde a senha em `api/.env` (`POWERBI_DB_PASSWORD`), que não vai para o GitHub.
4. **Conector:** o Power BI precisa do [MySQL Connector/NET](https://dev.mysql.com/downloads/connector/net/)
   (Windows, MSI). Instale e reabra o Power BI.
5. **Power BI:** abra o `.pbix` e clique em *Atualizar*. Na primeira vez ele pede a credencial: aba **Banco de dados**,
   usuário `powerbi_leitura` e a senha. O Power BI guarda a senha no Windows, nunca dentro do arquivo.

O servidor e o banco são os parâmetros `Servidor` (`localhost`) e `Banco` (`rv_label`), em
*Transformar dados > Gerenciar parâmetros*. Para ler o banco hospedado (Aiven), troque o `Servidor`, crie o mesmo
usuário lá e marque a criptografia (SSL) na credencial.

## Dados que a loja ainda alimenta à mão
- **Custo da peça:** no painel (Produtos > "Informar custo"). Cada pedido guarda o custo da hora da venda; sem custo,
  o lucro e a margem daquela venda ficam vazios.
- **Metas:** `INSERT INTO meta_mensal (id_categoria, mes, valor) VALUES (<id da categoria>, '2026-11-01', 1500);`
- **Estoque do mês:** `estoque_mensal` guarda o estoque no início de cada mês, as entradas e o mínimo de cada
  peça e cor. Ninguém preenche isso sozinho ainda, então a página Estoque mostra só os meses que têm essa linha.
- **Canal, pagamento e vendedora:** os pedidos do site e do app aparecem como canal "Site", pagamento "A combinar" e
  sem vendedora, porque a loja não pergunta isso no pedido.

## Tirar os dados de demonstração
Faça backup antes (`npm run backup` em `api/`). Depois, no MySQL:
```sql
START TRANSACTION;
DELETE FROM pedido WHERE simulado = 1;          -- os itens saem junto
DELETE FROM cliente WHERE simulado = 1;
DELETE FROM vendedor WHERE simulado = 1;
DELETE FROM meta_mensal WHERE simulado = 1;
DELETE FROM estoque_mensal WHERE simulado = 1;
COMMIT;
```
O custo que a carga preencheu nas peças `essence-004` a `essence-018` continua; troque pelo custo real no painel.
