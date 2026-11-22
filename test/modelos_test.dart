import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rvlabel_app/models/models.dart';
import 'package:rvlabel_app/services/sacola.dart';

void main() {
  test('herança e polimorfismo', () {
    final Produto a = Peca(id: '1', nome: 'Blusa', categoria: Categoria.blusas);
    final Produto b =
        Acessorio(id: '2', nome: 'Bolsa', categoria: Categoria.acessorios, material: 'couro');
    expect(a.tamanhos, ['P', 'M', 'G']);
    expect(b.tamanhos, ['Único']);
    expect(b.resumo, contains('couro'));
  });

  test('setters validam', () {
    final p = Peca(id: '1', nome: 'Blusa', categoria: Categoria.blusas);
    p.preco = 89.9;
    expect(p.precoFormatado, 'R\$ 89,90');
    expect(() => p.preco = -1, throwsArgumentError);
    expect(() => p.nome = '  ', throwsArgumentError);
  });

  test('toMap/toJson fazem ida e volta pelo fromJson', () {
    final pecas = <Produto>[
      Peca(
          id: '1',
          nome: 'Blusa',
          categoria: Categoria.blusas,
          preco: 89.9,
          tamanhos: const ['P', 'M'],
          cores: const [VarianteCor(nome: 'Preto'), VarianteCor(nome: 'Rosa', tom: 0xFFE91E63)]),
      Acessorio(id: '2', nome: 'Bolsa', categoria: Categoria.acessorios, material: 'couro'),
    ];
    for (final p in pecas) {
      final volta = Produto.fromJson(jsonDecode(p.toJson()) as Map<String, dynamic>);
      expect(volta.runtimeType, p.runtimeType);
      expect(volta.toMap(), p.toMap());
    }
    expect(pecas.first.toMap()['cores'][1]['tom'], '#E91E63');

    final s = Sacola()..adicionar(pecas.first, cor: 'Preto', tamanho: 'M', quantidade: 2);
    final mapa = jsonDecode(s.toJson()) as Map<String, dynamic>;
    expect(mapa['itens'], hasLength(1));
    expect(mapa['itens'][0]['subtotal'], closeTo(179.8, 1e-9));
  });

  test('sacola soma e remove', () {
    final s = Sacola();
    final p = Peca(id: '1', nome: 'Blusa', categoria: Categoria.blusas, preco: 100);
    s.adicionar(p, cor: 'Preto', tamanho: 'M');
    s.adicionar(p, cor: 'Preto', tamanho: 'M');
    expect(s.total, 200);
    s.alterarQuantidade(s.itens.first, -2);
    expect(s.vazia, isTrue);
  });
}
