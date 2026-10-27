import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'tema.dart';

/// Opção de escolha (categoria, tamanho, filtro) — o RvChip do DESIGN.md.
/// Selecionada: fundo vermelho suave e borda vermelha. Alvo de toque de pelo menos 44 px.
class PilulaEscolha extends StatelessWidget {
  const PilulaEscolha({
    super.key,
    required this.rotulo,
    required this.selecionada,
    required this.aoTocar,
  });

  final String rotulo;
  final bool selecionada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final duracao = RvMotion.de(context, RvMotion.fast);
    const forma = BorderRadius.all(Radius.circular(RvRadius.pill));
    return Semantics(
      button: true,
      selected: selecionada,
      child: AnimatedContainer(
        duration: duracao,
        curve: RvMotion.curve,
        decoration: BoxDecoration(
          color: selecionada ? RvColors.brandSoft : RvColors.surface,
          borderRadius: forma,
          border: Border.all(color: selecionada ? RvColors.brand : RvColors.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: aoTocar,
            borderRadius: forma,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RvSpace.lg),
                child: Center(
                  widthFactor: 1,
                  child: Text(rotulo,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: RvColors.textPrimary)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bolinha de cor (RvColorSwatch): recorte da própria foto da peça com a cor aplicada,
/// então mostra exatamente o que a cliente vai ver. Anel vermelho de 2 px quando selecionada.
class AmostraCor extends StatelessWidget {
  const AmostraCor({
    super.key,
    required this.foto,
    required this.variante,
    required this.selecionada,
    required this.aoTocar,
    this.tamanho = 28,
  });

  final String? foto;
  final VarianteCor variante;
  final bool selecionada;
  final VoidCallback aoTocar;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    const semFoto = ColoredBox(color: RvColors.surfaceRaised);
    Widget miolo = foto == null
        ? semFoto
        : Image.asset(foto!,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.1),
            cacheWidth: (tamanho * 3).round(),
            errorBuilder: (_, __, ___) => semFoto);
    if (foto != null) miolo = variante.aplicar(miolo);
    // Bolinhas grandes (seletor) ganham área de toque de 44 px; as pequenas do cartão não são alvo próprio.
    final alvo = tamanho >= 28 ? 44.0 : tamanho + 6;
    return Semantics(
      button: true,
      selected: selecionada,
      label: 'Cor ${variante.nome}',
      child: Tooltip(
        message: variante.nome,
        child: GestureDetector(
          onTap: aoTocar,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox.square(
              dimension: alvo,
              child: Center(
                child: AnimatedContainer(
                  duration: RvMotion.de(context, RvMotion.fast),
                  curve: RvMotion.curve,
                  width: tamanho + 6,
                  height: tamanho + 6,
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selecionada ? RvColors.brand : Colors.transparent, width: 2),
                  ),
                  child: ClipOval(child: miolo),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seletor de quantidade (stepper): menos, número, mais, dentro de um contorno só.
class SeletorQuantidade extends StatelessWidget {
  const SeletorQuantidade({
    super.key,
    required this.quantidade,
    required this.aoMudar,
    this.minimo = 1,
  });

  final int quantidade;
  final ValueChanged<int> aoMudar;
  final int minimo;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: RvColors.surface,
          border: Border.all(color: RvColors.border),
          borderRadius: BorderRadius.circular(RvRadius.sm),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Diminuir',
            icon: const Icon(Icons.remove, size: 18),
            onPressed:
                quantidade > minimo ? () => aoMudar(quantidade - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: AnimatedSwitcher(
              duration: RvMotion.de(context, RvMotion.fast),
              transitionBuilder: (filho, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(a), child: filho),
              ),
              child: Text('$quantidade',
                  key: ValueKey(quantidade),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
          ),
          IconButton(
            tooltip: 'Aumentar',
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => aoMudar(quantidade + 1),
          ),
        ]),
      );
}

/// Mostra a foto (asset), já recolorida pela [variante], ou um espaço
/// reservado ("Foto em breve") enquanto não há foto. Com [heroTag] a foto
/// "voa" do cartão para a tela da peça.
Widget fotoOuPlaceholder(String? caminho,
    {VarianteCor? variante, String? heroTag}) {
  const vazio = Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.checkroom, size: 44, color: RvColors.textMuted),
      SizedBox(height: 6),
      Text('Foto em breve', style: RvText.caption),
    ],
  );
  Widget conteudo = caminho == null
      ? vazio
      : Image.asset(caminho,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.5), // rosto fica no enquadramento
          errorBuilder: (_, __, ___) => vazio);
  if (caminho != null && variante != null) conteudo = variante.aplicar(conteudo);
  final quadro = Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: RvColors.surface,
      borderRadius: BorderRadius.circular(RvRadius.md),
    ),
    clipBehavior: Clip.antiAlias,
    child: conteudo,
  );
  return heroTag == null ? quadro : Hero(tag: heroTag, child: quadro);
}

/// Recolore a foto na cor da [VarianteCor]. Fica aqui, e não no modelo, para o
/// modelo continuar Dart puro (roda na demo de terminal, sem Flutter).
extension _FotoNaCor on VarianteCor {
  Widget aplicar(Widget foto) {
    if (ehOriginal) return foto;
    return ColorFiltered(
      colorFilter: tom != null
          ? ColorFilter.mode(Color(tom!), BlendMode.color)
          : ColorFilter.matrix(_matrizHue(hue)),
      child: foto,
    );
  }

  static List<double> _matrizHue(double graus) {
    final r = graus * math.pi / 180;
    final c = math.cos(r), s = math.sin(r);
    return [
      0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715,
      0.072 - c * 0.072 + s * 0.928, 0, 0, //
      0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140,
      0.072 - c * 0.072 - s * 0.283, 0, 0, //
      0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715,
      0.072 + c * 0.928 + s * 0.072, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}

enum RvButtonVariant { primary, secondary, ghost }

/// Botão padrão: primary (vermelho), secondary (contorno) ou ghost (só texto).
/// Carregando, mostra um spinner no lugar do texto e ignora toques sem mudar de cor.
class RvButton extends StatelessWidget {
  const RvButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = RvButtonVariant.primary,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final RvButtonVariant variant;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final acao = onPressed == null ? null : (loading ? () {} : onPressed);
    final corSpinner =
        variant == RvButtonVariant.primary ? RvColors.onBrand : RvColors.textPrimary;
    final rotulo = loading
        ? Semantics(
            label: 'Carregando',
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: corSpinner),
            ),
          )
        : Text(label);
    final comIcone = icon != null && !loading;
    return switch (variant) {
      RvButtonVariant.primary => comIcone
          ? FilledButton.icon(onPressed: acao, icon: Icon(icon), label: rotulo)
          : FilledButton(onPressed: acao, child: rotulo),
      RvButtonVariant.secondary => comIcone
          ? OutlinedButton.icon(onPressed: acao, icon: Icon(icon), label: rotulo)
          : OutlinedButton(onPressed: acao, child: rotulo),
      RvButtonVariant.ghost => comIcone
          ? TextButton.icon(onPressed: acao, icon: Icon(icon), label: rotulo)
          : TextButton(onPressed: acao, child: rotulo),
    };
  }
}

/// Status do pedido em pílula com ponto colorido (Recebido, Em separação, Enviado, Entregue, Devolvido, Cancelado).
class RvStatusBadge extends StatelessWidget {
  const RvStatusBadge(this.status, {super.key});
  final String status;

  static Color corDe(String status) => switch (status) {
        'Recebido' => RvColors.info,
        'Em separação' => RvColors.warning,
        'Enviado' || 'Entregue' => RvColors.success,
        'Cancelado' || 'Devolvido' => RvColors.danger,
        _ => RvColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final cor = corDe(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(RvRadius.pill),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(status, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Estado vazio: ícone, título, texto curto e um botão.
class RvEmptyState extends StatelessWidget {
  const RvEmptyState({
    super.key,
    required this.icone,
    required this.titulo,
    this.texto,
    this.rotuloAcao,
    this.aoAcionar,
  });

  final IconData icone;
  final String titulo;
  final String? texto;
  final String? rotuloAcao;
  final VoidCallback? aoAcionar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: RvSpace.xl, vertical: RvSpace.x3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: RvColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: RvColors.border),
            ),
            child: Icon(icone, size: 30, color: RvColors.textSecondary),
          ),
          const SizedBox(height: RvSpace.lg),
          Text(titulo,
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          if (texto != null) ...[
            const SizedBox(height: RvSpace.sm),
            Text(texto!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: RvColors.textSecondary)),
          ],
          if (rotuloAcao != null) ...[
            const SizedBox(height: RvSpace.xl),
            RvButton(label: rotuloAcao!, onPressed: aoAcionar, variant: RvButtonVariant.secondary),
          ],
        ]),
      );
}

/// Bloco de carregamento com brilho suave passando (parado com "reduzir movimento").
class RvSkeleton extends StatefulWidget {
  const RvSkeleton({super.key, this.largura, this.altura = 16, this.raio = RvRadius.sm});
  final double? largura;
  final double altura;
  final double raio;

  @override
  State<RvSkeleton> createState() => _RvSkeletonState();
}

class _RvSkeletonState extends State<RvSkeleton> with SingleTickerProviderStateMixin {
  late final _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _anim.stop() : _anim.repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) {
            final x = _anim.value * 3 - 1; // de -1 a 2: o brilho atravessa o bloco
            return Container(
              width: widget.largura,
              height: widget.altura,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.raio),
                gradient: LinearGradient(
                  begin: Alignment(x - 1, 0),
                  end: Alignment(x + 1, 0),
                  colors: const [
                    RvColors.surfaceRaised,
                    Color(0xFF26262A),
                    RvColors.surfaceRaised,
                  ],
                ),
              ),
            );
          },
        ),
      );
}

/// Campo de texto com o rótulo acima, ajuda/erro abaixo e máscara opcional.
class RvTextField extends StatelessWidget {
  const RvTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
    this.onSubmitted,
    this.obscureText = false,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: RvSpace.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: RvText.label.copyWith(color: RvColors.textSecondary)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            inputFormatters: inputFormatters,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: onSubmitted,
            decoration: InputDecoration(hintText: hint, helperText: helper, errorText: errorText),
          ),
        ]),
      );
}
