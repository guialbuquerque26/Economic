import 'package:flutter/material.dart';

import '../formatacao.dart';
import '../tema.dart';
import 'componentes.dart';

/// Últimos meses: barras com o que saiu em cada mês e, ao lado, a tabela de gastos por categoria.
class SecaoEvolucao extends StatelessWidget {
  const SecaoEvolucao({super.key, required this.evolucao, this.mes, this.aoEscolherMes});

  final Dados evolucao;

  /// Mês em exibição: sua barra fica destacada. Clicar numa barra abre o mês dela.
  final String? mes;
  final ValueChanged<String>? aoEscolherMes;

  static const _alturaEmColuna = 150.0;
  static const _alturaAoLadoDaTabela = 250.0;
  static const _larguraLadoALado = 860.0;

  @override
  Widget build(BuildContext context) {
    final meses = List<Dados>.from(evolucao['meses'] as List);
    final medias = evolucao['media_gastos_por_categoria'] as Dados;
    return Secao(
      titulo: 'Como os meses vêm indo',
      filho: LayoutBuilder(
        builder: (context, limites) {
          final tabela = medias.isEmpty ? null : _tabela(context, meses, medias);
          if (limites.maxWidth >= _larguraLadoALado && tabela != null) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _grafico(meses, _alturaAoLadoDaTabela)),
                const SizedBox(width: Espaco.enorme),
                Expanded(flex: 3, child: tabela),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _grafico(meses, _alturaEmColuna),
              if (tabela != null) ...[const SizedBox(height: Espaco.medio), tabela],
            ],
          );
        },
      ),
    );
  }

  Widget _grafico(List<Dados> meses, double altura) {
    final maiorSaida = meses.map((m) => m['saidas'] as num).fold<num>(0, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (meses.length < 2)
          const Padding(
            padding: EdgeInsets.only(bottom: Espaco.pequeno),
            child: Text('Importe extratos de mais meses para comparar.'),
          ),
        SizedBox(
          height: altura + 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final dados in meses)
                Expanded(
                  child: _ColunaDoMes(
                    dados: dados,
                    fracao: maiorSaida == 0 ? 0 : (dados['saidas'] as num) / maiorSaida,
                    altura: altura,
                    escolhido: dados['mes'] == mes,
                    aoEscolher: aoEscolherMes == null ? null : () => aoEscolherMes!(dados['mes'] as String),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabela(BuildContext context, List<Dados> meses, Dados medias) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, limites) => RolagemHorizontal(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: limites.maxWidth),
          child: DataTable(
            columnSpacing: Espaco.grande,
            horizontalMargin: 0,
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 36,
            headingTextStyle: textos.labelMedium?.copyWith(color: cores.onSurfaceVariant),
            columns: [
              const DataColumn(label: Text('Categoria')),
              for (final dados in meses)
                DataColumn(label: Text(formatarMesCurto(dados['mes'] as String)), numeric: true),
              const DataColumn(label: Text('Média'), numeric: true),
            ],
            rows: [
              for (final categoria in medias.keys)
                DataRow(cells: [
                  DataCell(Row(children: [
                    PontoDeCor(visualDaCategoria(categoria).cor),
                    const SizedBox(width: Espaco.pequeno),
                    Text(categoria),
                  ])),
                  for (final dados in meses)
                    DataCell(TextoValor(((dados['gastos_por_categoria'] as Dados)[categoria] ?? 0) as num)),
                  DataCell(TextoValor(medias[categoria] as num, estilo: textos.labelLarge)),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColunaDoMes extends StatelessWidget {
  static const _larguraDaBarra = 56.0;

  const _ColunaDoMes({
    required this.dados,
    required this.fracao,
    required this.altura,
    required this.escolhido,
    this.aoEscolher,
  });

  final Dados dados;
  final double fracao;
  final double altura;
  final bool escolhido;
  final VoidCallback? aoEscolher;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final mes = dados['mes'] as String;
    final sobra = dados['sobra_do_mes'] as num;
    final cor = escolhido ? cores.primary : cores.outline;
    return Tooltip(
      message: 'Abrir ${formatarMesPorExtenso(mes)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(Raio.medio),
        onTap: escolhido ? null : aoEscolher,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espaco.minimo),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child:
                    Text('Saiu ${formatarReais(dados['saidas'] as num, centavos: false)}', style: textos.labelMedium),
              ),
              const SizedBox(height: Espaco.minimo),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fracao),
                duration: Movimento.de(context, Movimento.lento),
                curve: Movimento.saida,
                builder: (context, atual, _) => Container(
                  width: _larguraDaBarra,
                  height: (altura * atual).clamp(6, altura),
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(Raio.pequeno), bottom: Radius.circular(4)),
                  ),
                ),
              ),
              const SizedBox(height: Espaco.pequeno),
              Text(formatarMesCurto(mes), style: textos.labelLarge),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${sobra < 0 ? 'Faltou' : 'Sobrou'} ${formatarReais(sobra.abs(), centavos: false)}',
                  style: textos.labelSmall?.copyWith(color: context.coresFinanceiras.doValor(sobra)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
