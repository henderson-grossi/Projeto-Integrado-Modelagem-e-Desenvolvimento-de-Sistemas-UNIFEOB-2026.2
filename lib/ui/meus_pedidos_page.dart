import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/mascaras.dart';
import '../core/moeda.dart';
import '../services/api.dart';
import '../services/api_admin.dart';
import 'componentes.dart';
import 'fundo_liquido.dart';
import 'rolagem_suave.dart';
import 'tema.dart';

/// O cliente acompanha o pedido com número + telefone (sem conta).
class MeusPedidosPage extends StatefulWidget {
  const MeusPedidosPage({super.key});

  @override
  State<MeusPedidosPage> createState() => _MeusPedidosPageState();
}

class _MeusPedidosPageState extends State<MeusPedidosPage> {
  static const _etapas = ['Recebido', 'Em separação', 'Enviado', 'Entregue'];
  final _numero = TextEditingController();
  final _telefone = TextEditingController();
  Map<String, dynamic>? _pedido;
  String? _erro;
  bool _carregando = false;

  @override
  void dispose() {
    _numero.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final id = int.tryParse(_numero.text.trim());
    final tel = _telefone.text.replaceAll(RegExp(r'\D'), '');
    if (id == null || tel.length < 10) {
      setState(() => _erro = 'Informe o número do pedido e o telefone com DDD.');
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
      _pedido = null;
    });
    try {
      final p = await ApiAdmin.consultarPedido(id, tel);
      if (mounted) setState(() => _pedido = p);
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Sem conexão com o servidor. Tente de novo.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pedido;
    return Scaffold(
      appBar: AppBar(title: const Text('Meus pedidos')),
      body: FundoLiquido(
        child: ListaSuave(padding: const EdgeInsets.all(24), children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(
                    'Use o número do pedido (enviado no WhatsApp) e o '
                    'telefone que você informou na compra.',
                    style: TextStyle(color: RvColors.textSecondary)),
                const SizedBox(height: RvSpace.xl),
                RvTextField(
                  label: 'Número do pedido',
                  controller: _numero,
                  hint: 'Ex.: 128',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                RvTextField(
                  label: 'Telefone (com DDD)',
                  controller: _telefone,
                  hint: '(11) 99999-9999',
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [Mascara(formatarTelefone)],
                  onSubmitted: (_) => _buscar(),
                ),
                RvButton(label: 'Consultar', loading: _carregando, onPressed: _buscar),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: RvSpace.lg),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.error_outline, size: 18, color: RvColors.danger),
                      const SizedBox(width: RvSpace.sm),
                      Expanded(
                          child: Text(_erro!, style: const TextStyle(color: RvColors.danger))),
                    ]),
                  ),
                if (p != null) ..._detalhe(context, p),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _detalhe(BuildContext context, Map<String, dynamic> p) {
    final status = p['status'] as String;
    // Cancelado e devolvido encerram o pedido: aparecem como uma etapa só, em vermelho.
    final encerrado = status == 'Cancelado' || status == 'Devolvido';
    final atual = _etapas.indexOf(status);
    // A API só guarda a data do pedido (etapa "Recebido"); as outras etapas aparecem sem data.
    final data = DateTime.tryParse('${p['data']}')?.toLocal();
    String? dataDe(int etapa) => etapa == 0 && data != null
        ? '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}'
        : null;
    return [
      const SizedBox(height: RvSpace.x2),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(RvSpace.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('Pedido nº ${p['id']}',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              RvStatusBadge(status),
            ]),
            const SizedBox(height: RvSpace.xl),
            if (encerrado)
              _Etapa(
                rotulo: status,
                data: null,
                cor: RvColors.danger,
                feita: true,
                ultima: true,
                icone: status == 'Devolvido' ? Icons.assignment_return : Icons.cancel,
              )
            else
              for (var i = 0; i < _etapas.length; i++)
                _Etapa(
                  rotulo: _etapas[i],
                  data: dataDe(i),
                  cor: RvStatusBadge.corDe(_etapas[i]),
                  feita: i <= atual,
                  atual: i == atual,
                  ultima: i == _etapas.length - 1,
                ),
            const Divider(height: RvSpace.x2),
            for (final i in (p['itens'] as List).cast<Map<String, dynamic>>())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: RvSpace.xs),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text('${i['quantidade']}× ${i['nome']}\n${i['cor']} · ${i['tamanho']}',
                        style: const TextStyle(height: 1.4)),
                  ),
                  Text(
                      i['subtotal'] == null
                          ? 'a combinar'
                          : formatarReais((i['subtotal'] as num).toDouble()),
                      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
            const SizedBox(height: RvSpace.md),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total'),
              Flexible(
                child: Text(
                    '${formatarReais((p['total'] as num).toDouble())}'
                    '${p['precoPendente'] == true ? ' + itens a combinar' : ''}',
                    textAlign: TextAlign.end,
                    style: RvText.price),
              ),
            ]),
          ]),
        ),
      ),
    ];
  }
}

/// Uma etapa da linha do tempo: ponto (cheio se já passou), linha até a próxima, nome e data.
class _Etapa extends StatelessWidget {
  const _Etapa({
    required this.rotulo,
    required this.data,
    required this.cor,
    required this.feita,
    required this.ultima,
    this.atual = false,
    this.icone = Icons.check,
  });

  final String rotulo;
  final String? data;
  final Color cor;
  final bool feita;
  final bool atual;
  final bool ultima;
  final IconData icone;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 28,
            child: Column(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: feita ? cor : Colors.transparent,
                  border: Border.all(color: feita ? cor : RvColors.border, width: 2),
                ),
                child: feita ? Icon(icone, size: 14, color: RvColors.bg) : null,
              ),
              if (!ultima)
                Expanded(
                  child: Container(
                      width: 2, color: feita ? cor.withValues(alpha: 0.5) : RvColors.border),
                ),
            ]),
          ),
          const SizedBox(width: RvSpace.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: ultima ? 0 : RvSpace.xl),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rotulo,
                    style: TextStyle(
                        fontWeight: atual ? FontWeight.w700 : FontWeight.w500,
                        color: feita ? RvColors.textPrimary : RvColors.textMuted)),
                if (data != null) Text(data!, style: RvText.caption),
              ]),
            ),
          ),
        ]),
      );
}
