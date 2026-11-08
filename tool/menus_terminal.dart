// Loja no terminal: menu de administração e menu de cliente, com as mesmas regras
// e a mesma API do app. Tudo é escolhido por quem está digitando.
//
//   dart run tool/demo_terminal.dart
//
// Precisa da API no ar (cd api; node server.js). Outro endereço:
//   dart run --define=API_URL=http://servidor:3000 tool/demo_terminal.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:rvlabel_app/core/ativacao_em_lote.dart';
import 'package:rvlabel_app/core/filtro_vitrine.dart';
import 'package:rvlabel_app/core/indicadores_vendas.dart';
import 'package:rvlabel_app/core/moeda.dart';
import 'package:rvlabel_app/core/privacidade.dart';
import 'package:rvlabel_app/core/resumo.dart';
import 'package:rvlabel_app/models/models.dart';
import 'package:rvlabel_app/services/api.dart';
import 'package:rvlabel_app/services/api_admin.dart';
import 'package:rvlabel_app/services/sacola_base.dart';

const _whatsappLoja = '5535997186762'; // o mesmo de lib/main.dart
const _statusPedido = ['Recebido', 'Em separação', 'Enviado', 'Entregue', 'Devolvido', 'Cancelado'];
const _etapasPedido = ['Recebido', 'Em separação', 'Enviado', 'Entregue'];

typedef _Opcao = (String, Future<void> Function());

/// Acabou a entrada (Ctrl+Z, ou o fim de um arquivo redirecionado): encerra em vez de perguntar para sempre.
class _FimDaEntrada implements Exception {}

/// O console do Windows pode entregar UTF-8 ou o código de página local: tenta UTF-8 e, se não for, usa os bytes como vieram.
String? _lerDoConsole() {
  final linha = stdin.readLineSync(encoding: latin1);
  if (linha == null) return null;
  try {
    return utf8.decode(latin1.encode(linha));
  } on FormatException {
    return linha;
  }
}

String? _lerSemEco() {
  final console = stdin.hasTerminal;
  if (console) stdin.echoMode = false;
  try {
    return _lerDoConsole();
  } finally {
    if (console) {
      stdin.echoMode = true;
      stdout.writeln();
    }
  }
}

bool _semConexao(Object e) =>
    e is TimeoutException || e is http.ClientException || e is SocketException;

bool _statusFinal(Object? s) => s == 'Cancelado' || s == 'Devolvido';

String _dinheiro(Object? v) => formatarReais((v as num).toDouble());

String _linkWhatsApp(String mensagem) =>
    'https://wa.me/$_whatsappLoja?text=${Uri.encodeComponent(mensagem)}';

class MenusTerminal {
  MenusTerminal({String? Function()? ler, String? Function()? lerOculto, StringSink? saida})
      : _lerLinha = ler ?? _lerDoConsole,
        _lerLinhaOculta = lerOculto ?? ler ?? _lerSemEco,
        _saida = saida ?? stdout;

  final String? Function() _lerLinha;
  final String? Function() _lerLinhaOculta;
  final StringSink _saida;
  final _sacola = SacolaBase();

  Future<void> rodar() async {
    _p('RV Label no terminal');
    try {
      await _menu('Menu inicial', () => [
            ('Administração', _admin),
            ('Cliente (loja)', _cliente),
          ], sair: 'Sair');
    } on _FimDaEntrada {
      _p();
    } finally {
      ApiAdmin.sair();
    }
    _p('Até logo!');
  }

  // ---- entrada e saída ----

  void _p([String texto = '']) => _saida.writeln(texto);

  String _ler(String rotulo) {
    _saida.write('$rotulo: ');
    final linha = _lerLinha();
    if (linha == null) throw _FimDaEntrada();
    return linha.trim();
  }

  Future<void> _menu(String titulo, List<_Opcao> Function() opcoes,
      {String sair = 'Voltar', bool Function()? ativo, void Function()? cabecalho}) async {
    while (ativo?.call() ?? true) {
      _p();
      _p('=== $titulo ===');
      cabecalho?.call();
      final lista = opcoes();
      for (final (i, o) in lista.indexed) {
        _p('${i + 1}. ${o.$1}');
      }
      _p('0. $sair');
      final n = int.tryParse(_ler('Escolha'));
      if (n == 0) return;
      if (n == null || n < 0 || n > lista.length) {
        _p('Opção inválida.');
        continue;
      }
      await _tentar(lista[n - 1].$2);
    }
  }

  Future<void> _tentar(Future<void> Function() acao) async {
    try {
      await acao();
    } on ApiErro catch (e) {
      _p('Erro: ${e.mensagem}');
    } on ArgumentError catch (e) {
      _p('Erro: ${e.message}');
    } catch (e) {
      if (!_semConexao(e)) rethrow;
      _p('Sem conexão com a API em ${Api.baseUrl}. Em outro terminal, rode: cd api; node server.js');
    }
  }

  /// Lista numerada; devolve null quando a pessoa digita 0.
  T? _escolher<T>(String titulo, List<T> itens, String Function(T) rotulo, {String voltar = 'Voltar'}) {
    _p();
    _p(titulo);
    for (final (i, item) in itens.indexed) {
      _p('${i + 1}. ${rotulo(item)}');
    }
    _p('0. $voltar');
    while (true) {
      final n = int.tryParse(_ler('Escolha'));
      if (n == 0) return null;
      if (n != null && n >= 1 && n <= itens.length) return itens[n - 1];
      _p('Opção inválida.');
    }
  }

  bool _confirmar(String pergunta) {
    while (true) {
      final r = _ler('$pergunta (s/n)').toLowerCase();
      if (r == 's' || r == 'sim') return true;
      if (r == 'n' || r == 'nao' || r == 'não') return false;
      _p('Responda s ou n.');
    }
  }

  int _lerInteiro(String rotulo, int minimo, int maximo) {
    while (true) {
      final n = int.tryParse(_ler(rotulo));
      if (n != null && n >= minimo && n <= maximo) return n;
      _p('Digite um número de $minimo a $maximo.');
    }
  }

  /// Texto validado: [erro] devolve a mensagem do problema, ou null se estiver certo. "c" cancela e devolve null.
  String? _lerCampo(String rotulo, String? Function(String) erro) {
    while (true) {
      final v = _ler('$rotulo [c cancela]');
      if (v.toLowerCase() == 'c') return null;
      final problema = erro(v);
      if (problema == null) return v;
      _p(problema);
    }
  }

  String? _obrigatorio(String v) => v.isEmpty ? 'Campo obrigatório.' : null;

  /// Número decimal opcional. Null = cancelou; `valor` null = deixou vazio.
  ({double? valor})? _lerValor(String rotulo) {
    final t = _lerCampo(rotulo, (v) {
      if (v.isEmpty) return null;
      final n = double.tryParse(v.replaceAll(',', '.'));
      return n == null || n < 0 ? 'Valor inválido.' : null;
    });
    if (t == null) return null;
    return (valor: t.isEmpty ? null : double.parse(t.replaceAll(',', '.')));
  }

  // ---- cliente ----

  Future<void> _cliente() => _menu('Cliente', () => [
        ('Ver produtos', _vitrine),
        ('Sacola (${contar(_sacola.quantidadeTotal, 'item', 'itens')})', _verSacola),
        ('Meus pedidos', _meusPedidos),
        ('Resumo da loja', _resumoLoja),
        ('Contato', _contato),
        ('Privacidade e termos', () async => _privacidade()),
      ]);

  /// Peça com dado inválido (categoria que o app não conhece, por exemplo) fica de fora, como no app.
  Future<List<Produto>> _carregarCatalogo() async {
    final dados = await Api.produtos();
    final pecas = <Produto>[];
    for (final p in dados['pecas'] as List) {
      try {
        pecas.add(Produto.fromJson(p as Map<String, dynamic>));
      } on ArgumentError {
        continue;
      } on TypeError {
        continue;
      }
    }
    return pecas;
  }

  /// Quantidade por "código|cor|tamanho". Variação fora do mapa não tem controle de estoque.
  Future<Map<String, int>> _carregarEstoque() async => {
        for (final v in await Api.estoque())
          '${v['produto_id']}|${v['cor']}|${v['tamanho']}': (v['quantidade'] as num).toInt(),
      };

  Future<void> _vitrine() async {
    final todas = await _carregarCatalogo();
    if (todas.isEmpty) return _p('Nenhuma peça à venda agora.');
    final estoque = await _carregarEstoque();
    final resumo = resumirCatalogo(todas);
    final categorias = [for (final c in resumo.categorias) c.categoria];
    final tamanhosLoja = {...resumo.tamanhos, for (final p in todas) ...p.tamanhos}.toList();
    final coresLoja = {for (final p in todas) for (final c in p.cores) c.nome}.toList();
    Categoria? categoria;
    String? tamanho, cor;
    FaixaPreco? faixa;
    var ordem = OrdemVitrine.destaque;

    List<Produto> visiveis() => filtrarVitrine(
          categoria == null ? todas : todas.where((p) => p.categoria == categoria).toList(),
          tamanho: tamanho,
          cor: cor,
          faixa: faixa,
          ordem: ordem,
        );

    await _menu('Produtos', () => [
          ('Ver ${contar(visiveis().length, 'peça', 'peças')}', () => _abrirLista(visiveis(), todas, estoque)),
          ('Categoria: ${categoria?.rotulo ?? 'todas'}', () async {
            categoria = _escolher('Categoria', categorias, (c) => c.rotulo, voltar: 'Todas');
          }),
          ('Tamanho: ${tamanho ?? 'todos'}', () async {
            tamanho = _escolher('Tamanho', tamanhosLoja, (t) => t, voltar: 'Todos');
          }),
          ('Cor: ${cor ?? 'todas'}', () async {
            cor = _escolher('Cor', coresLoja, (c) => c, voltar: 'Todas');
          }),
          ('Faixa de preço: ${faixa?.rotulo ?? 'todas'}', () async {
            faixa = _escolher('Faixa de preço', FaixaPreco.values, (f) => f.rotulo, voltar: 'Todas');
          }),
          ('Ordem: ${ordem.rotulo}', () async {
            ordem = _escolher('Ordem', OrdemVitrine.values, (o) => o.rotulo) ?? ordem;
          }),
          ('Limpar filtros', () async {
            categoria = null;
            tamanho = cor = null;
            faixa = null;
            ordem = OrdemVitrine.destaque;
          }),
        ]);
  }

  Future<void> _abrirLista(List<Produto> lista, List<Produto> todas, Map<String, int> estoque) async {
    if (lista.isEmpty) return _p('Nenhuma peça com esses filtros.');
    while (true) {
      final p = _escolher('Peças', lista, (p) => '${p.nome} - ${p.precoFormatado} (${p.resumo})');
      if (p == null) return;
      await _detalhe(p, todas, estoque);
    }
  }

  Future<void> _detalhe(Produto p, List<Produto> todas, Map<String, int> estoque) {
    // Como no app: as da mesma categoria primeiro, depois as outras, no máximo 3.
    final parecidas = [
      ...todas.where((o) => o.categoria == p.categoria && o.id != p.id),
      ...todas.where((o) => o.categoria != p.categoria),
    ].take(3).toList();
    String variacao(String cor, String tamanho) {
      final q = estoque['${p.id}|$cor|$tamanho'];
      return q == null ? tamanho : '$tamanho (${q > 0 ? q : 'esgotado'})';
    }

    return _menu(p.nome, () => [
          ('Adicionar à sacola', () async => _adicionar(p, estoque)),
          if (parecidas.isNotEmpty)
            ('Peças parecidas', () async {
              final x = _escolher('Você também pode gostar', parecidas,
                  (o) => '${o.nome} - ${o.precoFormatado}');
              if (x != null) await _detalhe(x, todas, estoque);
            }),
        ], cabecalho: () {
      _p(p.resumo);
      _p(p.precoFormatado);
      if (p.descricao.isNotEmpty) _p(p.descricao);
      _p('Variações:');
      for (final c in p.cores) {
        _p('  ${c.nome}: ${p.tamanhos.map((t) => variacao(c.nome, t)).join(', ')}');
      }
    });
  }

  void _adicionar(Produto p, Map<String, int> estoque) {
    final nomesCores = [for (final c in p.cores) c.nome];
    final cor = nomesCores.length == 1 ? nomesCores.first : _escolher('Cor', nomesCores, (c) => c);
    if (cor == null) return;
    final tamanho = p.tamanhos.length == 1 ? p.tamanhos.first : _escolher('Tamanho', p.tamanhos, (t) => t);
    if (tamanho == null) return;

    final chave = '${p.id}|$cor|$tamanho';
    final naSacola = _sacola.itens.where((i) => i.chave == chave).fold(0, (s, i) => s + i.quantidade);
    final disponivel = min(estoque[chave] ?? 99, 99) - naSacola; // a API aceita até 99 por item
    if (disponivel < 1) return _p('Sem estoque disponível: ${p.nome} ($cor, $tamanho).');

    final quantidade = _lerInteiro('Quantidade (1 a $disponivel, 0 cancela)', 0, disponivel);
    if (quantidade == 0) return;
    _sacola.adicionar(p, cor: cor, tamanho: tamanho, quantidade: quantidade);
    _p('Adicionado: ${quantidade}x ${p.nome} ($cor, $tamanho).');
  }

  Future<void> _verSacola() async {
    if (_sacola.vazia) return _p('Sua sacola está vazia.');
    ItemSacola? item() => _escolher('Item', _sacola.itens, (i) => '${i.peca.nome} (${i.cor}, ${i.tamanho})');
    await _menu('Sacola', () => [
          ('Alterar quantidade', () async {
            final i = item();
            if (i == null) return;
            _sacola.alterarQuantidade(i, _lerInteiro('Nova quantidade (0 remove)', 0, 99) - i.quantidade);
          }),
          ('Remover item', () async {
            final i = item();
            if (i != null) _sacola.alterarQuantidade(i, -i.quantidade);
          }),
          ('Esvaziar sacola', () async {
            if (_confirmar('Tirar tudo da sacola?')) _sacola.limpar();
          }),
          ('Fechar pedido', _fecharPedido),
        ], ativo: () => !_sacola.vazia, cabecalho: () {
      for (final i in _sacola.itens) {
        _p(i.linhaPedido);
      }
      _p('Total: ${formatarReais(_sacola.total)}${_sacola.temPrecoPendente ? ' + a combinar' : ''}');
      _p('Entrega e pagamento você combina no WhatsApp.');
    });
  }

  static String _digitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _fecharPedido() async {
    if (_confirmar('Quer ler a privacidade e os termos?')) _privacidade();
    if (!_confirmar('Concorda em usar seus dados só para este pedido?')) {
      return _p('Pedido não enviado.');
    }
    final nome = _lerCampo('Nome', _obrigatorio);
    if (nome == null) return;
    final telefone = _lerCampo('Telefone com DDD', (v) {
      final n = _digitos(v).length;
      return n < 10 || n > 13 ? 'Telefone inválido.' : null;
    });
    if (telefone == null) return;
    final cpf = _lerCampo('CPF (opcional, Enter pula)', (v) {
      final n = _digitos(v).length;
      return n != 0 && n != 11 ? 'CPF deve ter 11 dígitos.' : null;
    });
    if (cpf == null) return;

    int? numero;
    try {
      numero = await Api.enviarPedido(_sacola,
          nome: nome, telefone: _digitos(telefone), cpf: cpf.isEmpty ? null : _digitos(cpf));
      _p('Pedido nº $numero registrado. Guarde esse número para acompanhar em "Meus pedidos".');
    } catch (e) {
      if (!_semConexao(e)) rethrow; // erro de regra (ex.: sem estoque) para aqui, como no app
      _p('Pedido não foi salvo (sem conexão). Segue só a mensagem para o WhatsApp.');
    }
    final mensagem = _sacola.mensagemPedido(numeroPedido: numero);
    _p();
    _p(mensagem.trimRight());
    _p();
    _p('Para enviar no WhatsApp, abra: ${_linkWhatsApp(mensagem)}');
    if (numero != null) _sacola.limpar(); // já virou pedido: não deixa fechar o mesmo duas vezes
  }

  Future<void> _meusPedidos() async {
    final id = _lerCampo('Número do pedido', (v) => int.tryParse(v) == null ? 'Número inválido.' : null);
    if (id == null) return;
    final telefone = _lerCampo('Telefone usado na compra', (v) => _digitos(v).length < 10 ? 'Telefone inválido.' : null);
    if (telefone == null) return;
    final p = await ApiAdmin.consultarPedido(int.parse(id), _digitos(telefone));
    final status = p['status'] as String;
    _p();
    _p('Pedido nº ${p['id']} - $status');
    if (!_statusFinal(status)) {
      final atual = _etapasPedido.indexOf(status);
      for (final (i, etapa) in _etapasPedido.indexed) {
        _p('  [${i <= atual ? 'x' : ' '}] $etapa');
      }
    }
    _imprimirItens(p);
    _p('Total: ${_dinheiro(p['total'])}${p['precoPendente'] == true ? ' + itens a combinar' : ''}');
  }

  void _imprimirItens(Map<String, dynamic> p) {
    for (final i in (p['itens'] as List).cast<Map<String, dynamic>>()) {
      _p('  ${i['quantidade']}x ${i['nome']} (${i['cor']}, ${i['tamanho']}) - '
          '${i['subtotal'] == null ? 'a combinar' : _dinheiro(i['subtotal'])}');
    }
  }

  Future<void> _resumoLoja() async {
    final pecas = await _carregarCatalogo();
    if (pecas.isEmpty) return _p('Nenhuma peça à venda agora.');
    final r = resumirCatalogo(pecas);
    _p();
    _p('${contar(r.total, 'peça', 'peças')} à venda');
    final faixa = faixaDePreco(r.menor, r.maior);
    if (faixa != null) _p('Preços: $faixa');
    if (r.aCombinar > 0) _p('${contar(r.aCombinar, 'peça', 'peças')} com preço a combinar');
    for (final c in r.categorias) {
      _p('  ${c.categoria.rotulo}: ${c.quantidade}');
    }
    if (r.tamanhos.isNotEmpty) _p('Tamanhos: ${emFrase(r.tamanhos)}');
    if (r.cores.isNotEmpty) _p('Cores: ${emFrase(r.cores)}');
  }

  Future<void> _contato() async {
    _p();
    _p('E-mail: $emailContato');
    _p('CNPJ: $cnpjLoja');
    if (!_confirmar('Quer escrever uma mensagem para o WhatsApp da loja?')) return;
    final nome = _lerCampo('Nome', _obrigatorio);
    if (nome == null) return;
    final email = _lerCampo('E-mail', (v) =>
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) ? null : 'Informe um e-mail válido.');
    if (email == null) return;
    final assunto = _lerCampo('Assunto', _obrigatorio);
    if (assunto == null) return;
    final mensagem = _lerCampo('Mensagem', _obrigatorio);
    if (mensagem == null) return;
    _p('Para enviar, abra: ${_linkWhatsApp('Olá, RV Label! Aqui é $nome ($email).\nAssunto: $assunto\n\n$mensagem')}');
  }

  void _privacidade() {
    for (final (titulo, texto) in blocosPrivacidade) {
      _p();
      _p(titulo);
      _p('  $texto');
    }
  }

  // ---- administração ----

  Future<void> _admin() async {
    if (!ApiAdmin.logado) {
      final email = _ler('E-mail');
      _saida.write('Senha: ');
      final senha = _lerLinhaOculta();
      if (senha == null) throw _FimDaEntrada();
      _p('Olá, ${await ApiAdmin.entrar(email, senha)}!');
    }
    await _menu('Administração', () => [
          ('Pedidos', _pedidosAdmin),
          ('Produtos', _produtosAdmin),
          ('Novo produto', _novoProduto),
          ('Apagar dados de demonstração', _apagarSimulados),
        ], sair: 'Sair da administração', ativo: () => ApiAdmin.logado);
    if (!ApiAdmin.logado) _p('A sessão expirou. Entre de novo.');
    ApiAdmin.sair();
  }

  String? _lerMes(String rotulo, String? atual) {
    final v = _lerCampo('$rotulo, AAAA-MM (Enter = sem limite)', (v) =>
        v.isEmpty || RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(v) ? null : 'Use o formato AAAA-MM.');
    if (v == null) return atual;
    return v.isEmpty ? null : v;
  }

  Future<void> _pedidosAdmin() async {
    String? de, ate; // sem período vêm os 200 mais recentes
    await _menu('Pedidos', () => [
          ('Listar pedidos', () => _listarPedidos(de, ate)),
          ('Mês inicial: ${de ?? 'sem limite'}', () async {
            de = _lerMes('Mês inicial', de);
            if (de != null && ate != null && ate!.compareTo(de!) < 0) ate = de;
          }),
          ('Mês final: ${ate ?? 'sem limite'}', () async {
            ate = _lerMes('Mês final', ate);
            if (de != null && ate != null && de!.compareTo(ate!) > 0) de = ate;
          }),
          ('Limpar período', () async => de = ate = null),
        ]);
  }

  Future<void> _listarPedidos(String? de, String? ate) async {
    while (true) {
      final lista = await ApiAdmin.pedidos(de: de, ate: ate);
      if (lista.isEmpty) return _p(de != null || ate != null ? 'Nenhum pedido no período.' : 'Nenhum pedido ainda.');
      final ind = IndicadoresVendas.calcular([
        for (final p in lista)
          if (!_statusFinal(p['status'])) (p['total'] as num).toDouble()
      ]);
      if (ind != null) {
        _p();
        _p('Indicadores (${ind.quantidade} pedidos): soma ${formatarReais(ind.soma)}, média ${formatarReais(ind.media)}, '
            'maior ${formatarReais(ind.maior)}, menor ${formatarReais(ind.menor)}');
      }
      final p = _escolher('Pedidos', lista, (p) =>
          '#${p['id']} ${p['cliente']} - ${p['status']} - ${_dinheiro(p['total'])}'
          '${p['precoPendente'] == true ? ' + a combinar' : ''}');
      if (p == null) return;
      _p();
      _p('Pedido #${p['id']} - ${p['cliente']} - telefone ${p['telefone']}');
      _imprimirItens(p);
      if (_statusFinal(p['status'])) {
        _p('Pedido ${(p['status'] as String).toLowerCase()}: não pode ser reaberto.');
        continue;
      }
      final status = _escolher('Novo status', _statusPedido, (s) => s == p['status'] ? '$s (atual)' : s,
          voltar: 'Manter');
      if (status == null || status == p['status']) continue;
      if (_statusFinal(status) &&
          !_confirmar('O estoque será devolvido e o pedido não poderá ser reaberto. Marcar como $status?')) {
        continue;
      }
      await ApiAdmin.mudarStatus(p['id'] as int, status);
      _p('Status alterado para $status.');
    }
  }

  Future<void> _produtosAdmin() async {
    var todos = await ApiAdmin.produtos();
    var busca = '';
    bool? naLoja; // null = todos
    String? categoria;

    List<Map<String, dynamic>> visiveis() => [
          for (final p in todos)
            if ('${p['nome']} ${p['codigo']}'.toLowerCase().contains(busca.toLowerCase()) &&
                (naLoja == null || (p['ativo'] == true) == naLoja) &&
                (categoria == null || p['categoria'] == categoria))
              p,
        ];
    String rotulo(Map<String, dynamic> p) =>
        '${p['nome']} [${p['codigo']}] - ${p['preco'] == null ? 'Preço a definir' : _dinheiro(p['preco'])}'
        '${p['ativo'] == true ? '' : ' (desativado)'}';

    await _menu('Produtos', () => [
          ('Ver ${contar(visiveis().length, 'produto', 'produtos')}', () async {
            if (visiveis().isEmpty) return _p('Nenhum produto encontrado.');
            final p = _escolher('Produtos', visiveis(), rotulo);
            if (p == null) return;
            await _editarProduto(p);
            todos = await ApiAdmin.produtos();
          }),
          ('Busca: ${busca.isEmpty ? 'nenhuma' : busca}', () async {
            busca = _ler('Nome ou código (Enter limpa)');
          }),
          ('Situação: ${naLoja == null ? 'todos' : naLoja! ? 'na loja' : 'desativados'}', () async {
            naLoja = _escolher('Situação', [true, false], (v) => v ? 'Na loja' : 'Desativados', voltar: 'Todos');
          }),
          ('Categoria: ${categoria ?? 'todas'}', () async {
            final nomes = {for (final p in todos) p['categoria']}.whereType<String>().toList()..sort();
            categoria = _escolher('Categoria', nomes, (c) => c, voltar: 'Todas');
          }),
          ('Ativar ou desativar vários', () async {
            await _lote(visiveis(), rotulo);
            todos = await ApiAdmin.produtos();
          }),
        ]);
  }

  Future<void> _lote(List<Map<String, dynamic>> lista, String Function(Map<String, dynamic>) rotulo) async {
    if (lista.isEmpty) return _p('Nenhum produto encontrado.');
    _p();
    for (final (i, p) in lista.indexed) {
      _p('${i + 1}. ${rotulo(p)}');
    }
    final marcados = _lerCampo('Números separados por vírgula, ou "todos"', (v) {
      if (v.toLowerCase() == 'todos') return null;
      final ns = v.split(',').map((s) => int.tryParse(s.trim()));
      return v.isEmpty || ns.any((n) => n == null || n < 1 || n > lista.length) ? 'Lista inválida.' : null;
    });
    if (marcados == null) return;
    final codigos = marcados.toLowerCase() == 'todos'
        ? {for (final p in lista) p['codigo'] as String}
        : {for (final s in marcados.split(',')) lista[int.parse(s.trim()) - 1]['codigo'] as String};
    final ativar = _escolher('O que fazer com ${contar(codigos.length, 'produto', 'produtos')}?', [true, false],
        (v) => v ? 'Ativar' : 'Desativar');
    if (ativar == null) return;
    final r = await aplicarAtivo(
      produtos: lista,
      codigos: codigos,
      ativo: ativar,
      alterar: (codigo, v) => ApiAdmin.alterarProduto(codigo, {'ativo': v}),
    );
    _p(resumoDoLote(r, ativo: ativar));
  }

  Future<void> _editarProduto(Map<String, dynamic> inicial) async {
    var p = inicial;
    final codigo = p['codigo'] as String;
    Future<void> recarregar() async {
      p = (await ApiAdmin.produtos()).firstWhere((x) => x['codigo'] == codigo);
    }

    Future<void> alterarValor(String campo, String rotulo) async {
      final v = _lerValor('$rotulo em R\$ (Enter = sem valor)');
      if (v == null) return;
      await ApiAdmin.alterarProduto(codigo, {campo: v.valor});
      await recarregar();
    }

    await _menu(p['nome'] as String, () => [
          (p['ativo'] == true ? 'Tirar da loja' : 'Colocar na loja', () async {
            await ApiAdmin.alterarProduto(codigo, {'ativo': p['ativo'] != true});
            await recarregar();
          }),
          ('Alterar preço', () => alterarValor('preco', 'Preço')),
          ('Alterar custo', () => alterarValor('custo', 'Custo')),
          ('Alterar estoque', () async {
            final variacoes = (p['variacoes'] as List).cast<Map<String, dynamic>>();
            final v = _escolher('Variação', variacoes, (v) =>
                '${v['cor']} / ${v['tamanho']}: ${v['estoque'] ?? 'sem controle'}'
                '${v['estoque'] is num && (v['estoque'] as num) <= 2 ? ' (baixo)' : ''}');
            if (v == null) return;
            final q = _lerCampo('Quantidade (Enter = sem controle)', (t) {
              if (t.isEmpty) return null;
              final n = int.tryParse(t);
              return n == null || n < 0 ? 'Quantidade inválida.' : null;
            });
            if (q == null) return;
            await ApiAdmin.definirEstoque(codigo, v['cor'] as String, v['tamanho'] as String,
                q.isEmpty ? null : int.parse(q));
            await recarregar();
          }),
        ], cabecalho: () {
      _p('${p['codigo']} - ${p['categoria']} - ${p['ativo'] == true ? 'na loja' : 'desativado'}');
      _p('Preço: ${p['preco'] == null ? 'a definir' : _dinheiro(p['preco'])}');
      _p('Custo: ${p['custo'] == null ? 'não informado' : _dinheiro(p['custo'])}');
      for (final v in (p['variacoes'] as List).cast<Map<String, dynamic>>()) {
        _p('  ${v['cor']} / ${v['tamanho']}: ${v['estoque'] ?? 'sem controle'}');
      }
    });
  }

  List<String> _fotosDisponiveis() {
    final pasta = Directory('assets/fotos');
    if (!pasta.existsSync()) return const [];
    return [
      for (final f in pasta.listSync().whereType<File>())
        if (RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false).hasMatch(f.path))
          'assets/fotos/${f.uri.pathSegments.last}',
    ]..sort();
  }

  Future<void> _novoProduto() async {
    final fotos = _fotosDisponiveis();
    if (fotos.isEmpty) return _p('Nenhuma foto em assets/fotos. Rode o comando na raiz do projeto.');
    final codigo = _lerCampo('Código (ex.: essence-020)', (v) =>
        RegExp(r'^[a-z0-9-]{3,40}$').hasMatch(v) ? null : 'Use letras minúsculas, números e hífen.');
    if (codigo == null) return;
    final nome = _lerCampo('Nome', _obrigatorio);
    if (nome == null) return;
    final categoria = _escolher('Categoria', Categoria.values, (c) => c.rotulo, voltar: 'Cancelar');
    if (categoria == null) return;
    final acessorio = categoria == Categoria.acessorios;
    final descricao = _lerCampo('Descrição (opcional)', (_) => null);
    if (descricao == null) return;
    final preco = _lerValor('Preço em R\$ (Enter = a combinar)');
    if (preco == null) return;
    final material = _lerCampo('Material (opcional)', (_) => null);
    if (material == null) return;
    final tamanhos = acessorio ? '' : _lerCampo('Tamanhos separados por vírgula (ex.: P,M,G; Enter = Único)', (_) => null);
    if (tamanhos == null) return;

    final cores = <Map<String, dynamic>>[];
    do {
      final cor = _lerCampo('Nome da cor ${cores.length + 1}', _obrigatorio);
      if (cor == null) return;
      final frente = _escolher('Foto da frente', fotos, (f) => f.split('/').last, voltar: 'Cancelar');
      if (frente == null) return;
      final costas = _escolher('Foto das costas', fotos, (f) => f.split('/').last, voltar: 'Nenhuma');
      final tom = _lerCampo('Tom para recolorir (opcional, ex.: #8B1A2B)', (v) =>
          v.isEmpty || RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v) ? null : 'Use o formato #RRGGBB.');
      if (tom == null) return;
      cores.add({
        'nome': cor,
        'fotoFrente': frente,
        if (costas != null) 'fotoCostas': costas,
        if (tom.isNotEmpty) 'tom': tom,
      });
    } while (_confirmar('Adicionar outra cor?'));

    await ApiAdmin.criarProduto({
      'codigo': codigo,
      'nome': nome,
      'categoria': categoria.name,
      if (acessorio) 'tipo': 'acessorio',
      'descricao': descricao,
      if (preco.valor != null) 'preco': preco.valor,
      if (material.isNotEmpty) 'material': material,
      'cores': cores,
      if (tamanhos.isNotEmpty)
        'tamanhos': [for (final t in tamanhos.split(',')) if (t.trim().isNotEmpty) t.trim().toUpperCase()],
    });
    _p('Produto cadastrado: $nome. O estoque de cada variação começa sem controle.');
  }

  Future<void> _apagarSimulados() async {
    _p('Saem todos os pedidos, clientes, vendedoras, metas e estoque mensal simulados (os do dashboard).');
    _p('Os pedidos reais continuam. Não dá para desfazer.');
    if (_ler('Para confirmar, digite APAGAR') != 'APAGAR') return _p('Nada foi apagado.');
    _p('${await ApiAdmin.apagarSimulados()} pedidos de demonstração apagados.');
  }
}
