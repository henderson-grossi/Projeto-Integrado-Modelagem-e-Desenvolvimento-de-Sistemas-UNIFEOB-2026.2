import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api.dart';

/// Chamadas da área administrativa e da consulta de pedido.
/// O token fica só em memória: fechar o app encerra a sessão.
class ApiAdmin {
  static String? _token;
  static const _timeout = Duration(seconds: 8);

  static bool get logado => _token != null;
  static void sair() => _token = null;

  static Future<dynamic> _chamar(String metodo, String caminho,
      {Map<String, dynamic>? corpo, bool auth = true}) async {
    final req = http.Request(metodo, Uri.parse('${Api.baseUrl}$caminho'))
      ..headers['Content-Type'] = 'application/json';
    if (auth && _token != null) req.headers['Authorization'] = 'Bearer $_token';
    if (corpo != null) req.body = jsonEncode(corpo);
    final r = await http.Response.fromStream(await req.send().timeout(_timeout));
    final json = r.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode == 401 && auth) _token = null; // sessão expirou
    if (r.statusCode >= 400) {
      throw ApiErro((json is Map ? json['erro'] as String? : null) ?? 'Erro ${r.statusCode}');
    }
    return json;
  }

  static Future<String> entrar(String email, String senha) async {
    final j = await _chamar('POST', '/admin/login',
        corpo: {'email': email, 'senha': senha}, auth: false);
    _token = j['token'] as String;
    return j['nome'] as String;
  }

  static Future<List<Map<String, dynamic>>> produtos() async =>
      ((await _chamar('GET', '/admin/produtos')) as List).cast<Map<String, dynamic>>();

  static Future<void> criarProduto(Map<String, dynamic> dados) =>
      _chamar('POST', '/admin/produtos', corpo: dados);

  static Future<void> alterarProduto(String codigo, Map<String, dynamic> campos) =>
      _chamar('PATCH', '/admin/produtos/$codigo', corpo: campos);

  static Future<void> definirEstoque(String codigo, String cor, String tamanho, int? quantidade) =>
      _chamar('PUT', '/admin/estoque',
          corpo: {'codigo': codigo, 'cor': cor, 'tamanho': tamanho, 'quantidade': quantidade});

  /// [de] e [ate] no formato 'AAAA-MM' (os dois meses entram); sem período vêm os 200 mais recentes.
  static Future<List<Map<String, dynamic>>> pedidos({String? de, String? ate}) async {
    final q = {if (de != null) 'de': de, if (ate != null) 'ate': ate};
    final caminho = q.isEmpty ? '/admin/pedidos' : '/admin/pedidos?${Uri(queryParameters: q).query}';
    return ((await _chamar('GET', caminho)) as List).cast<Map<String, dynamic>>();
  }

  /// Apaga todos os dados de demonstração do dashboard. Devolve quantos pedidos saíram.
  static Future<int> apagarSimulados() async =>
      ((await _chamar('DELETE', '/admin/simulados')) as Map)['pedidos'] as int;

  static Future<void> mudarStatus(int id, String status) =>
      _chamar('PATCH', '/admin/pedidos/$id', corpo: {'status': status});

  /// Consulta pública: exige o número do pedido e o telefone usado nele.
  static Future<Map<String, dynamic>> consultarPedido(int id, String telefone) async =>
      (await _chamar('GET', '/pedidos/$id?telefone=${Uri.encodeQueryComponent(telefone)}',
          auth: false)) as Map<String, dynamic>;
}
