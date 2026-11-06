import 'package:flutter/material.dart';

import '../formatacao.dart';
import '../tema.dart';
import 'componentes.dart';

/// Última dica guardada para o mês, se houver.
Dados? ultimaDicaDoMes(List<Dados> dicas, String mes) => dicas.where((dica) => dica['mes'] == mes).firstOrNull;

/// Itens da dica com o que pede ação mais urgente primeiro.
List<Dados> itensOrdenados(Dados dica) => List<Dados>.from(dica['itens'] as List)
  ..sort((a, b) => _ordemDosTipos.indexOf(a['tipo'] as String) - _ordemDosTipos.indexOf(b['tipo'] as String));

/// Para a abertura do painel: um conselho de verdade; o alerta só entra quando não houver outro.
Dados? conselhoDoMes(Dados dica) {
  final itens = itensOrdenados(dica);
  return itens.where((item) => const ['cortar', 'saldo'].contains(item['tipo'])).firstOrNull ?? itens.firstOrNull;
}

/// Últimas dicas da IA para o mês escolhido, agrupadas por tipo, com ícone próprio.
class SecaoDicas extends StatelessWidget {
  const SecaoDicas(
      {super.key, required this.dicas, required this.mes, required this.habilitado, required this.aoGerar});

  final List<Dados> dicas;
  final String mes;
  final bool habilitado;
  final VoidCallback aoGerar;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final ultima = ultimaDicaDoMes(dicas, mes);
    return Secao(
      titulo: 'O que fazer agora',
      acoes: [
        if (ultima == null)
          MolaAoPressionar(
            ativa: habilitado,
            child: FilledButton.icon(
              onPressed: habilitado ? aoGerar : null,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Gerar dicas'),
            ),
          )
        else
          MolaAoPressionar(
            ativa: habilitado,
            child: TextButton.icon(
              onPressed: habilitado ? aoGerar : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Gerar de novo'),
            ),
          ),
      ],
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ultima == null)
            Text(
              'Ainda não há dicas para ${formatarMesPorExtenso(mes)}. Clique em "Gerar dicas" para saber onde '
              'economizar e o que fazer com o seu saldo.',
              style: textos.bodyMedium?.copyWith(color: cores.onSurfaceVariant),
            )
          else ...[
            // A chave faz as dicas novas entrarem de novo, uma depois da outra.
            KeyedSubtree(key: ValueKey(ultima['criada_em']), child: _grupos(ultima)),
            const SizedBox(height: Espaco.medio),
            Text(
              'Geradas pela IA em ${formatarData(ultima['criada_em'] as String)}',
              style: textos.bodySmall?.copyWith(color: cores.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  /// Junta os itens do mesmo tipo, mantendo a ordem de urgência.
  Widget _grupos(Dados dica) {
    final grupos = <String, List<Dados>>{};
    for (final item in itensOrdenados(dica)) {
      (grupos[item['tipo'] as String] ??= []).add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (ordem, grupo) in grupos.entries.indexed) ...[
          if (ordem > 0) const SizedBox(height: Espaco.medio + Espaco.minimo),
          EntradaSuave(ordem: ordem, child: _GrupoDeDicas(tipo: grupo.key, itens: grupo.value)),
        ],
      ],
    );
  }
}

/// O alerta vem primeiro: é o que pede ação mais urgente. Dicas antigas sem tipo reconhecido ficam por último.
const _ordemDosTipos = ['alerta', 'cortar', 'saldo', 'comparar', 'dica'];

class _GrupoDeDicas extends StatelessWidget {
  const _GrupoDeDicas({required this.tipo, required this.itens});

  final String tipo;
  final List<Dados> itens;

  ({IconData icone, String nome}) get _visual => switch (tipo) {
        'alerta' => (icone: Icons.warning_amber_rounded, nome: 'Atenção'),
        'cortar' => (icone: Icons.content_cut_rounded, nome: 'Onde cortar'),
        'saldo' => (icone: Icons.savings_rounded, nome: 'O que fazer com o saldo'),
        'comparar' => (icone: Icons.compare_arrows_rounded, nome: 'Comparado a outros meses'),
        _ => (icone: Icons.lightbulb_rounded, nome: 'Dicas'),
      };

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final visual = _visual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          IconeEmCaixa(visual.icone),
          const SizedBox(width: Espaco.pequeno + Espaco.minimo),
          Expanded(child: Text(visual.nome, style: textos.titleMedium)),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in itens)
                _ItemDaDica(
                  titulo: item['titulo'] as String?,
                  texto: item['texto'] as String,
                  valor: item['valor'] as num?,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemDaDica extends StatelessWidget {
  const _ItemDaDica({required this.titulo, required this.texto, this.valor});

  final String? titulo;
  final String texto;
  final num? valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final linhas = linhasDaDica(texto);
    return Padding(
      padding: const EdgeInsets.only(top: Espaco.pequeno),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(titulo!, style: textos.titleSmall)),
                if (valor != null) ...[
                  const SizedBox(width: Espaco.pequeno),
                  TextoValor(valor!, estilo: textos.titleSmall),
                ],
              ],
            ),
          if (linhas.length == 1)
            _TextoDaDica(linhas.single.texto)
          else
            for (final linha in linhas) _LinhaDaLista(linha),
        ],
      ),
    );
  }
}

/// Texto da IA com os valores em destaque. Dá para selecionar e copiar.
class _TextoDaDica extends StatelessWidget {
  const _TextoDaDica(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    const destaque = TextStyle(fontWeight: FontWeight.w700, fontFeatures: algarismosAlinhados);
    final trechos = <TextSpan>[];
    var posicao = 0;
    for (final valor in valorNoTexto.allMatches(texto)) {
      trechos
        ..add(TextSpan(text: texto.substring(posicao, valor.start)))
        ..add(TextSpan(text: valor[0], style: destaque));
      posicao = valor.end;
    }
    trechos.add(TextSpan(text: texto.substring(posicao)));
    return SelectableText.rich(
      TextSpan(children: trechos),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
    );
  }
}

/// Item de lista dentro de uma dica: bolinha da categoria citada, texto e, à direita, o valor que fecha a frase.
class _LinhaDaLista extends StatelessWidget {
  const _LinhaDaLista(this.linha);

  final LinhaDaDica linha;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final corDoPonto = linha.categoria == null ? cores.outline : visualDaCategoria(linha.categoria!).cor;
    final total = linha.categoria == null && linha.texto.startsWith('Total'); // fecha a lista: não é mais um item
    return Padding(
      padding: EdgeInsets.only(top: total ? Espaco.pequeno : Espaco.minimo + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!total) ...[
            Padding(padding: const EdgeInsets.only(top: 5), child: PontoDeCor(corDoPonto)),
            const SizedBox(width: Espaco.pequeno),
          ],
          Expanded(child: _TextoDaDica(linha.texto)),
          if (linha.valor != null) ...[
            const SizedBox(width: Espaco.pequeno),
            Text(
              linha.valor!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontFeatures: algarismosAlinhados),
            ),
          ],
        ],
      ),
    );
  }
}
