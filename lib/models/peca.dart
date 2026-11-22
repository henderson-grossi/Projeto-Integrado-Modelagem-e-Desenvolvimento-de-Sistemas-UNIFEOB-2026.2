import 'produto.dart';

/// Peça de roupa: HERDA de [Produto] e acrescenta tamanhos e foto de costas.
class Peca extends Produto {
  Peca({
    required super.id,
    required super.nome,
    required super.categoria,
    super.descricao,
    super.preco,
    super.fotos,
    super.cores,
    List<String> tamanhos = const ['P', 'M', 'G'],
    this.fotoCostas,
  }) : _tamanhos = List.unmodifiable(tamanhos);

  final List<String> _tamanhos;
  final String? fotoCostas;

  @override
  List<String> get tamanhos => _tamanhos;

  @override
  String get rotuloTipo => 'Peça';

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'tipo': 'peca',
        'tamanhos': _tamanhos,
        'fotoCostas': fotoCostas,
      };
}
