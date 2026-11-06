import 'package:flutter/material.dart';

import '../formatacao.dart';
import 'componentes.dart';
import '../tema.dart';

/// Gastos do mês por categoria e o que ficou fora dos gastos.
class SecaoGastos extends StatelessWidget {
  const SecaoGastos({super.key, required this.resumo});

  final Dados resumo;

  @override
  Widget build(BuildContext context) {
    final gastos = resumo['gastos_por_categoria'] as Dados;
    final internas = resumo['movimentacoes_internas'] as Dados;
    final subtitulo = Theme.of(context).textTheme.titleMedium;
    return Secao(
      titulo: 'Para onde foi o dinheiro',
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gastos.isEmpty) const Text('Nenhum gasto neste mês.'),
          ListaValores(valores: gastos, deCategorias: true),
          if (internas.isNotEmpty) ...[
            const SizedBox(height: Espaco.medio),
            Text('Fora dos gastos (suas contas e investimentos)', style: subtitulo),
            const SizedBox(height: Espaco.pequeno + Espaco.minimo),
            ListaValores(valores: internas),
          ],
        ],
      ),
    );
  }
}

/// Lugares que mais receberam dinheiro no mês.
class SecaoLugares extends StatelessWidget {
  const SecaoLugares({super.key, required this.maiores});

  final Dados maiores;

  @override
  Widget build(BuildContext context) => Secao(titulo: 'Onde você mais gastou', filho: ListaValores(valores: maiores));
}
