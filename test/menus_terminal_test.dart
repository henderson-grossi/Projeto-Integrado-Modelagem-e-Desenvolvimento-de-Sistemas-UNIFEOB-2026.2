import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../tool/menus_terminal.dart';

const _catalogo = {
  'pecas': [
    {
      'id': 'essence-1',
      'nome': 'Blusa Essence',
      'categoria': 'blusas',
      'preco': 50,
      'cores': [
        {'nome': 'Preto'},
        {'nome': 'Vinho'},
      ],
      'tamanhos': ['P', 'M'],
    },
  ],
};

http.Response _json(Object corpo, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(corpo)), status,
    headers: {'content-type': 'application/json'});

/// Roda os menus digitando [entradas] e devolve o que apareceu na tela. Depois das entradas vem o fim da entrada.
Future<String> _rodar(List<String> entradas, Future<http.Response> Function(http.Request) api) async {
  final tela = StringBuffer();
  final fila = entradas.iterator;
  await http.runWithClient(
    () => MenusTerminal(ler: () => fila.moveNext() ? fila.current : null, saida: tela).rodar(),
    () => MockClient(api),
  );
  return tela.toString();
}

void main() {
  test('fim da entrada encerra em vez de perguntar para sempre', () async {
    final tela = await _rodar([], (_) async => _json({}));
    expect(tela, contains('Administração'));
    expect(tela, contains('Cliente (loja)'));
    expect(tela, contains('Até logo!'));
  });

  test('cliente escolhe variação, respeita o estoque e fecha o pedido', () async {
    Map<String, dynamic>? pedido;
    final tela = await _rodar([
      '2', // cliente
      '1', '1', '1', // produtos, ver peças, a primeira
      '1', '1', '2', // adicionar, Preto, M
      '5', '1', // só tem 1 em estoque: 5 é recusado
      '1', '1', '2', // tentar de novo a mesma variação: não sobrou nenhuma
      '0', '0', '0', // volta até o menu do cliente
      '2', '4', // sacola, fechar pedido
      'n', 's', 'Ana', '(35) 99999-0000', '', // termos, consentimento, dados
    ], (r) async {
      if (r.url.path == '/produtos') return _json(_catalogo);
      if (r.url.path == '/estoque') {
        return _json([
          {'produto_id': 'essence-1', 'cor': 'Preto', 'tamanho': 'M', 'quantidade': 1},
        ]);
      }
      expect('${r.method} ${r.url.path}', 'POST /pedidos');
      pedido = jsonDecode(r.body) as Map<String, dynamic>;
      return _json({'id': 77}, 201);
    });

    expect(tela, contains('Preto: P, M (1)'));
    expect(tela, contains('Digite um número de 0 a 1.'));
    expect(tela, contains('Sem estoque disponível: Blusa Essence (Preto, M).'));
    expect(tela, contains('Pedido nº 77 registrado.'));
    expect(pedido!['comprador'], {'nome': 'Ana', 'telefone': '35999990000', 'cpf': null});
    expect(pedido!['itens'], [
      {'produtoId': 'essence-1', 'cor': 'Preto', 'tamanho': 'M', 'quantidade': 1},
    ]);
  });

  test('admin entra e cancelar pedido pede confirmação', () async {
    String? statusEnviado;
    var cabecalhoToken = '';
    final tela = await _rodar([
      '1', 'admin@teste.local', 'segredo', // administração e login
      '1', '1', '1', // pedidos, listar, o primeiro
      '6', 's', // Cancelado, confirma
    ], (r) async {
      if (r.url.path == '/admin/login') return _json({'token': 'tk', 'nome': 'Dona'});
      if (r.method == 'PATCH') {
        cabecalhoToken = r.headers['Authorization'] ?? '';
        statusEnviado = (jsonDecode(r.body) as Map)['status'] as String;
        return _json({'ok': true});
      }
      return _json([
        {
          'id': 9,
          'cliente': 'Ana',
          'telefone': '35999990000',
          'status': statusEnviado ?? 'Recebido',
          'total': 50,
          'precoPendente': false,
          'itens': [],
        },
      ]);
    });

    expect(tela, contains('Olá, Dona!'));
    expect(tela, contains('Indicadores (1 pedidos)'));
    expect(statusEnviado, 'Cancelado');
    expect(cabecalhoToken, 'Bearer tk');
  });

  test('senha errada mostra o erro da API e volta ao menu', () async {
    final tela = await _rodar(['1', 'a@b.c', 'errada'],
        (_) async => _json({'erro': 'E-mail ou senha incorretos.'}, 401));
    expect(tela, contains('Erro: E-mail ou senha incorretos.'));
    expect(tela, contains('Até logo!'));
  });
}
