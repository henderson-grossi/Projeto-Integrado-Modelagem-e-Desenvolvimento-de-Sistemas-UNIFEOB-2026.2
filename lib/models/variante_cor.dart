/// Uma cor disponível para a peça. A foto original é reaproveitada e
/// recolorida por filtro, então novas cores = só uma linha no catalogo.json.
///
/// - [hue]: gira o matiz em graus (bom para peças já coloridas).
/// - [tom]: cor ARGB aplicada com BlendMode.color (funciona também em
///   peças pretas, brancas ou cinza, onde girar o matiz não muda nada).
///
/// Dart puro (sem Flutter), para rodar também na demo de terminal. O filtro
/// que recolore a foto fica na UI (extensão em ui/componentes.dart).
class VarianteCor {
  const VarianteCor({required this.nome, this.hue = 0, this.tom});

  final String nome;
  final double hue;
  final int? tom;

  factory VarianteCor.fromJson(Map<String, dynamic> json) {
    final hex = json['tom'] as String?;
    return VarianteCor(
      nome: json['nome'] as String,
      hue: (json['hue'] as num?)?.toDouble() ?? 0,
      tom: hex == null
          ? null
          : int.parse('FF${hex.replaceFirst('#', '')}', radix: 16),
    );
  }

  bool get ehOriginal => hue == 0 && tom == null;
}
