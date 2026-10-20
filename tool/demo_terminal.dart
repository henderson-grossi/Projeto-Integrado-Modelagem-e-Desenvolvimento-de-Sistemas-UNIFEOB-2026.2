// Demonstração no terminal: encapsulamento, getters/setters, validações e
// regras de negócio das classes reais do app, sem abrir a interface Flutter.
//
//   dart run tool/demo_terminal.dart            (com cores)
//   dart run tool/demo_terminal.dart --sem-cor  (sem cores ANSI)
//
// Só importa arquivos em Dart puro (lib/models, lib/core/moeda.dart e
// lib/services/sacola_base.dart); por isso roda com o `dart`, sem Flutter.

// A demo existe para escrever no console.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:rvlabel_app/core/moeda.dart';
import 'package:rvlabel_app/models/models.dart';
import 'package:rvlabel_app/services/sacola_base.dart';

var _comCor = false;
var _passo = 0;

String _pinta(String codigo, String texto) =>
    _comCor ? '\x1B[${codigo}m$texto\x1B[0m' : texto;

void _etapa(String titulo) {
  _passo++;
  print('');
  print(_pinta('1;31', '[$_passo] $titulo'));
  print(_pinta('2', '-' * 64));
}

void _mostra(String rotulo, Object? valor) =>
    print('  ${rotulo.padRight(26)} $valor');

void _nota(String texto) => print(_pinta('2', '  $texto'));

/// Roda [acao] esperando que a validação barre, e mostra a mensagem dela.
void _tenta(String descricao, void Function() acao) {
  try {
    acao();
    print('  ${_pinta('1;33', 'ACEITOU (não devia)')} $descricao');
  } on ArgumentError catch (e) {
    print('  ${_pinta('32', 'BLOQUEADO')} $descricao');
    print('            -> ${e.message}');
  } on UnsupportedError {
    print('  ${_pinta('32', 'BLOQUEADO')} $descricao');
    print('            -> a lista é só de leitura');
  }
}

void main(List<String> args) {
  // cmd e PowerShell do Windows 10+ entendem cores ANSI; NO_COLOR ou --sem-cor desligam.
  _comCor = stdout.hasTerminal &&
      stdout.supportsAnsiEscapes &&
      !args.contains('--sem-cor') &&
      !Platform.environment.containsKey('NO_COLOR');
  _passo = 0;

  print(_pinta('1', 'RV Label - demonstração no terminal'));
  print('Encapsulamento, getters/setters, validações e regras de negócio');
  print('com as classes reais do app (lib/models e lib/services/sacola_base.dart).');

  _etapa('Criando as peças');
  final blusa = Peca(
    id: 'blusa-essence',
    nome: 'Blusa Essence',
    categoria: Categoria.blusas,
    preco: 89.9,
    cores: const [VarianteCor(nome: 'Preto'), VarianteCor(nome: 'Vinho', hue: 20)],
  );
  final vestido = Peca(
    id: 'vestido-midi',
    nome: 'Vestido Midi',
    categoria: Categoria.vestidos,
    tamanhos: const ['P', 'M'],
  ); // sem preço: "preço a definir"
  final bolsa = Acessorio(
    id: 'bolsa-mini',
    nome: 'Bolsa Mini',
    categoria: Categoria.acessorios,
    preco: 59.9,
    material: 'couro sintético',
  );
  final pecas = <Produto>[blusa, vestido, bolsa];
  for (final p in pecas) {
    print('  criado: ${p.nome} (${p.rotuloTipo})');
  }

  _etapa('Lendo os dados pelos getters');
  for (final p in pecas) {
    print('  ${p.nome}');
    _mostra('  preco', p.preco);
    _mostra('  precoFormatado', p.precoFormatado);
    _mostra('  tamanhos', p.tamanhos.join(', '));
    _mostra('  cores', p.cores.map((c) => c.nome).join(', '));
    _mostra('  resumo', p.resumo);
  }
  _nota('_nome e _preco são privados: de fora da classe só se lê pelo getter.');
  _nota('tamanhos e resumo são polimórficos: Peca e Acessorio respondem diferente.');

  _etapa('Alterando pelos setters (valores válidos)');
  blusa.preco = 79.9;
  _mostra('blusa.preco = 79.9', blusa.precoFormatado);
  blusa.nome = '   Blusa Essence Gola V   ';
  _mostra("blusa.nome = '   ...   '", '"${blusa.nome}" (o setter tira os espaços)');

  _etapa('Tentando valores inválidos (a validação barra)');
  _tenta('blusa.preco = -10', () => blusa.preco = -10);
  _tenta("blusa.nome = '   '", () => blusa.nome = '   ');
  _tenta('Peca(..., preco: -5)',
      () => Peca(id: 'x', nome: 'Top', categoria: Categoria.tops, preco: -5));
  _tenta("Peca(..., nome: '')",
      () => Peca(id: 'x', nome: '', categoria: Categoria.tops));
  final item = ItemSacola(peca: blusa, cor: 'Preto', tamanho: 'M');
  _tenta('itemSacola.quantidade = 0', () => item.quantidade = 0);
  _tenta("blusa.tamanhos.add('GG')", () => blusa.tamanhos.add('GG'));
  _nota('Nada mudou: ${blusa.nome}, ${blusa.precoFormatado}, '
      'tamanhos ${blusa.tamanhos.join('/')}, quantidade ${item.quantidade}.');

  _etapa('Montando a sacola');
  final sacola = SacolaBase();
  sacola.adicionar(blusa, cor: 'Preto', tamanho: 'M', quantidade: 2);
  print('  + 2x ${blusa.nome} (Preto, M)');
  sacola.adicionar(blusa, cor: 'Preto', tamanho: 'M');
  print('  + 1x ${blusa.nome} (Preto, M)  -> mesma peça, cor e tamanho: soma no item');
  sacola.adicionar(bolsa, cor: 'Única', tamanho: 'Único');
  print('  + 1x ${bolsa.nome} (Única, Único)');
  sacola.adicionar(vestido, cor: 'Única', tamanho: 'P');
  print('  + 1x ${vestido.nome} (Única, P)  -> preço a definir');
  _tenta('sacola.itens.add(...) por fora', () => sacola.itens.add(item));
  _nota('O mapa _itens é privado: só muda por adicionar, alterarQuantidade e limpar.');

  void calculos() {
    for (final i in sacola.itens) {
      _mostra('  ${i.quantidade}x ${i.peca.nome}',
          i.subtotal == null ? 'preço a combinar' : formatarReais(i.subtotal!));
    }
    _mostra('quantidadeTotal', sacola.quantidadeTotal);
    _mostra('total', formatarReais(sacola.total));
    _mostra('temPrecoPendente',
        sacola.temPrecoPendente ? 'sim (tem item com preço a combinar)' : 'não');
  }

  _etapa('Cálculos da sacola (subtotal = preço x quantidade)');
  calculos();

  _etapa('Tirando 1 blusa: alterarQuantidade(item, -1)');
  sacola.alterarQuantidade(sacola.itens.first, -1);
  calculos();

  _etapa('Mensagem do pedido (a que vai para o WhatsApp)');
  for (final linha in sacola.mensagemPedido(numeroPedido: 1024).trimRight().split('\n')) {
    print('  | $linha');
  }

  print('');
  print(_pinta('32', 'Fim da demonstração.'));
}
