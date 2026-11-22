import 'dart:convert';

/// Contrato (interface) de quem pode ser convertido para Map e JSON.
///
/// Quem usa `with Serializavel` é OBRIGADO a implementar [toMap] e GANHA
/// [toJson] pronto: o contrato vem junto com o código reaproveitado.
mixin Serializavel {
  Map<String, dynamic> toMap();

  String toJson() => jsonEncode(toMap());
}
