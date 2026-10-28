import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/ativacao_em_lote.dart';
import '../core/indicadores_vendas.dart';
import '../core/moeda.dart';
import '../services/api.dart';
import '../services/api_admin.dart';
import '../services/catalogo_repository.dart';
import 'admin_produto_page.dart';
import 'componentes.dart';
import 'fundo_liquido.dart';
import 'rolagem_suave.dart';
import 'tema.dart';

const _statusPedido = ['Recebido', 'Em separação', 'Enviado', 'Entregue', 'Devolvido', 'Cancelado'];

/// Cancelado e devolvido devolvem o estoque e não podem ser reabertos (a API recusa).
bool _statusFinal(Object? s) => s == 'Cancelado' || s == 'Devolvido';

/// Lista "carregando": blocos com brilho no lugar das linhas.
Widget _carregandoLista() => ListView(
      padding: const EdgeInsets.all(RvSpace.md),
      children: [
        for (var i = 0; i < 6; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: RvSpace.xs),
            child: RvSkeleton(altura: 64, raio: RvRadius.md),
          ),
      ],
    );

Widget _erroLista(VoidCallback recarregar) => Center(
      child: SingleChildScrollView(
        child: RvEmptyState(
          icone: Icons.cloud_off_outlined,
          titulo: 'Não deu para carregar',
          texto: 'Confira a conexão com o servidor.',
          rotuloAcao: 'Tentar de novo',
          aoAcionar: recarregar,
        ),
      ),
    );

/// Área da dona da loja: entra com e-mail e senha e gerencia pedidos e produtos.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.catalogo});
  final CatalogoRepository catalogo;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  @override
  Widget build(BuildContext context) => ApiAdmin.logado
      ? _Painel(catalogo: widget.catalogo, onSair: () => setState(ApiAdmin.sair))
      : _Login(onEntrou: () => setState(() {}));
}

class _Login extends StatefulWidget {
  const _Login({required this.onEntrou});
  final VoidCallback onEntrou;

  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  String? _erro;
  bool _enviando = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ApiAdmin.entrar(_email.text.trim(), _senha.text);
      widget.onEntrou();
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Sem conexão com o servidor.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Área administrativa')),
        body: FundoLiquido(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  TextField(
                    controller: _senha,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    onSubmitted: (_) => _entrar(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _enviando ? null : _entrar, child: const Text('Entrar')),
                  if (_erro != null)
                    Padding(padding: const EdgeInsets.only(top: 12), child: Text(_erro!)),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _Painel extends StatefulWidget {
  const _Painel({required this.onSair, required this.catalogo});
  final VoidCallback onSair;
  final CatalogoRepository catalogo;

  @override
  State<_Painel> createState() => _PainelState();
}

class _PainelState extends State<_Painel> {
  int _versao = 0; // muda ao cadastrar produto, para a lista recarregar
  int _versaoPedidos = 0; // muda ao apagar os dados de demonstração

  Future<void> _apagarSimulados() async {
    final msg = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apagar dados de demonstração?'),
        content: const Text('Saem todos os pedidos, clientes, vendedoras, metas e estoque mensal simulados '
            '(os usados no dashboard de vendas). Os pedidos reais continuam. Não dá para desfazer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n = await ApiAdmin.apagarSimulados();
      msg.showSnackBar(SnackBar(content: Text('$n pedidos de demonstração apagados.')));
      if (mounted) setState(() => _versaoPedidos++);
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(e is ApiErro ? e.mensagem : 'Não foi possível apagar.')));
    }
  }

  Future<void> _novoProduto() async {
    final criou = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => AdminProdutoPage(catalogo: widget.catalogo)));
    if (criou == true) await CatalogoRepository.atualizarCopiaLocal(); // o produto novo também fica guardado
    if (criou == true && mounted) setState(() => _versao++);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Administração'),
            actions: [
              PopupMenuButton<void>(
                tooltip: 'Mais opções',
                itemBuilder: (_) => [
                  PopupMenuItem(onTap: _apagarSimulados, child: const Text('Apagar dados de demonstração')),
                ],
              ),
              TextButton(onPressed: widget.onSair, child: const Text('Sair')),
            ],
            bottom: const TabBar(tabs: [Tab(text: 'Pedidos'), Tab(text: 'Produtos')]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _novoProduto,
            icon: const Icon(Icons.add),
            label: const Text('Novo produto'),
          ),
          body: FundoLiquido(
            child: TabBarView(children: [
              _PedidosAdmin(key: ValueKey(_versaoPedidos)),
              ProdutosAdmin(key: ValueKey(_versao)),
            ]),
          ),
        ),
      );
}

/// Carrega uma lista da API e mostra carregando/erro/lista, com botão de recarregar.
mixin _Carrega<T extends StatefulWidget, L> on State<T> {
  late Future<List<L>> futuro = buscar();
  Future<List<L>> buscar();
  // Com chaves: a seta devolveria o Future da atribuição, e o setState não aceita callback que devolve Future.
  void recarregar() => setState(() {
        futuro = buscar();
      });
  /// "Sem conexão" só para falha de rede de verdade; qualquer outro erro mostra o motivo.
  void aviso(Object e) {
    final texto = e is ApiErro
        ? e.mensagem
        : (e is TimeoutException || e is http.ClientException)
            ? 'Sem conexão com o servidor.'
            : 'Erro inesperado: $e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }
}

class _PedidosAdmin extends StatefulWidget {
  const _PedidosAdmin({super.key});
  @override
  State<_PedidosAdmin> createState() => _PedidosAdminState();
}

class _PedidosAdminState extends State<_PedidosAdmin>
    with _Carrega<_PedidosAdmin, Map<String, dynamic>> {
  String? _de, _ate; // período 'AAAA-MM'; vazio = os 200 pedidos mais recentes

  @override
  Future<List<Map<String, dynamic>>> buscar() => ApiAdmin.pedidos(de: _de, ate: _ate);

  /// Os últimos 48 meses, do mais recente para o mais antigo.
  static final _meses = () {
    final hoje = DateTime.now();
    return [
      for (var i = 0; i < 48; i++)
        DateTime(hoje.year, hoje.month - i).toIso8601String().substring(0, 7),
    ];
  }();
  static const _abrev = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
  static String _rotuloMes(String m) => '${_abrev[int.parse(m.substring(5)) - 1]}/${m.substring(0, 4)}';

  // 'AAAA-MM' compara certo como texto; início depois do fim puxa o outro lado junto.
  void _periodo({String? de, String? ate, bool limpar = false}) {
    setState(() {
      if (limpar) {
        _de = _ate = null;
      } else if (de != null) {
        _de = de;
        if (_ate != null && _ate!.compareTo(de) < 0) _ate = de;
      } else if (ate != null) {
        _ate = ate;
        if (_de != null && _de!.compareTo(ate) > 0) _de = ate;
      }
    });
    recarregar();
  }

  Widget _seletorMes(String rotulo, String? valor, ValueChanged<String> aoEscolher) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$rotulo '),
          DropdownButton<String>(
            value: valor,
            hint: const Text('—'),
            items: [for (final m in _meses) DropdownMenuItem(value: m, child: Text(_rotuloMes(m)))],
            onChanged: (m) => m == null ? null : aoEscolher(m),
          ),
        ],
      );

  Widget _filtroPeriodo() => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: RvSpace.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.date_range, size: 20),
              _seletorMes('De', _de, (m) => _periodo(de: m)),
              _seletorMes('Até', _ate, (m) => _periodo(ate: m)),
              if (_de != null || _ate != null)
                TextButton(onPressed: () => _periodo(limpar: true), child: const Text('Limpar período')),
            ],
          ),
        ),
      );

  Future<void> _mudar(int id, String status) async {
    try {
      await ApiAdmin.mudarStatus(id, status);
      recarregar();
    } catch (e) {
      if (mounted) aviso(e);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _carregandoLista();
          }
          if (snap.hasError) return _erroLista(recarregar);
          final lista = snap.data!;
          final filtrado = _de != null || _ate != null;
          if (lista.isEmpty) {
            return ListaSuave(padding: const EdgeInsets.all(12), children: [
              _filtroPeriodo(),
              RvEmptyState(
                  icone: Icons.receipt_long_outlined,
                  titulo: filtrado ? 'Nenhum pedido no período' : 'Nenhum pedido ainda',
                  texto: filtrado
                      ? 'Escolha outros meses ou limpe o período.'
                      : 'Os pedidos feitos no app aparecem aqui.'),
            ]);
          }
          final ind = IndicadoresVendas.calcular([
            for (final p in lista)
              if (!_statusFinal(p['status'])) (p['total'] as num).toDouble()
          ]);
          return RefreshIndicator(
            onRefresh: () async => recarregar(),
            child: ListaSuave(padding: const EdgeInsets.all(12), children: [
              _filtroPeriodo(),
              if (ind != null) _CartaoIndicadores(ind),
              for (final p in lista)
                Card(
                  child: ExpansionTile(
                    title: Text('#${p['id']} · ${p['cliente']}'),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: RvSpace.xs),
                      child: Wrap(
                        spacing: RvSpace.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          RvStatusBadge(p['status'] as String),
                          Text('${formatarReais((p['total'] as num).toDouble())}'
                              '${p['precoPendente'] == true ? ' + a combinar' : ''}',
                              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                        ],
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Telefone: ${p['telefone']}'),
                      for (final i in (p['itens'] as List).cast<Map<String, dynamic>>())
                        Text('${i['quantidade']}× ${i['nome']} · ${i['cor']} · ${i['tamanho']}'),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: p['status'] as String,
                        items: [
                          for (final s in _statusPedido) DropdownMenuItem(value: s, child: Text(s))
                        ],
                        onChanged: _statusFinal(p['status'])
                            ? null
                            : (s) => s == null ? null : _confirmar(p['id'] as int, s),
                      ),
                    ],
                  ),
                ),
            ]),
          );
        },
      );

  Future<void> _confirmar(int id, String status) async {
    if (_statusFinal(status)) {
      final acao = status == 'Cancelado' ? 'Cancelar pedido' : 'Marcar como devolvido';
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('$acao?'),
          content: const Text('O estoque das peças será devolvido e o pedido não poderá ser reaberto.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(acao)),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _mudar(id, status);
  }
}

/// Resumo das vendas (pedidos não cancelados) no topo da aba Pedidos.
class _CartaoIndicadores extends StatelessWidget {
  const _CartaoIndicadores(this.ind);
  final IndicadoresVendas ind;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Indicadores de vendas (${ind.quantidade} pedidos)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('Soma: ${formatarReais(ind.soma)}'),
            Text('Média: ${formatarReais(ind.media)}'),
            Text('Maior: ${formatarReais(ind.maior)}'),
            Text('Menor: ${formatarReais(ind.menor)}'),
          ]),
        ),
      );
}

/// Lista de produtos da área administrativa: liga/desliga cada peça na loja, altera preço e estoque, e permite
/// marcar várias (ou todas) para ativar ou desativar de uma vez. As funções vêm por parâmetro só para o teste
/// poder trocá-las; no app valem as da API.
class ProdutosAdmin extends StatefulWidget {
  const ProdutosAdmin({
    super.key,
    this.buscarProdutos = ApiAdmin.produtos,
    this.alterarProduto = ApiAdmin.alterarProduto,
    this.atualizarCopia = CatalogoRepository.atualizarCopiaLocal,
  });

  final Future<List<Map<String, dynamic>>> Function() buscarProdutos;
  final Future<void> Function(String codigo, Map<String, dynamic> campos) alterarProduto;

  /// Chamada depois de cada mudança: guarda no aparelho o que a loja mostra agora.
  final Future<void> Function() atualizarCopia;

  @override
  State<ProdutosAdmin> createState() => _ProdutosAdminState();
}

class _ProdutosAdminState extends State<ProdutosAdmin>
    with _Carrega<ProdutosAdmin, Map<String, dynamic>> {
  @override
  Future<List<Map<String, dynamic>>> buscar() => widget.buscarProdutos();

  bool _selecionando = false;
  bool _ocupado = false; // ativando/desativando em lote
  final _marcados = <String>{};
  final _busca = TextEditingController();
  bool? _naLoja; // null = todos
  String? _categoria;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  /// Trocar busca ou filtro desmarca tudo: "Selecionar todos" e o lote valem só para o que está na tela.
  void _mudarFiltro(VoidCallback f) => setState(() {
        f();
        _marcados.clear();
      });

  List<Map<String, dynamic>> _visiveis(List<Map<String, dynamic>> todos) {
    final busca = _busca.text.trim().toLowerCase();
    return [
      for (final p in todos)
        if ((busca.isEmpty || '${p['nome']} ${p['codigo']}'.toLowerCase().contains(busca)) &&
            (_naLoja == null || (p['ativo'] == true) == _naLoja) &&
            (_categoria == null || p['categoria'] == _categoria))
          p,
    ];
  }

  Widget _buscaEFiltros(List<Map<String, dynamic>> todos) {
    final categorias = {for (final p in todos) p['categoria']}.whereType<String>().toList()..sort();
    Widget pilula(String rotulo, bool sel, VoidCallback f) => Padding(
          padding: const EdgeInsets.only(right: RvSpace.sm),
          child: PilulaEscolha(rotulo: rotulo, selecionada: sel, aoTocar: () => _mudarFiltro(f)),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: RvSpace.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _busca,
          onChanged: (_) => _mudarFiltro(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar por nome ou código',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _busca.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    icon: const Icon(Icons.close),
                    onPressed: () => _mudarFiltro(_busca.clear),
                  ),
          ),
        ),
        const SizedBox(height: RvSpace.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            pilula('Todos', _naLoja == null, () => _naLoja = null),
            pilula('Na loja', _naLoja == true, () => _naLoja = true),
            pilula('Desativados', _naLoja == false, () => _naLoja = false),
            if (categorias.isNotEmpty) ...[
              const SizedBox(height: 24, child: VerticalDivider(width: RvSpace.lg)),
              for (final c in categorias)
                pilula(c, _categoria == c, () => _categoria = _categoria == c ? null : c),
            ],
          ]),
        ),
      ]),
    );
  }

  Future<void> _executar(Future<void> Function() acao) async {
    try {
      await acao();
      await widget.atualizarCopia();
      recarregar();
    } catch (e) {
      if (mounted) aviso(e);
    }
  }

  void _sairDaSelecao() => setState(() {
        _selecionando = false;
        _marcados.clear();
      });

  Future<void> _aplicarEmLote(List<Map<String, dynamic>> lista, bool ativo) async {
    setState(() => _ocupado = true);
    final r = await aplicarAtivo(
      produtos: lista,
      codigos: _marcados,
      ativo: ativo,
      alterar: (codigo, v) => widget.alterarProduto(codigo, {'ativo': v}),
    );
    await widget.atualizarCopia();
    if (!mounted) return;
    setState(() => _ocupado = false);
    _sairDaSelecao();
    recarregar();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(resumoDoLote(r, ativo: ativo))));
  }

  /// Barra do topo da lista: "Selecionar vários", ou, no modo de seleção, "Selecionar todos" e as ações.
  Widget _barraSelecao(List<Map<String, dynamic>> lista) {
    if (!_selecionando) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: const Icon(Icons.checklist),
          label: const Text('Selecionar vários'),
          onPressed: lista.isEmpty ? null : () => setState(() => _selecionando = true),
        ),
      );
    }
    final todos = lista.isNotEmpty && _marcados.length == lista.length;
    final pode = _marcados.isNotEmpty && !_ocupado;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // A linha inteira marca/desmarca todos: o texto também é clicável, não só a caixinha.
          InkWell(
            onTap: _ocupado
                ? null
                : () => setState(() {
                      if (todos) {
                        _marcados.clear();
                      } else {
                        _marcados.addAll([for (final p in lista) p['codigo'] as String]);
                      }
                    }),
            child: Row(children: [
              IgnorePointer(
                child: Checkbox(
                  tristate: true,
                  value: todos ? true : (_marcados.isEmpty ? false : null),
                  onChanged: (_) {},
                ),
              ),
              const Text('Selecionar todos'),
              const Spacer(),
              Text('${_marcados.length} de ${lista.length}'),
              const SizedBox(width: 8),
            ]),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text('Ativar'),
              onPressed: pode ? () => _aplicarEmLote(lista, true) : null,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.visibility_off),
              label: const Text('Desativar'),
              onPressed: pode ? () => _aplicarEmLote(lista, false) : null,
            ),
            TextButton(onPressed: _ocupado ? null : _sairDaSelecao, child: const Text('Cancelar')),
          ]),
          if (_ocupado) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        ]),
      ),
    );
  }

  /// Linha do modo de seleção: caixa de marcar, nome e se a peça está na loja.
  Widget _linhaSelecionavel(Map<String, dynamic> p) {
    final codigo = p['codigo'] as String;
    final ativo = p['ativo'] == true;
    return Card(
      child: CheckboxListTile(
        value: _marcados.contains(codigo),
        onChanged: _ocupado
            ? null
            : (v) => setState(() => v == true ? _marcados.add(codigo) : _marcados.remove(codigo)),
        title: Text(p['nome'] as String,
            style: TextStyle(decoration: ativo ? null : TextDecoration.lineThrough)),
        subtitle: Text('$codigo · ${ativo ? 'na loja' : 'desativada'}'),
      ),
    );
  }

  /// Pede um número; vazio devolve null (usado para "sem controle" no estoque).
  Future<(bool, String?)> _perguntar(String titulo, String dica, String inicial) async {
    final c = TextEditingController(text: inicial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: dica),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    final texto = c.text.trim().replaceAll(',', '.');
    c.dispose();
    return (ok == true, texto.isEmpty ? null : texto);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _carregandoLista();
          if (snap.hasError) return _erroLista(recarregar);
          final lista = _visiveis(snap.data!);
          return RefreshIndicator(
            onRefresh: () async => recarregar(),
            child: ListaSuave(padding: const EdgeInsets.all(RvSpace.md), children: [
              _buscaEFiltros(snap.data!),
              _barraSelecao(lista),
              if (lista.isEmpty)
                RvEmptyState(
                  icone: Icons.search_off,
                  titulo: 'Nenhum produto encontrado',
                  rotuloAcao: 'Limpar busca e filtros',
                  aoAcionar: () => _mudarFiltro(() {
                    _busca.clear();
                    _naLoja = null;
                    _categoria = null;
                  }),
                ),
              for (final p in lista)
                if (_selecionando)
                  _linhaSelecionavel(p)
                else
                Card(
                  child: ExpansionTile(
                    title: Text(p['nome'] as String,
                        style: TextStyle(
                            decoration: p['ativo'] == true ? null : TextDecoration.lineThrough)),
                    subtitle: Text('${p['codigo']} · '
                        '${p['preco'] == null ? 'Preço a definir' : formatarReais((p['preco'] as num).toDouble())}'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aparece na loja'),
                        value: p['ativo'] == true,
                        onChanged: (v) => _executar(
                            () => widget.alterarProduto(p['codigo'] as String, {'ativo': v})),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Alterar preço'),
                        onPressed: () async {
                          final (ok, v) = await _perguntar('Preço', 'Ex.: 129,90 (vazio = a definir)',
                              p['preco']?.toString() ?? '');
                          if (!ok) return;
                          final preco = v == null ? null : double.tryParse(v);
                          if (v != null && (preco == null || preco < 0)) return aviso(ApiErro('Preço inválido.'));
                          await _executar(() =>
                              widget.alterarProduto(p['codigo'] as String, {'preco': preco}));
                        },
                      ),
                      // O custo entra no lucro e na margem do dashboard de vendas.
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(p['custo'] == null
                            ? 'Informar custo'
                            : 'Custo: ${formatarReais((p['custo'] as num).toDouble())}'),
                        onPressed: () async {
                          final (ok, v) = await _perguntar('Custo', 'Ex.: 45,00 (vazio = não informado)',
                              p['custo']?.toString() ?? '');
                          if (!ok) return;
                          final custo = v == null ? null : double.tryParse(v);
                          if (v != null && (custo == null || custo < 0)) return aviso(ApiErro('Custo inválido.'));
                          await _executar(() =>
                              widget.alterarProduto(p['codigo'] as String, {'custo': custo}));
                        },
                      ),
                      const Text('Estoque (toque para alterar)'),
                      for (final v in (p['variacoes'] as List).cast<Map<String, dynamic>>())
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${v['cor']} · ${v['tamanho']}'),
                          // Estoque baixo (≤ 2) em amarelo, para repor antes de acabar.
                          trailing: Text(
                            v['estoque'] == null ? 'sem controle' : '${v['estoque']}',
                            style: TextStyle(
                              color: v['estoque'] is num && (v['estoque'] as num) <= 2
                                  ? RvColors.warning
                                  : null,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          onTap: () async {
                            final (ok, q) = await _perguntar(
                                '${v['cor']} · ${v['tamanho']}', 'Quantidade (vazio = sem controle)',
                                v['estoque']?.toString() ?? '');
                            if (!ok) return;
                            final n = q == null ? null : int.tryParse(q);
                            if (q != null && (n == null || n < 0)) return aviso(ApiErro('Quantidade inválida.'));
                            await _executar(() => ApiAdmin.definirEstoque(
                                p['codigo'] as String, v['cor'] as String, v['tamanho'] as String, n));
                          },
                        ),
                    ],
                  ),
                ),
            ]),
          );
        },
      );
}
