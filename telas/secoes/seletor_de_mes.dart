import 'package:flutter/material.dart';

import '../formatacao.dart';
import '../tema.dart';
import 'componentes.dart';

/// Meses em pílulas, do mais antigo ao mais recente, com um indicador que desliza até o escolhido.
/// Quando não cabem todos, setas nas pontas levam ao mês anterior e ao seguinte.
class SeletorDeMes extends StatefulWidget {
  const SeletorDeMes(
      {super.key, required this.meses, required this.mes, required this.habilitado, required this.aoEscolher});

  /// Do mês mais recente ao mais antigo, como vem do serviço.
  final List<String> meses;
  final String mes;
  final bool habilitado;
  final ValueChanged<String> aoEscolher;

  @override
  State<SeletorDeMes> createState() => _EstadoSeletorDeMes();
}

class _EstadoSeletorDeMes extends State<SeletorDeMes> {
  static const _largura = 78.0;
  static const _altura = 40.0;
  static const _recuo = Espaco.minimo;

  final _rolagem = ScrollController();

  @override
  void didUpdateWidget(SeletorDeMes anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.mes != widget.mes) WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarEscolhido());
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  /// A rolagem é invertida: a posição zero é o mês mais recente.
  void _mostrarEscolhido() {
    if (!mounted || !_rolagem.hasClients) return;
    final posicao = _rolagem.position;
    final centro = widget.meses.indexOf(widget.mes) * _largura - (posicao.viewportDimension - _largura) / 2;
    _rolagem.animateTo(
      centro.clamp(0, posicao.maxScrollExtent),
      duration: Movimento.de(context, Movimento.medio),
      curve: Movimento.saida,
    );
  }

  Widget _faixa(ColorScheme cores, List<String> ordem) => Container(
        padding: const EdgeInsets.all(_recuo),
        decoration: BoxDecoration(color: cores.surfaceContainerHigh, borderRadius: BorderRadius.circular(Raio.pilula)),
        child: SingleChildScrollView(
          controller: _rolagem,
          scrollDirection: Axis.horizontal,
          reverse: true, // abre mostrando o mês mais recente, mesmo com muitos meses
          child: SizedBox(
            width: _largura * ordem.length,
            height: _altura,
            child: Stack(
              children: [
                AnimatedPositioned(
                  left: ordem.indexOf(widget.mes) * _largura,
                  top: 0,
                  width: _largura,
                  height: _altura,
                  // Mesmo tempo e curva dos números e das barras: tudo se acomoda junto.
                  duration: Movimento.de(context, Movimento.lento),
                  curve: Movimento.saida,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: cores.primary, borderRadius: BorderRadius.circular(Raio.pilula)),
                  ),
                ),
                Row(
                  children: [
                    for (final opcao in ordem)
                      _PilulaDoMes(
                        mes: opcao,
                        escolhido: opcao == widget.mes,
                        largura: _largura,
                        aoEscolher: widget.habilitado ? () => widget.aoEscolher(opcao) : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final ordem = widget.meses.reversed.toList();
    final posicao = widget.meses.indexOf(widget.mes);
    VoidCallback? irPara(int indice) => !widget.habilitado || indice < 0 || indice >= widget.meses.length
        ? null
        : () => widget.aoEscolher(widget.meses[indice]);
    return LayoutBuilder(
      builder: (context, limites) {
        final cabemTodos = _largura * ordem.length + _recuo * 2 <= limites.maxWidth;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!cabemTodos)
              MolaAoPressionar(
                ativa: irPara(posicao + 1) != null,
                child: IconButton(
                  tooltip: 'Mês anterior',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: irPara(posicao + 1),
                ),
              ),
            Flexible(child: _faixa(cores, ordem)),
            if (!cabemTodos)
              MolaAoPressionar(
                ativa: irPara(posicao - 1) != null,
                child: IconButton(
                  tooltip: 'Próximo mês',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: irPara(posicao - 1),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PilulaDoMes extends StatelessWidget {
  const _PilulaDoMes({required this.mes, required this.escolhido, required this.largura, this.aoEscolher});

  final String mes;
  final bool escolhido;
  final double largura;
  final VoidCallback? aoEscolher;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Tooltip(
      message: maiusculaInicial(formatarMesPorExtenso(mes)),
      child: Semantics(
        selected: escolhido,
        child: MolaAoPressionar(
          ativa: aoEscolher != null,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: aoEscolher,
              child: SizedBox(
                width: largura,
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: Movimento.de(context, Movimento.rapido),
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: escolhido ? cores.onPrimary : cores.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                    child: Text(formatarMesCurto(mes)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
