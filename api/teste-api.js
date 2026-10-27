// Teste de ponta a ponta. Precisa do MySQL e da API no ar (npm start). Uso: npm test
// Cria um admin, um produto e um pedido temporários e apaga tudo no fim.
require('dotenv').config();
const test = require('node:test');
const assert = require('node:assert/strict');
const db = require('./db');
const { bcrypt } = require('./auth');

const URL = process.env.API_URL || `http://localhost:${process.env.PORT || 3000}`;

// Este teste escreve (e apaga) dados no banco do .env: não deixa rodar contra um servidor ou banco que não seja local.
const local = (h) => ['localhost', '127.0.0.1', '[::1]', '::1'].includes(h);
if ((!local(process.env.DB_HOST || 'localhost') || !local(new globalThis.URL(URL).hostname)) && process.env.TESTE_EM_BANCO_REMOTO !== 'sim') {
  console.error('Recusado: o teste cria e apaga dados e o banco/API não são locais. Se for de propósito, rode com TESTE_EM_BANCO_REMOTO=sim.');
  process.exit(1);
}

const EMAIL = 'teste-tmp@rvlabel.local', SENHA = 'senha-de-teste-123', COD = 'zz-teste-001', TEL = '35999990000';
const CPF = '12345678909', TEL_OUTRO = '35988887777';
let token, idAdmin, idPedido;

const chama = async (metodo, caminho, corpo, auth = true) => {
  const r = await fetch(URL + caminho, {
    method: metodo,
    headers: { 'Content-Type': 'application/json', ...(auth && token ? { Authorization: `Bearer ${token}` } : {}) },
    body: corpo ? JSON.stringify(corpo) : undefined,
  });
  return { status: r.status, json: await r.json().catch(() => null) };
};

async function limpar() {
  await db.query('DELETE ip FROM item_pedido ip JOIN produto p ON p.id_produto = ip.id_produto WHERE p.codigo = ?', [COD]);
  await db.query('DELETE pe FROM pedido pe JOIN cliente c ON c.id_cliente = pe.id_cliente WHERE c.telefone = ? OR c.cpf = ?', [TEL, CPF]);
  await db.query('DELETE FROM cliente WHERE telefone = ? OR cpf = ?', [TEL, CPF]);
  await db.query('DELETE FROM produto WHERE codigo = ?', [COD]);
  await db.query("DELETE FROM categoria WHERE nome = 'Categoria Teste'");
  await db.query('DELETE FROM administrador WHERE email = ?', [EMAIL]);
}

test.before(async () => {
  await limpar();
  [{ insertId: idAdmin }] = await db.query(
    'INSERT INTO administrador (nome, email, senha) VALUES (?, ?, ?)', ['Teste', EMAIL, await bcrypt.hash(SENHA, 4)]);
});
test.after(async () => { await limpar(); await db.end(); });

test('rotas de admin exigem login', async () => {
  assert.equal((await chama('GET', '/admin/produtos', null, false)).status, 401);
  assert.equal((await chama('GET', '/admin/pedidos', null, false)).status, 401);
});

test('login errado é recusado e certo devolve token', async () => {
  assert.equal((await chama('POST', '/admin/login', { email: EMAIL, senha: 'errada' }, false)).status, 401);
  const ok = await chama('POST', '/admin/login', { email: EMAIL, senha: SENHA }, false);
  assert.equal(ok.status, 200);
  token = ok.json.token;
});

test('cria produto, valida entrada e rejeita código repetido', async () => {
  const base = { codigo: COD, nome: 'Peça de teste', categoria: 'Categoria Teste', preco: 10,
    cores: [{ nome: 'Preto', fotoFrente: 'assets/fotos/x.jpg' }], tamanhos: ['P', 'M'] };
  assert.equal((await chama('POST', '/admin/produtos', { ...base, preco: -1 })).status, 400);
  const ruim = (c) => ({ ...base, cores: [{ nome: 'Preto', fotoFrente: 'assets/fotos/x.jpg', ...c }] });
  assert.equal((await chama('POST', '/admin/produtos', ruim({ tom: 'vermelho' }))).status, 400);
  assert.equal((await chama('POST', '/admin/produtos', ruim({ fotoFrente: '../segredo.jpg' }))).status, 400);
  assert.equal((await chama('POST', '/admin/produtos', base)).status, 201);
  assert.equal((await chama('POST', '/admin/produtos', base)).status, 409);
});

test('estoque: define, barra pedido sem saldo e baixa ao vender', async () => {
  assert.equal((await chama('PUT', '/admin/estoque', { codigo: COD, cor: 'Preto', tamanho: 'P', quantidade: 2 })).status, 200);
  const itens = (q) => ({ comprador: { nome: 'Cliente Teste', telefone: TEL }, itens: [{ produtoId: COD, cor: 'Preto', tamanho: 'P', quantidade: q }] });
  assert.equal((await chama('POST', '/pedidos', itens(3), false)).status, 409);
  const ok = await chama('POST', '/pedidos', itens(2), false);
  assert.equal(ok.status, 201);
  idPedido = ok.json.id;
  const lista = (await chama('GET', '/admin/produtos')).json.find((p) => p.codigo === COD);
  assert.equal(lista.variacoes.find((v) => v.tamanho === 'P').estoque, 0);
});

test('cliente só vê o pedido com número + telefone certos', async () => {
  assert.equal((await chama('GET', `/pedidos/${idPedido}?telefone=35911112222`, null, false)).status, 404);
  const ok = await chama('GET', `/pedidos/${idPedido}?telefone=${TEL}`, null, false);
  assert.equal(ok.status, 200);
  assert.equal(ok.json.status, 'Recebido');
});

test('quem usa o CPF de outra pessoa com outro telefone não passa a ver os pedidos dela', async () => {
  // Tamanho M não tem controle de estoque, então não mexe no saldo que o teste de estoque confere.
  const pedir = (comprador) => chama('POST', '/pedidos', { comprador, itens: [{ produtoId: COD, cor: 'Preto', tamanho: 'M', quantidade: 1 }] }, false);
  const ver = (id, tel) => chama('GET', `/pedidos/${id}?telefone=${tel}`, null, false);

  const dela = await pedir({ nome: 'Cliente Teste', telefone: TEL, cpf: CPF });
  assert.equal(dela.status, 201);
  const intruso = await pedir({ nome: 'Intruso', telefone: TEL_OUTRO, cpf: CPF });
  assert.equal(intruso.status, 201);

  assert.equal((await ver(dela.json.id, TEL_OUTRO)).status, 404); // o intruso não vê o pedido dela
  assert.equal((await ver(dela.json.id, TEL)).status, 200); // ela continua vendo
  assert.equal((await ver(intruso.json.id, TEL_OUTRO)).status, 200); // e cada um vê o próprio pedido

  const [[cadastro]] = await db.query('SELECT nome, telefone FROM cliente WHERE cpf = ?', [CPF]);
  assert.deepEqual({ ...cadastro }, { nome: 'Cliente Teste', telefone: TEL }); // o cadastro não foi reescrito
});

test('status do pedido muda e cancelar devolve o estoque', async () => {
  assert.equal((await chama('PATCH', `/admin/pedidos/${idPedido}`, { status: 'inventado' })).status, 400);
  assert.equal((await chama('PATCH', `/admin/pedidos/${idPedido}`, { status: 'Em separação' })).status, 200);
  assert.equal((await chama('PATCH', `/admin/pedidos/${idPedido}`, { status: 'Cancelado' })).status, 200);
  const p = (await chama('GET', '/admin/produtos')).json.find((x) => x.codigo === COD);
  assert.equal(p.variacoes.find((v) => v.tamanho === 'P').estoque, 2);
  assert.equal((await chama('PATCH', `/admin/pedidos/${idPedido}`, { status: 'Recebido' })).status, 409);
});

test('o pedido guarda o custo da peça; entregue pode virar devolvido, que devolve o estoque e encerra', async () => {
  assert.equal((await chama('PATCH', `/admin/produtos/${COD}`, { custo: -1 })).status, 400);
  assert.equal((await chama('PATCH', `/admin/produtos/${COD}`, { custo: 4.5 })).status, 200);
  await chama('PUT', '/admin/estoque', { codigo: COD, cor: 'Preto', tamanho: 'P', quantidade: 1 });
  const novo = await chama('POST', '/pedidos', { comprador: { nome: 'Cliente Teste', telefone: TEL }, itens: [{ produtoId: COD, cor: 'Preto', tamanho: 'P', quantidade: 1 }] }, false);
  assert.equal(novo.status, 201);
  const [[item]] = await db.query('SELECT custo_unitario FROM item_pedido WHERE id_pedido = ?', [novo.json.id]);
  assert.equal(Number(item.custo_unitario), 4.5);

  const mudar = (status) => chama('PATCH', `/admin/pedidos/${novo.json.id}`, { status });
  assert.equal((await mudar('Devolvido')).status, 409); // só depois de entregue
  assert.equal((await mudar('Entregue')).status, 200);
  assert.equal((await mudar('Devolvido')).status, 200);
  const p = (await chama('GET', '/admin/produtos')).json.find((x) => x.codigo === COD);
  assert.equal(p.variacoes.find((v) => v.tamanho === 'P').estoque, 1);
  assert.equal((await mudar('Entregue')).status, 409);
});

test('pedido simulado (demonstração do dashboard) não aparece na consulta nem no painel', async () => {
  const [{ insertId: cli }] = await db.query("INSERT INTO cliente (nome, telefone, simulado) VALUES ('Simulada', ?, 1)", [TEL]);
  const [{ insertId: id }] = await db.query(
    "INSERT INTO pedido (id_cliente, nome_comprador, telefone, status, simulado) VALUES (?, 'Simulada', ?, 'Entregue', 1)", [cli, TEL]);
  assert.equal((await chama('GET', `/pedidos/${id}?telefone=${TEL}`, null, false)).status, 404);
  assert.ok(!(await chama('GET', '/admin/pedidos')).json.some((p) => p.id === id));
  assert.equal((await chama('PATCH', `/admin/pedidos/${id}`, { status: 'Cancelado' })).status, 404);
});

test('desativar produto o tira da vitrine pública', async () => {
  assert.equal((await chama('PATCH', `/admin/produtos/${COD}`, { ativo: false })).status, 200);
  const vitrine = (await chama('GET', '/produtos', null, false)).json.pecas;
  assert.ok(!vitrine.some((p) => p.id === COD));
});

test('pedir peça desativada devolve o nome dela, não o código interno', async () => {
  const r = await chama('POST', '/pedidos', { comprador: { nome: 'Cliente Teste', telefone: TEL }, itens: [{ produtoId: COD, cor: 'Preto', tamanho: 'M', quantidade: 1 }] }, false);
  assert.equal(r.status, 400);
  assert.match(r.json.erro, /Peça de teste/);
  assert.doesNotMatch(r.json.erro, new RegExp(COD));
});

test('pedido rejeita nome longo demais, quantidade absurda e sacola enorme', async () => {
  const item = { produtoId: COD, cor: 'Preto', tamanho: 'M', quantidade: 1 };
  const pedir = (corpo) => chama('POST', '/pedidos', { comprador: { nome: 'Cliente Teste', telefone: TEL }, itens: [item], ...corpo }, false);
  assert.equal((await pedir({ comprador: { nome: 'x'.repeat(121), telefone: TEL } })).status, 400);
  assert.equal((await pedir({ itens: [{ ...item, quantidade: 100 }] })).status, 400);
  assert.equal((await pedir({ itens: Array(51).fill(item) })).status, 400);
});

test('/saude responde sem login e as respostas levam os cabeçalhos de segurança', async () => {
  const r = await fetch(`${URL}/saude`);
  assert.equal(r.status, 200);
  assert.deepEqual(await r.json(), { ok: true });
  assert.equal(r.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(r.headers.get('x-powered-by'), null);
  const p = await fetch(`${URL}/pedidos/1?telefone=00000000000`);
  assert.equal(p.headers.get('cache-control'), 'no-store');
});

// Por último: esgota o limite deste IP, e as demais rotas de pedido deixam de responder por alguns minutos.
test('consultar pedido muitas vezes seguidas é barrado com 429', async () => {
  const status = [];
  for (let i = 0; i < 40; i++) status.push((await chama('GET', `/pedidos/${idPedido}?telefone=35900000000`, null, false)).status);
  assert.ok(status.includes(429), 'nenhuma das 40 consultas foi barrada');
  assert.ok(status.indexOf(429) >= 20, 'o limite começou cedo demais e atrapalha uso normal');
});
