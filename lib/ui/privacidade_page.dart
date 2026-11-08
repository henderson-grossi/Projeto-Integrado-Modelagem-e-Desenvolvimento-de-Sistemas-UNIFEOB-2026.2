import 'package:flutter/material.dart';

import '../services/loja_info.dart';
import 'fundo_liquido.dart';
import 'rolagem_suave.dart';

/// Política de privacidade (LGPD) e termos de uso, em linguagem direta.
class PrivacidadePage extends StatelessWidget {
  const PrivacidadePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Privacidade e termos')),
        body: FundoLiquido(
          child: ListaSuave(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (titulo, texto) in blocosPrivacidade) ...[
                        Text(titulo, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(texto, style: const TextStyle(fontSize: 16, height: 1.5)),
                        const SizedBox(height: 22),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
