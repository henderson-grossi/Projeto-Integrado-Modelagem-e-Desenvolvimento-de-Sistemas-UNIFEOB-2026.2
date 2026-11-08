import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sacola_base.dart';

/// Cliente HTTP da API (pasta api/), que conversa com o MySQL Rv_Label.
/// Troque o endereço com: flutter run --dart-define=API_URL=http://10.0.2.2:3000
/// (10.0.2.2 = o PC, visto de dentro do emulador Android).
class Api {
  static const baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');
  static const _timeout = Duration(seconds: 6);

  /// Catálogo no mesmo formato do assets/catalogo.json.
  static Future<Map<String, dynamic>> produtos() async {
    final r = await http.get(Uri.parse('$baseUrl/produtos')).timeout(_timeout);
    if (r.statusCode != 200) throw Exception('API respondeu ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// Variações com controle de estoque: `produto_id`, `cor`, `tamanho`, `quantidade`.
  static Future<List<Map<String, dynamic>>> estoque() async {
    final r = await http.get(Uri.parse('$baseUrl/estoque')).timeout(_timeout);
    if (r.statusCode != 200) throw Exception('API respondeu ${r.statusCode}');
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List).cast<Map<String, dynamic>>();
  }

  /// Grava o pedido e devolve o número. Lança [ApiErro] com a mensagem do servidor.
  static Future<int> enviarPedido(
    SacolaBase sacola, {
    required String nome,
    required String telefone,
    String? cpf,
  }) async {
    final r = await http
        .post(
          Uri.parse('$baseUrl/pedidos'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'comprador': {'nome': nome, 'telefone': telefone, 'cpf': cpf},
            'itens': [
              for (final i in sacola.itens)
                {
                  'produtoId': i.peca.id,
                  'cor': i.cor,
                  'tamanho': i.tamanho,
                  'quantidade': i.quantidade,
                }
            ],
          }),
        )
        .timeout(_timeout);
    final corpo = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (r.statusCode != 201) {
      throw ApiErro(corpo['erro'] as String? ?? 'Erro ${r.statusCode}');
    }
    return corpo['id'] as int;
  }
}

class ApiErro implements Exception {
  ApiErro(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}
