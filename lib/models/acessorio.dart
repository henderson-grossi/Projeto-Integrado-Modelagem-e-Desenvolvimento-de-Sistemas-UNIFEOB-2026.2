import 'produto.dart';

/// Acessório: HERDA de [Produto]; tamanho único e material opcional.
class Acessorio extends Produto {
  Acessorio({
    required super.id,
    required super.nome,
    required super.categoria,
    super.descricao,
    super.preco,
    super.fotos,
    super.cores,
    this.material,
  });

  final String? material;

  @override
  List<String> get tamanhos => const ['Único'];

  @override
  String get rotuloTipo => 'Acessório';

  @override
  String get resumo =>
      material == null ? super.resumo : '${super.resumo} · $material';

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'tipo': 'acessorio',
        'material': material,
      };
}
