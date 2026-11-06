import 'package:flutter/material.dart';

import '../formatacao.dart';
import '../tema.dart';
import 'componentes.dart';

/// Abertura do painel: o mês em uma frase, o conselho da IA e, ao lado, saldo, entradas e saídas.
class SecaoMetricas extends StatelessWidget {
  const SecaoMetricas({
    super.key,
    required this.resumo,
    required this.mes,
    this.nome,
    this.conselho,
    this.habilitado = true,
    this.aoGerarDicas,
    this.aoVerDicas,
    this.aoInformarSaldo,
  });

  final Dados resumo;
  final String mes;
  final String? nome;

  /// Primeira dica do mês, se já houver.
  final Dados? conselho;
  final bool habilitado;
  final VoidCallback? aoGerarDicas;
  final VoidCallback? aoVerDicas;
  final VoidCallback? aoInformarSaldo;

  static const _larguraLadoALado = 760.0;

  /// O informado pela pessoa é provisório: a conexão com o banco ou um extrato com saldo o substituem.
  static String _origemDoSaldo(Dados informado) {
    final data = formatarData(informado['data'] as String);
    return switch (informado['origem']) {
      'banco' => 'Saldo do banco, atualizado em $data.',
      'extrato' => 'Saldo do extrato de $data.',
      _ => 'Saldo provisório, informado por você em $data.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Cartao(
      preenchimento: const EdgeInsets.all(Espaco.grande + Espaco.pequeno),
      filho: LayoutBuilder(
        builder: (context, limites) {
          if (limites.maxWidth < _larguraLadoALado) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_oMes(context), const SizedBox(height: Espaco.grande), _contas(context)],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _oMes(context)),
                const VerticalDivider(width: Espaco.enorme * 2),
                Expanded(flex: 2, child: _contas(context)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _oMes(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    final sobra = resumo['sobra_do_mes'] as num;
    final emAndamento = mes == DateTime.now().toIso8601String().substring(0, 7);
    final saldo = resumo['saldo_informado'] == null ? null : resumo['saldo_atual'] as num;
    final texto = conselho == null
        ? 'Peça uma análise e veja onde dá para economizar e o que fazer com o seu saldo.'
        : resumoDaDica(conselho!['titulo'] as String?, conselho!['texto'] as String);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // O valor rola junto com o saldo e as barras quando o mês muda.
        TweenAnimationBuilder<double>(
          tween: Tween(end: sobra.toDouble()),
          duration: Movimento.de(context, Movimento.lento),
          curve: Movimento.saida,
          builder: (context, atual, _) {
            final frase = fraseDoMes(mes, atual, nome: nome, emAndamento: emAndamento, saldo: saldo);
            return Text.rich(
              TextSpan(children: [
                TextSpan(text: frase.inicio),
                if (frase.valor != null)
                  // Espaço que não quebra: "R$" nunca fica sozinho no fim da linha.
                  TextSpan(
                    text: frase.valor!.replaceAll(' ', '\u00a0'),
                    // Gasto de mês em andamento não é prejuízo: fica sem a cor de alerta.
                    style: emAndamento && atual < 0
                        ? null
                        : TextStyle(color: context.coresFinanceiras.doValor(atual)),
                  ),
                TextSpan(text: frase.fim),
              ]),
              style: textos.displaySmall,
            );
          },
        ),
        const SizedBox(height: Espaco.pequeno + Espaco.minimo),
        Text(texto,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textos.bodyLarge?.copyWith(color: cores.onSurfaceVariant)),
        const SizedBox(height: Espaco.medio + Espaco.minimo),
        Wrap(
          spacing: Espaco.medio,
          runSpacing: Espaco.pequeno + Espaco.minimo,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MolaAoPressionar(
              ativa: habilitado,
              child: FilledButton.icon(
                onPressed: !habilitado ? null : (conselho == null ? aoGerarDicas : aoVerDicas),
                icon: Icon(conselho == null ? Icons.auto_awesome_rounded : Icons.arrow_downward_rounded, size: 18),
                label: Text(conselho == null ? 'Gerar dicas do mês' : 'Ver o que fazer'),
              ),
            ),
            const AvisoDePrivacidade(),
          ],
        ),
      ],
    );
  }

  Widget _contas(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    final financeiras = context.coresFinanceiras;
    final informado = resumo['saldo_informado'] as Dados?;
    final entradas = resumo['entradas'] as num;
    final provisoria = resumo['entrada_provisoria'] as num? ?? 0;
    final saidas = resumo['saidas'] as num;
    final maior = entradas > saidas ? entradas : saidas;
    final secundario = textos.bodySmall?.copyWith(color: cores.onSurfaceVariant);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // ocupa a altura da frase ao lado; em coluna, encosta
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo atual', style: textos.labelLarge?.copyWith(color: cores.onSurfaceVariant)),
            ValorAnimado(resumo['saldo_atual'] as num, estilo: textos.headlineSmall),
            Text(
              informado == null ? 'Informe o saldo atual para este valor ficar exato.' : _origemDoSaldo(informado),
              style: secundario,
            ),
            MolaAoPressionar(
              ativa: habilitado,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                onPressed: habilitado ? aoInformarSaldo : null,
                child: const Text('Informar saldo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: Espaco.pequeno),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Fluxo('Entrou', entradas, maior == 0 ? 0 : entradas / maior, financeiras.positivo),
            if (provisoria > 0)
              Padding(
                padding: const EdgeInsets.only(top: Espaco.minimo),
                child: Text(
                  'Inclui ${formatarReais(provisoria)} do saldo informado, até entrar um valor real.',
                  style: secundario,
                ),
              ),
            const SizedBox(height: Espaco.pequeno + Espaco.minimo),
            _Fluxo('Saiu', saidas, maior == 0 ? 0 : saidas / maior, financeiras.negativo),
          ],
        ),
      ],
    );
  }
}

class _Fluxo extends StatelessWidget {
  const _Fluxo(this.nome, this.valor, this.fracao, this.cor);

  final String nome;
  final num valor;
  final double fracao;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: Text(nome, style: textos.titleSmall)),
          ValorAnimado(valor, estilo: textos.titleSmall),
        ]),
        const SizedBox(height: Espaco.minimo + 2),
        BarraAnimada(fracao: fracao.toDouble(), cor: cor),
      ],
    );
  }
}
