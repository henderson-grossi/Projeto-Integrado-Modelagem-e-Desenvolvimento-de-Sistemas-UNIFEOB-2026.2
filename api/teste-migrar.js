// Teste da ferramenta de migração. Precisa só do MySQL (sem a API no ar): npm run test:migrar
// Cria um banco temporário (rv_teste_migrar_*), usa nele o schema.sql e apaga o banco no fim.
require('dotenv').config();
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const { migrar } = require('./migrar');

// Cria e apaga um banco: não deixa rodar contra um servidor que não seja local.
const local = (h) => ['localhost', '127.0.0.1', '[::1]', '::1'].includes(h);
if (!local(process.env.DB_HOST || 'localhost') && process.env.TESTE_EM_BANCO_REMOTO !== 'sim') {
  console.error('Recusado: o teste cria e apaga um banco e o MySQL não é local. Se for de propósito, rode com TESTE_EM_BANCO_REMOTO=sim.');
  process.exit(1);
}

const BANCO = `rv_teste_migrar_${process.pid}`;
const silencio = () => {};
let con;

test.before(async () => {
  con = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    multipleStatements: true,
  });
  await con.query(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8').replaceAll('Rv_Label', BANCO));
  await con.query(`USE \`${BANCO}\``);
});
test.after(async () => {
  await con.query(`DROP DATABASE IF EXISTS \`${BANCO}\``);
  await con.end();
});

test('banco criado pelo schema.sql atual: 001 e 002 são só anotadas, as views (003) são criadas, e rodar de novo não faz nada', async () => {
  assert.deepEqual(await migrar(con, { log: silencio }),
    { aplicadas: ['003-painel-bi-views'], puladas: ['001-pedido-contato', '002-painel-bi'] });
  assert.deepEqual(await migrar(con, { log: silencio }), { aplicadas: [], puladas: [] });
});

test('banco antigo (sem as colunas, telefone com máscara): aplica, tira a máscara e copia para o pedido', async () => {
  await con.query('ALTER TABLE pedido DROP COLUMN nome_comprador, DROP COLUMN telefone');
  await con.query('DELETE FROM schema_migracoes');
  await con.query("INSERT INTO cliente (nome, telefone) VALUES ('Fulana', '(35) 99999-0000')");
  await con.query('INSERT INTO pedido (id_cliente) SELECT id_cliente FROM cliente');

  assert.deepEqual(await migrar(con, { log: silencio }),
    { aplicadas: ['001-pedido-contato', '003-painel-bi-views'], puladas: ['002-painel-bi'] });

  const [[pedido]] = await con.query('SELECT nome_comprador, telefone FROM pedido');
  assert.deepEqual({ ...pedido }, { nome_comprador: 'Fulana', telefone: '35999990000' });
  const [[cliente]] = await con.query('SELECT telefone FROM cliente');
  assert.equal(cliente.telefone, '35999990000');
  const [[coluna]] = await con.query(
    "SELECT IS_NULLABLE AS n FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pedido' AND COLUMN_NAME = 'telefone'");
  assert.equal(coluna.n, 'NO');
  assert.deepEqual(await migrar(con, { log: silencio }), { aplicadas: [], puladas: [] });
});

test('views do dashboard: valores da venda, saídas do estoque vindas dos pedidos e calendário de meses inteiros', async () => {
  await con.query(`
    INSERT INTO administrador (nome, email, senha) VALUES ('A', 'a@teste', 'x');
    INSERT INTO categoria (nome, id_admin) VALUES ('bodys', LAST_INSERT_ID());
    INSERT INTO produto (codigo, nome, preco, custo, id_categoria, id_admin)
      SELECT 'essence-004', 'Body', 74.90, 36.70, id_categoria, id_admin FROM categoria WHERE nome = 'bodys';
    SET @p = LAST_INSERT_ID();
    INSERT INTO cor (nome) VALUES ('Cinza');      SET @c = LAST_INSERT_ID();
    INSERT INTO tamanho (nome) VALUES ('P');      SET @t = LAST_INSERT_ID();
    INSERT INTO produto_cor (id_produto, id_cor, foto_frente) VALUES (@p, @c, 'x.jpg');
    INSERT INTO variacao (id_produto, id_cor, id_tamanho) VALUES (@p, @c, @t);
    INSERT INTO cliente (nome, telefone, simulado) VALUES ('Simulada', '00000000001', 1); SET @cl = LAST_INSERT_ID();
    INSERT INTO pedido (id_cliente, nome_comprador, telefone, data_pedido, status, simulado)
      VALUES (@cl, 'Simulada', '00000000001', '2025-10-15', 'Entregue', 1);
    INSERT INTO item_pedido (id_pedido, id_produto, id_cor, id_tamanho, quantidade, preco_unitario, subtotal, custo_unitario, desconto_perc)
      VALUES (LAST_INSERT_ID(), @p, @c, @t, 2, 74.90, 149.80, 36.70, 0.1);
    INSERT INTO pedido (id_cliente, nome_comprador, telefone, data_pedido, status, simulado)
      VALUES (@cl, 'Simulada', '00000000001', '2025-10-20', 'Cancelado', 1);
    INSERT INTO item_pedido (id_pedido, id_produto, id_cor, id_tamanho, quantidade, preco_unitario, subtotal)
      VALUES (LAST_INSERT_ID(), @p, @c, @t, 1, 74.90, 74.90);
    INSERT INTO estoque_mensal (id_produto, id_cor, mes, estoque_inicial, entradas, estoque_minimo) VALUES (@p, @c, '2025-10-01', 10, 0, 3);`);

  const [[venda]] = await con.query("SELECT * FROM bi_vendas WHERE Status_Pedido = 'Entregue'");
  assert.deepEqual([venda.Valor_Bruto, venda.Valor_Desconto, venda.Valor_Liquido, venda.Custo_Total, venda.Lucro].map(Number),
    [149.8, 14.98, 134.82, 73.4, 61.42]);
  assert.equal(venda.Canal_Venda, 'Site'); // pedido sem canal (site e app)
  const [[peca]] = await con.query('SELECT * FROM bi_produtos');
  assert.equal(peca.ID_Produto, venda.ID_Produto);
  assert.equal(peca.SKU, 'BOD-004-CIN');

  const [[estoque]] = await con.query('SELECT * FROM bi_estoque');
  assert.deepEqual([Number(estoque.Saidas), Number(estoque.Estoque_Final), estoque.Status_Estoque, Number(estoque.Valor_Estoque_Final)],
    [2, 8, 'OK', 293.6]); // o pedido cancelado não conta como saída

  // Vai de out/2025 até o fim do mês do pedido mais recente (o do teste anterior, feito hoje).
  const [[cal]] = await con.query('SELECT MIN(Data) AS ini, COUNT(*) AS dias, MAX(Data) = LAST_DAY(CURDATE()) AS ate_fim FROM bi_calendario');
  assert.equal(cal.ini.toISOString().slice(0, 10), '2025-10-01');
  assert.equal(cal.ate_fim, 1);
  const [[dia]] = await con.query("SELECT Dia_Semana, Semana_Ano, Mes_Ano FROM bi_calendario WHERE Data = '2025-10-01'");
  assert.deepEqual({ ...dia }, { Dia_Semana: 'Quarta', Semana_Ano: 40, Mes_Ano: 'Out/25' }); // igual ao Excel
});
