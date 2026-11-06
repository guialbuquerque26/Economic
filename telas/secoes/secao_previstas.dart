import 'package:flutter/material.dart';

import '../formatacao.dart';
import '../tema.dart';
import 'componentes.dart';

/// Saídas com data futura, como parcelas do cartão, agrupadas por mês. Ainda não contam nos gastos.
class SecaoPrevistas extends StatelessWidget {
  const SecaoPrevistas({super.key, required this.previstas});

  final List<Dados> previstas;

  Map<String, List<Dados>> get _porMes {
    final meses = <String, List<Dados>>{};
    for (final prevista in previstas) {
      meses.putIfAbsent((prevista['data'] as String).substring(0, 7), () => []).add(prevista);
    }
    return meses;
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final detalhe = textos.bodySmall?.copyWith(color: cores.onSurfaceVariant);
    return Secao(
      titulo: 'Previsto para os próximos meses',
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Só entra nos seus gastos quando a data chegar.', style: detalhe),
          for (final MapEntry(key: mes, value: doMes) in _porMes.entries) ...[
            const SizedBox(height: Espaco.medio),
            Row(
              children: [
                Expanded(child: Text(formatarMesPorExtenso(mes), style: textos.titleSmall)),
                TextoValor(doMes.fold<num>(0, (soma, p) => soma + (p['valor'] as num)), estilo: textos.titleSmall),
              ],
            ),
            for (final prevista in doMes) _linha(prevista, textos, detalhe),
          ],
        ],
      ),
    );
  }

  Widget _linha(Dados prevista, TextTheme textos, TextStyle? detalhe) {
    final parcela = prevista['parcela'] as int?;
    final total = prevista['total_parcelas'] as int?;
    return Padding(
      padding: const EdgeInsets.only(top: Espaco.pequeno),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomeLegivel(prevista['descricao'] as String),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textos.bodyMedium,
                ),
                Text(
                  parcela == null || total == null
                      ? formatarData(prevista['data'] as String)
                      : 'parcela $parcela de $total',
                  style: detalhe,
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaco.pequeno),
          TextoValor(prevista['valor'] as num, estilo: textos.bodyMedium),
        ],
      ),
    );
  }
}
