import '../core/moeda.dart';
import 'acessorio.dart';
import 'categoria.dart';
import 'peca.dart';
import 'serializavel.dart';
import 'variante_cor.dart';

/// Classe-base (abstrata) de tudo que a loja vende.
/// Os dados ficam PRIVADOS (_) e só mudam por get/set com validação.
abstract class Produto with Serializavel {
  Produto({
    required this.id,
    required String nome,
    required this.categoria,
    this.descricao = '',
    double? preco,
    List<String> fotos = const [],
    List<VarianteCor> cores = const [VarianteCor(nome: 'Única')],
  })  : _nome = _validarNome(nome),
        _preco = _validarPreco(preco),
        _fotos = List.unmodifiable(fotos),
        _cores = List.unmodifiable(cores);

  final String id;
  final Categoria categoria;
  final String descricao;

  String _nome;
  double? _preco; // null = "Preço a definir"
  final List<String> _fotos;
  final List<VarianteCor> _cores; // a primeira é a cor da foto original

  // ---- get / set ----
  String get nome => _nome;
  set nome(String valor) => _nome = _validarNome(valor);

  double? get preco => _preco;
  set preco(double? valor) => _preco = _validarPreco(valor);

  List<String> get fotos => _fotos;
  List<VarianteCor> get cores => _cores;

  String get precoFormatado =>
      _preco == null ? 'Preço a definir' : formatarReais(_preco!);

  // ---- polimorfismo: cada subclasse define o seu ----
  List<String> get tamanhos;
  String get rotuloTipo;

  /// Texto curto exibido na vitrine. Subclasses podem estender.
  String get resumo => '$rotuloTipo · ${categoria.rotulo}';

  /// Campos comuns, nas mesmas chaves do catalogo.json (volta pelo [Produto.fromJson]).
  /// Cada subclasse reaproveita este mapa com `super.toMap()` e soma os seus.
  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': _nome,
        'categoria': categoria.name,
        'descricao': descricao,
        'preco': _preco,
        'fotos': _fotos,
        'cores': [for (final c in _cores) c.toMap()],
      };

  static String _validarNome(String valor) {
    final limpo = valor.trim();
    if (limpo.isEmpty) throw ArgumentError('O nome não pode ser vazio.');
    return limpo;
  }

  static double? _validarPreco(double? valor) {
    if (valor != null && valor < 0) {
      throw ArgumentError('O preço não pode ser negativo.');
    }
    return valor;
  }

  /// Fábrica: lê uma entrada do catalogo.json e devolve a subclasse certa.
  factory Produto.fromJson(Map<String, dynamic> j) {
    final cores = [
      for (final c in (j['cores'] as List? ?? const []))
        VarianteCor.fromJson(c as Map<String, dynamic>)
    ];
    final fotos = [...(j['fotos'] as List? ?? const [])].cast<String>();
    final categoria = Categoria.values.byName(j['categoria'] as String);
    final corLista = cores.isEmpty ? const [VarianteCor(nome: 'Única')] : cores;

    if (j['tipo'] == 'acessorio') {
      return Acessorio(
        id: j['id'] as String,
        nome: j['nome'] as String,
        categoria: categoria,
        descricao: (j['descricao'] as String?) ?? '',
        preco: (j['preco'] as num?)?.toDouble(),
        fotos: fotos,
        cores: corLista,
        material: j['material'] as String?,
      );
    }
    return Peca(
      id: j['id'] as String,
      nome: j['nome'] as String,
      categoria: categoria,
      descricao: (j['descricao'] as String?) ?? '',
      preco: (j['preco'] as num?)?.toDouble(),
      fotos: fotos,
      cores: corLista,
      tamanhos: [...(j['tamanhos'] as List? ?? const ['P', 'M', 'G'])]
          .cast<String>(),
      fotoCostas: j['fotoCostas'] as String?,
    );
  }
}
