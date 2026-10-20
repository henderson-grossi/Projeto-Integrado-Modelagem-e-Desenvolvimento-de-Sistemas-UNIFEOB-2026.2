import '../core/moeda.dart';
import '../models/models.dart';

/// Regras da sacola de compras em Dart puro (sem Flutter): o app usa pela
/// [Sacola], que só acrescenta o aviso à tela, e a demo de terminal usa direto.
/// O mapa interno é privado: quem usa só enxerga getters e métodos.
class SacolaBase {
  final Map<String, ItemSacola> _itens = {};

  List<ItemSacola> get itens => List.unmodifiable(_itens.values);
  int get quantidadeTotal =>
      _itens.values.fold(0, (soma, i) => soma + i.quantidade);
  bool get vazia => _itens.isEmpty;

  double get total =>
      _itens.values.fold(0.0, (soma, i) => soma + (i.subtotal ?? 0));
  bool get temPrecoPendente => _itens.values.any((i) => i.subtotal == null);

  /// Chamado depois de cada mudança. A [Sacola] do app avisa a tela daqui.
  void aoMudar() {}

  void adicionar(Produto produto,
      {required String cor, required String tamanho, int quantidade = 1}) {
    final novo = ItemSacola(
        peca: produto, cor: cor, tamanho: tamanho, quantidade: quantidade);
    final existente = _itens[novo.chave];
    if (existente != null) {
      existente.quantidade += quantidade;
    } else {
      _itens[novo.chave] = novo;
    }
    aoMudar();
  }

  void alterarQuantidade(ItemSacola item, int delta) {
    final nova = item.quantidade + delta;
    if (nova < 1) {
      _itens.remove(item.chave);
    } else {
      item.quantidade = nova; // passa pelo setter validado
    }
    aoMudar();
  }

  void limpar() {
    _itens.clear();
    aoMudar();
  }

  /// Texto enviado no "Fechar pedido pelo WhatsApp".
  String mensagemPedido({int? numeroPedido}) {
    final b = StringBuffer('Olá, RV Label! Quero fechar este pedido'
        '${numeroPedido == null ? '' : ' (nº $numeroPedido)'}:\n\n');
    for (final i in _itens.values) {
      b.writeln(i.linhaPedido);
    }
    b.writeln('\nTotal: ${formatarReais(total)}'
        '${temPrecoPendente ? ' + itens a combinar' : ''}');
    return b.toString();
  }
}
