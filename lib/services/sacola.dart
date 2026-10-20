import 'package:flutter/foundation.dart';

import 'sacola_base.dart';

/// Estado da sacola de compras (observável pela UI).
/// As regras (total, quantidade, mensagem do pedido) ficam em [SacolaBase],
/// em Dart puro; aqui só se avisa a tela a cada mudança.
class Sacola extends SacolaBase with ChangeNotifier {
  @override
  void aoMudar() => notifyListeners();
}
