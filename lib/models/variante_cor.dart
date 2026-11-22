import 'serializavel.dart';

/// Uma cor disponível para a peça. A foto original é reaproveitada e
/// recolorida por filtro, então novas cores = só uma linha no catalogo.json.
///
/// - [hue]: gira o matiz em graus (bom para peças já coloridas).
/// - [tom]: cor ARGB aplicada com BlendMode.color (funciona também em
///   peças pretas, brancas ou cinza, onde girar o matiz não muda nada).
///
/// Dart puro (sem Flutter), para rodar também na demo de terminal. O filtro
/// que recolore a foto fica na UI (extensão em ui/componentes.dart).
class VarianteCor with Serializavel {
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

  /// Inverso do [VarianteCor.fromJson]: o tom volta para "#RRGGBB".
  @override
  Map<String, dynamic> toMap() => {
        'nome': nome,
        'hue': hue,
        'tom': tom == null
            ? null
            : '#${(tom! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      };

  bool get ehOriginal => hue == 0 && tom == null;
}
