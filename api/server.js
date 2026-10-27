const express = require('express');
const cors = require('cors');
const db = require('./db');
const { router: adminRouter, itensSql } = require('./admin');
const { criarLimite } = require('./limite');

const app = express();

// Atrás de um proxy (Nginx, Render, Railway...) o IP real vem em X-Forwarded-For. TRUST_PROXY = quantos proxies ficam
// entre o cliente e esta API (normalmente 1). Valor errado deixa o cliente forjar o IP e fugir dos limites abaixo.
const proxies = parseInt(process.env.TRUST_PROXY ?? '', 10);
if (proxies > 0) app.set('trust proxy', proxies);
app.disable('x-powered-by');
app.use((_req, res, next) => {
  res.set('X-Content-Type-Options', 'nosniff');
  next();
});
// Pedido e painel têm dado pessoal: nenhum navegador ou proxy deve guardar a resposta.
app.use(['/pedidos', '/admin'], (_req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
});

// Rotas públicas de pedido: sem limite, um script enche o banco de pedidos falsos, zera o estoque ou testa
// telefones até achar o de uma cliente.
const limitePedir = criarLimite({ janelaMs: 10 * 60_000, max: 20 });
const limiteConsultar = criarLimite({ janelaMs: 10 * 60_000, max: 30 });

// CORS só importa para navegador (site e app web). CORS_ORIGIN = origens permitidas, separadas por vírgula.
// Sem ela: aberto para desenvolvimento, mas fechado quando NODE_ENV=production.
const origens = (process.env.CORS_ORIGIN ?? '').split(',').map((o) => o.trim()).filter(Boolean);
app.use(cors({ origin: origens.length ? origens : process.env.NODE_ENV !== 'production' }));
if (!origens.length) {
  console.warn(process.env.NODE_ENV === 'production'
    ? 'CORS_ORIGIN vazio em produção: navegadores de outros sites não conseguem chamar a API.'
    : 'CORS aberto (CORS_ORIGIN vazio). Defina CORS_ORIGIN antes de hospedar.');
}
app.use(express.json());

class Erro extends Error {
  constructor(status, mensagem) {
    super(mensagem);
    this.status = status;
  }
}

// Express 4 não captura erro de async sozinho.
const rota = (fn) => async (req, res) => {
  try {
    await fn(req, res);
  } catch (e) {
    if (e instanceof Erro) return res.status(e.status).json({ erro: e.message });
    console.error(e);
    res.status(500).json({ erro: 'Erro interno.' });
  }
};

const agrupar = (linhas) => {
  const m = new Map();
  for (const l of linhas) {
    if (!m.has(l.id_produto)) m.set(l.id_produto, []);
    m.get(l.id_produto).push(l);
  }
  return m;
};

// Mesmo formato do assets/catalogo.json: o Produto.fromJson do app não muda.
app.get('/produtos', rota(async (_req, res) => {
  const [prods] = await db.query(
    `SELECT p.*, c.nome AS categoria
     FROM produto p JOIN categoria c ON c.id_categoria = p.id_categoria
     WHERE p.ativo = 1 ORDER BY p.id_produto`);
  const [cores] = await db.query(
    `SELECT pc.id_produto, co.nome, pc.foto_frente, pc.foto_costas, pc.hue, pc.tom
     FROM produto_cor pc JOIN cor co ON co.id_cor = pc.id_cor
     ORDER BY pc.ordem, co.id_cor`);
  const [tams] = await db.query(
    `SELECT DISTINCT v.id_produto, t.nome, t.id_tamanho
     FROM variacao v JOIN tamanho t ON t.id_tamanho = v.id_tamanho
     ORDER BY t.id_tamanho`);
  const c = agrupar(cores), t = agrupar(tams);

  const pecas = prods.map((p) => {
    const cs = c.get(p.id_produto) ?? [];
    const j = {
      id: p.codigo,
      nome: p.nome,
      categoria: p.categoria,
      descricao: p.descricao ?? '',
      preco: p.preco,
      fotos: cs.length ? [cs[0].foto_frente] : [],
      cores: cs.map((x) => ({
        nome: x.nome,
        ...(x.hue != null ? { hue: x.hue } : {}),
        ...(x.tom ? { tom: x.tom } : {}),
      })),
    };
    if (p.tipo === 'acessorio') {
      j.tipo = 'acessorio';
      j.material = p.material;
    } else {
      j.tamanhos = (t.get(p.id_produto) ?? []).map((x) => x.nome);
      j.fotoCostas = cs[0]?.foto_costas ?? null;
    }
    return j;
  });
  res.json({ pecas });
}));

// Só as variações com controle de estoque (quantidade_estoque não nula).
app.get('/estoque', rota(async (_req, res) => {
  const [rows] = await db.query(
    `SELECT p.codigo AS produto_id, co.nome AS cor, t.nome AS tamanho, v.quantidade_estoque AS quantidade
     FROM variacao v
     JOIN produto p  ON p.id_produto = v.id_produto
     JOIN cor co     ON co.id_cor = v.id_cor
     JOIN tamanho t  ON t.id_tamanho = v.id_tamanho
     WHERE v.quantidade_estoque IS NOT NULL`);
  res.json(rows);
}));

// Body: { comprador:{nome,telefone,cpf?}, itens:[{produtoId,cor,tamanho,quantidade}] }
// O preço vem do banco, nunca do app.
app.post('/pedidos', limitePedir, rota(async (req, res) => {
  const { comprador = {}, itens } = req.body ?? {};
  const nome = String(comprador.nome ?? '').trim();
  const telefone = String(comprador.telefone ?? '').replace(/\D/g, '');
  const cpf = String(comprador.cpf ?? '').replace(/\D/g, '') || null;

  if (!nome) throw new Erro(400, 'Informe o nome.');
  if (nome.length > 120) throw new Erro(400, 'Nome muito longo (máximo 120 caracteres).');
  if (telefone.length < 10 || telefone.length > 13) throw new Erro(400, 'Telefone inválido.');
  if (cpf && cpf.length !== 11) throw new Erro(400, 'CPF inválido.');
  if (!Array.isArray(itens) || itens.length === 0) throw new Erro(400, 'Sacola vazia.');
  if (itens.length > 50) throw new Erro(400, 'Itens demais em um só pedido (máximo 50).');

  const con = await db.getConnection();
  try {
    await con.beginTransaction();

    const linhas = [];
    for (const i of itens) {
      const qtd = Number(i.quantidade);
      if (!Number.isInteger(qtd) || qtd < 1 || qtd > 99) throw new Erro(400, 'Quantidade inválida.');
      // A variação (produto + cor + tamanho) tem que existir; trava só a linha dela.
      const [[v]] = await con.query(
        `SELECT p.id_produto, p.nome, p.preco, p.custo, v.id_cor, v.id_tamanho, v.quantidade_estoque
         FROM produto p
         JOIN cor co    ON co.nome = ?
         JOIN tamanho t ON t.nome = ?
         JOIN variacao v ON v.id_produto = p.id_produto AND v.id_cor = co.id_cor AND v.id_tamanho = t.id_tamanho
         WHERE p.codigo = ? AND p.ativo = 1
         FOR UPDATE OF v`,
        [i.cor, i.tamanho, i.produtoId]);
      if (!v) {
        // Peça desativada, ou cor/tamanho que ela não tem: a cliente reconhece o nome, não o código interno.
        const [[p]] = await con.query('SELECT nome FROM produto WHERE codigo = ?', [i.produtoId]);
        throw new Erro(400, `Peça indisponível: ${p?.nome ?? 'item da sacola'} (${i.cor}, ${i.tamanho}).`);
      }

      if (v.quantidade_estoque != null) {
        if (v.quantidade_estoque < qtd) throw new Erro(409, `Sem estoque: ${v.nome} (${i.cor}, ${i.tamanho}).`);
        await con.query(
          `UPDATE variacao SET quantidade_estoque = quantidade_estoque - ?
           WHERE id_produto = ? AND id_cor = ? AND id_tamanho = ?`,
          [qtd, v.id_produto, v.id_cor, v.id_tamanho]);
      }
      linhas.push({ v, qtd });
    }

    // Quem já é cliente (mesmo CPF ou telefone) só é reaproveitada: um pedido anônimo nunca reescreve os dados dela
    // (senão bastava mandar o CPF dela com outro telefone para passar a ver os pedidos dela).
    // O nome e o telefone informados ficam no próprio pedido, e é por eles que a consulta autoriza.
    // Cadastro simulado (demonstração do dashboard) nunca é reaproveitado.
    const [[ex]] = await con.query(
      `SELECT id_cliente FROM cliente WHERE ${cpf ? 'cpf' : 'telefone'} = ? AND simulado = 0 LIMIT 1`, [cpf ?? telefone]);
    let clienteId = ex?.id_cliente;
    if (!clienteId) {
      [{ insertId: clienteId }] = await con.query(
        'INSERT INTO cliente (nome, telefone, cpf) VALUES (?, ?, ?)', [nome, telefone, cpf]);
    }

    const centavos = (n) => Math.round(n * 100) / 100;
    const subtotal = (l) => (l.v.preco == null ? null : centavos(l.v.preco * l.qtd));
    const total = centavos(linhas.reduce((s, l) => s + (subtotal(l) ?? 0), 0));
    const pendente = linhas.some((l) => l.v.preco == null);
    const [{ insertId: pedidoId }] = await con.query(
      'INSERT INTO pedido (id_cliente, nome_comprador, telefone, valor_total, preco_pendente) VALUES (?, ?, ?, ?, ?)',
      [clienteId, nome, telefone, total, pendente ? 1 : 0]);
    for (const l of linhas) {
      await con.query(
        `INSERT INTO item_pedido (id_pedido, id_produto, id_cor, id_tamanho, quantidade, preco_unitario, subtotal, custo_unitario)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [pedidoId, l.v.id_produto, l.v.id_cor, l.v.id_tamanho, l.qtd, l.v.preco, subtotal(l), l.v.custo]);
    }

    await con.commit();
    res.status(201).json({ id: pedidoId, total, precoPendente: pendente });
  } catch (e) {
    await con.rollback();
    throw e;
  } finally {
    con.release();
  }
}));

// Consulta do cliente: precisa do número do pedido E do telefone informado nele (um sem o outro não revela nada).
// Compara com o telefone gravado no pedido, que ninguém consegue trocar depois por outro pedido.
app.get('/pedidos/:id', limiteConsultar, rota(async (req, res) => {
  const telefone = String(req.query.telefone ?? '').replace(/\D/g, '');
  const [[p]] = await db.query(
    `SELECT pe.id_pedido AS id, pe.data_pedido AS data, pe.status, pe.valor_total AS total, pe.preco_pendente AS precoPendente
     FROM pedido pe
     WHERE pe.id_pedido = ? AND pe.telefone = ? AND pe.simulado = 0`, [req.params.id, telefone]);
  if (!p) throw new Erro(404, 'Pedido não encontrado. Confira o número e o telefone.');
  const [itens] = await db.query(itensSql('WHERE ip.id_pedido = ?'), [p.id]);
  res.json({ ...p, precoPendente: !!p.precoPendente, itens });
}));

// Para o monitor de disponibilidade da hospedagem: 200 se a API alcança o banco, 503 se não. Não expõe dado nenhum.
app.get('/saude', async (_req, res) => {
  try {
    await db.query('SELECT 1');
    res.json({ ok: true });
  } catch (e) {
    console.error('saude:', e.code || e.message);
    res.status(503).json({ ok: false });
  }
});

app.use('/admin', adminRouter);

const porta = Number(process.env.PORT || 3000);
app.listen(porta, () => console.log(`API RV Label em http://localhost:${porta}`));
