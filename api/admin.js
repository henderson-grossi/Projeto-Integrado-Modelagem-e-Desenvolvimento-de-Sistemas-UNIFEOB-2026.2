const express = require('express');
const db = require('./db');
const { login, exigirAdmin } = require('./auth');

class Erro extends Error {
  constructor(status, mensagem) { super(mensagem); this.status = status; }
}
const rota = (fn) => async (req, res) => {
  try { await fn(req, res); } catch (e) {
    if (e instanceof Erro) return res.status(e.status).json({ erro: e.message });
    console.error(e);
    res.status(500).json({ erro: 'Erro interno.' });
  }
};

const STATUS = ['Recebido', 'Em separação', 'Enviado', 'Entregue', 'Devolvido', 'Cancelado'];
// Cancelado e devolvido devolvem o estoque e não podem ser reabertos.
const FINAIS = ['Cancelado', 'Devolvido'];
const texto = (v, max, campo) => {
  const s = String(v ?? '').trim();
  if (!s || s.length > max) throw new Erro(400, `${campo} inválido.`);
  return s;
};
const precoOuNull = (v, campo = 'Preço') => {
  if (v == null || v === '') return null;
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0) throw new Erro(400, `${campo} inválido.`);
  return Math.round(n * 100) / 100;
};

const r = express.Router();

r.post('/login', rota(async (req, res) => {
  const out = await login(req.ip, req.body?.email, req.body?.senha);
  if (out.status !== 200) throw new Erro(out.status, out.erro);
  res.json({ token: out.token, nome: out.nome });
}));

r.use(exigirAdmin);

// Todos os produtos (inclusive inativos) com o estoque de cada variação.
r.get('/produtos', rota(async (_req, res) => {
  const [prods] = await db.query(
    `SELECT p.id_produto, p.codigo, p.tipo, p.nome, p.descricao, p.preco, p.custo, p.ativo, c.nome AS categoria
     FROM produto p JOIN categoria c ON c.id_categoria = p.id_categoria ORDER BY p.id_produto`);
  const [vars] = await db.query(
    `SELECT v.id_produto, co.nome AS cor, t.nome AS tamanho, v.quantidade_estoque AS estoque
     FROM variacao v JOIN cor co ON co.id_cor = v.id_cor JOIN tamanho t ON t.id_tamanho = v.id_tamanho
     ORDER BY co.id_cor, t.id_tamanho`);
  res.json(prods.map(({ id_produto, ...p }) => ({
    ...p, ativo: !!p.ativo,
    variacoes: vars.filter((v) => v.id_produto === id_produto).map(({ id_produto: _, ...v }) => v),
  })));
}));

// Body: { codigo, nome, categoria, tipo?, descricao?, preco?, material?,
//         cores:[{nome, fotoFrente, fotoCostas?, hue?, tom?}], tamanhos?:[...] }
r.post('/produtos', rota(async (req, res) => {
  const b = req.body ?? {};
  const codigo = texto(b.codigo, 40, 'Código');
  const nome = texto(b.nome, 120, 'Nome');
  const categoria = texto(b.categoria, 60, 'Categoria');
  const tipo = b.tipo === 'acessorio' ? 'acessorio' : 'peca';
  const preco = precoOuNull(b.preco);
  const custo = precoOuNull(b.custo, 'Custo');
  if (!Array.isArray(b.cores) || b.cores.length === 0) throw new Erro(400, 'Informe ao menos uma cor.');
  for (const c of b.cores) {
    if (typeof c.fotoFrente !== 'string' || !c.fotoFrente.startsWith('assets/fotos/') || c.fotoFrente.includes('..'))
      throw new Erro(400, 'Foto inválida.');
    if (c.fotoCostas != null && (typeof c.fotoCostas !== 'string' || !c.fotoCostas.startsWith('assets/fotos/') || c.fotoCostas.includes('..')))
      throw new Erro(400, 'Foto das costas inválida.');
    if (c.tom != null && !/^#[0-9A-Fa-f]{6}$/.test(c.tom)) throw new Erro(400, 'Tom inválido (use #RRGGBB).');
  }
  const tamanhos = Array.isArray(b.tamanhos) && b.tamanhos.length ? b.tamanhos : ['Único'];

  const con = await db.getConnection();
  try {
    await con.beginTransaction();
    await con.query('INSERT IGNORE INTO categoria (nome, id_admin) VALUES (?, ?)', [categoria, req.admin.id]);
    const [[cat]] = await con.query('SELECT id_categoria FROM categoria WHERE nome = ?', [categoria]);
    let idProduto;
    try {
      [{ insertId: idProduto }] = await con.query(
        `INSERT INTO produto (codigo, tipo, nome, descricao, preco, custo, material, id_categoria, id_admin)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [codigo, tipo, nome, b.descricao ?? null, preco, custo, b.material ?? null, cat.id_categoria, req.admin.id]);
    } catch (e) {
      if (e.code === 'ER_DUP_ENTRY') throw new Erro(409, 'Já existe um produto com esse código.');
      throw e;
    }
    for (const t of tamanhos) await con.query('INSERT IGNORE INTO tamanho (nome) VALUES (?)', [texto(t, 10, 'Tamanho')]);
    let ordem = 0;
    for (const c of b.cores) {
      const nomeCor = texto(c.nome, 40, 'Cor');
      await con.query('INSERT IGNORE INTO cor (nome) VALUES (?)', [nomeCor]);
      const [[cor]] = await con.query('SELECT id_cor FROM cor WHERE nome = ?', [nomeCor]);
      await con.query(
        `INSERT INTO produto_cor (id_produto, id_cor, foto_frente, foto_costas, hue, tom, ordem)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [idProduto, cor.id_cor, texto(c.fotoFrente, 255, 'Foto'), c.fotoCostas ?? null, c.hue ?? null, c.tom ?? null, ordem++]);
      for (const t of tamanhos) {
        await con.query(
          `INSERT INTO variacao (id_produto, id_cor, id_tamanho)
           SELECT ?, ?, id_tamanho FROM tamanho WHERE nome = ?`, [idProduto, cor.id_cor, t]);
      }
    }
    await con.commit();
    res.status(201).json({ codigo });
  } catch (e) { await con.rollback(); throw e; } finally { con.release(); }
}));

// Só os campos enviados mudam. Produto nunca é apagado (pedidos antigos dependem dele): use ativo=false.
r.patch('/produtos/:codigo', rota(async (req, res) => {
  const b = req.body ?? {};
  const sets = [], vals = [];
  if ('nome' in b) { sets.push('nome = ?'); vals.push(texto(b.nome, 120, 'Nome')); }
  if ('descricao' in b) { sets.push('descricao = ?'); vals.push(b.descricao ? String(b.descricao).slice(0, 500) : null); }
  if ('preco' in b) { sets.push('preco = ?'); vals.push(precoOuNull(b.preco)); }
  if ('custo' in b) { sets.push('custo = ?'); vals.push(precoOuNull(b.custo, 'Custo')); }
  if ('ativo' in b) { sets.push('ativo = ?'); vals.push(b.ativo ? 1 : 0); }
  if (!sets.length) throw new Erro(400, 'Nada para alterar.');
  const [out] = await db.query(`UPDATE produto SET ${sets.join(', ')} WHERE codigo = ?`, [...vals, req.params.codigo]);
  if (out.affectedRows === 0) throw new Erro(404, 'Produto não encontrado.');
  res.json({ ok: true });
}));

// quantidade: número >= 0, ou null para "sem controle".
r.put('/estoque', rota(async (req, res) => {
  const { codigo, cor, tamanho } = req.body ?? {};
  let q = req.body?.quantidade ?? null;
  if (q !== null) {
    q = Number(q);
    if (!Number.isInteger(q) || q < 0) throw new Erro(400, 'Quantidade inválida.');
  }
  const [out] = await db.query(
    `UPDATE variacao v
     JOIN produto p ON p.id_produto = v.id_produto
     JOIN cor co ON co.id_cor = v.id_cor
     JOIN tamanho t ON t.id_tamanho = v.id_tamanho
     SET v.quantidade_estoque = ?
     WHERE p.codigo = ? AND co.nome = ? AND t.nome = ?`, [q, codigo, cor, tamanho]);
  if (out.affectedRows === 0) throw new Erro(404, 'Variação não encontrada.');
  res.json({ ok: true });
}));

// 'AAAA-MM' vira o dia 1 do mês; vazio = sem limite desse lado.
const mesOuNull = (v, campo) => {
  if (v == null || v === '') return null;
  const m = /^(\d{4})-(0[1-9]|1[0-2])$/.exec(String(v));
  if (!m) throw new Erro(400, `${campo} inválido (use AAAA-MM).`);
  return `${m[1]}-${m[2]}-01`;
};

// ?de=AAAA-MM&ate=AAAA-MM filtra pelo mês do pedido (os dois meses entram). Sem período: os 200 mais recentes.
// Pedidos simulados (demonstração do dashboard) entram como os reais; DELETE /admin/simulados apaga todos.
r.get('/pedidos', rota(async (req, res) => {
  const de = mesOuNull(req.query.de, 'Início'), ate = mesOuNull(req.query.ate, 'Fim');
  if (de && ate && de > ate) throw new Erro(400, 'O início do período é depois do fim.');
  const conds = [], vals = [];
  if (de) { conds.push('pe.data_pedido >= ?'); vals.push(de); }
  if (ate) { conds.push('pe.data_pedido < ? + INTERVAL 1 MONTH'); vals.push(ate); }
  const limite = conds.length ? 3000 : 200; // shortcut: período com mais de 3000 pedidos vem cortado; paginar se a loja crescer
  const [peds] = await db.query(
    `SELECT pe.id_pedido AS id, pe.data_pedido AS data, pe.status, pe.valor_total AS total,
            pe.preco_pendente AS precoPendente, pe.nome_comprador AS cliente, pe.telefone
     FROM pedido pe ${conds.length ? `WHERE ${conds.join(' AND ')}` : ''}
     ORDER BY pe.data_pedido DESC, pe.id_pedido DESC LIMIT ${limite}`, vals);
  const [itens] = peds.length
    ? await db.query(itensSql('WHERE ip.id_pedido IN (?)'), [peds.map((p) => p.id)])
    : [[]];
  const porPedido = new Map(peds.map((p) => [p.id, []]));
  for (const i of itens) porPedido.get(i.pedido).push(i);
  res.json(peds.map((p) => ({ ...p, precoPendente: !!p.precoPendente, itens: porPedido.get(p.id) })));
}));

// Apaga de uma vez os dados de demonstração do dashboard: pedidos (com os itens), clientes, vendedoras, metas e
// estoque mensal com simulado = 1. Nada real é tocado.
r.delete('/simulados', rota(async (_req, res) => {
  const con = await db.getConnection();
  try {
    await con.beginTransaction();
    const [pedidos] = await con.query('DELETE FROM pedido WHERE simulado = 1');
    for (const t of ['cliente', 'vendedor', 'meta_mensal', 'estoque_mensal']) {
      await con.query(`DELETE FROM ${t} WHERE simulado = 1`);
    }
    await con.commit();
    res.json({ pedidos: pedidos.affectedRows });
  } catch (e) { await con.rollback(); throw e; } finally { con.release(); }
}));

r.patch('/pedidos/:id', rota(async (req, res) => {
  const status = req.body?.status;
  if (!STATUS.includes(status)) throw new Erro(400, 'Status inválido.');
  const con = await db.getConnection();
  try {
    await con.beginTransaction();
    const [[ped]] = await con.query('SELECT status, simulado FROM pedido WHERE id_pedido = ? FOR UPDATE', [req.params.id]);
    if (!ped) throw new Erro(404, 'Pedido não encontrado.');
    if (FINAIS.includes(ped.status) && status !== ped.status)
      throw new Erro(409, `Pedido ${ped.status.toLowerCase()} não pode ser reaberto.`);
    if (status === 'Devolvido' && ped.status !== 'Entregue' && ped.status !== 'Devolvido')
      throw new Erro(409, 'Só um pedido entregue pode ser devolvido.');
    if (FINAIS.includes(status) && !FINAIS.includes(ped.status) && !ped.simulado) {
      // Devolve ao estoque só o que tem controle (quantidade não nula). Pedido simulado nunca baixou estoque real.
      await con.query(
        `UPDATE variacao v JOIN item_pedido ip
           ON ip.id_produto = v.id_produto AND ip.id_cor = v.id_cor AND ip.id_tamanho = v.id_tamanho
         SET v.quantidade_estoque = v.quantidade_estoque + ip.quantidade
         WHERE ip.id_pedido = ? AND v.quantidade_estoque IS NOT NULL`, [req.params.id]);
    }
    await con.query('UPDATE pedido SET status = ? WHERE id_pedido = ?', [status, req.params.id]);
    await con.commit();
    res.json({ ok: true });
  } catch (e) { await con.rollback(); throw e; } finally { con.release(); }
}));

function itensSql(where) {
  return `SELECT ip.id_pedido AS pedido, p.nome, co.nome AS cor, t.nome AS tamanho,
                 ip.quantidade, ip.preco_unitario AS precoUnitario, ip.subtotal
          FROM item_pedido ip
          JOIN produto p ON p.id_produto = ip.id_produto
          JOIN cor co ON co.id_cor = ip.id_cor
          JOIN tamanho t ON t.id_tamanho = ip.id_tamanho ${where} ORDER BY ip.id_item`;
}

module.exports = { router: r, itensSql, rota, Erro };
