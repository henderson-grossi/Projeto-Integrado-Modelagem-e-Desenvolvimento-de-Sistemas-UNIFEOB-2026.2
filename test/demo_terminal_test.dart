import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rvlabel_app/models/models.dart';
import 'package:rvlabel_app/services/sacola.dart';

import '../tool/demo_terminal.dart' as demo;

void main() {
  test('modelos e regras da sacola não dependem de Flutter (a demo roda com dart run)', () {
    final arquivos = [
      ...Directory('lib/models').listSync().whereType<File>(),
      File('lib/core/moeda.dart'),
      File('lib/services/sacola_base.dart'),
    ];
    for (final f in arquivos) {
      expect(f.readAsStringSync(), isNot(contains('package:flutter')), reason: f.path);
    }
  });

  test('demo de terminal: validações barram e o pedido sai certo', () {
    final saida = StringBuffer();
    runZoned(() => demo.main(['--sem-cor']),
        zoneSpecification: ZoneSpecification(print: (_, __, ___, linha) => saida.writeln(linha)));
    final texto = saida.toString();
    expect(texto, isNot(contains('ACEITOU')));
    expect('BLOQUEADO'.allMatches(texto).length, 7);
    expect(texto, contains('Total: R\$ 219,70 + itens a combinar'));
  });

  test('Sacola avisa a tela a cada mudança', () {
    final s = Sacola();
    var avisos = 0;
    s.addListener(() => avisos++);
    final p = Peca(id: '1', nome: 'Blusa', categoria: Categoria.blusas, preco: 10);
    s.adicionar(p, cor: 'Preto', tamanho: 'M');
    s.alterarQuantidade(s.itens.first, 1);
    s.limpar();
    expect(avisos, 3);
  });
}
