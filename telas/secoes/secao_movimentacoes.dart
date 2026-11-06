import 'package:flutter/material.dart';

import '../formatacao.dart';
import '../tema.dart';
import 'componentes.dart';

/// Movimentações do mês com busca, filtro por categoria e troca de categoria.
class SecaoMovimentacoes extends StatefulWidget {
  const SecaoMovimentacoes({
    super.key,
    required this.transacoes,
    required this.categorias,
    required this.habilitado,
    required this.aoCorrigir,
    required this.aoReclassificar,
  });

  final List<Dados> transacoes;
  final List<String> categorias;
  final bool habilitado;
  final void Function(int id, String categoria) aoCorrigir;
  final VoidCallback aoReclassificar;

  @override
  State<SecaoMovimentacoes> createState() => _EstadoSecaoMovimentacoes();
}

class _EstadoSecaoMovimentacoes extends State<SecaoMovimentacoes> {
  String _busca = '';
  String? _categoria; // null = todas
  String? _forma; // null = crédito e débito
  String? _instituicao; // null = todas

  bool get _temForma => widget.transacoes.any((t) => t['forma'] != null);

  List<String> get _instituicoes => {
        for (final t in widget.transacoes)
          if (t['instituicao'] != null) t['instituicao'] as String
      }.toList()
        ..sort();

  /// A escolhida pode não existir no mês aberto agora: aí vale "todas".
  String? get _instituicaoDoMes => _instituicoes.contains(_instituicao) ? _instituicao : null;

  List<Dados> get _filtradas {
    final instituicao = _instituicaoDoMes;
    return [
      for (final t in widget.transacoes)
        if ((_categoria == null || t['categoria'] == _categoria) &&
            (_forma == null || t['forma'] == _forma) &&
            (instituicao == null || t['instituicao'] == instituicao) &&
            semAcento(t['descricao'] as String).contains(semAcento(_busca)))
          t,
    ];
  }

  Widget _filtro(String? valor, String rotuloDeTodas, Map<String, String> opcoes, ValueChanged<String?> aoEscolher) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: Espaco.medio, right: Espaco.pequeno),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(Raio.medio),
        border: Border.all(color: cores.outlineVariant),
      ),
      child: DropdownButton<String?>(
        value: valor,
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(Raio.medio),
        style: Theme.of(context).textTheme.labelLarge,
        icon: Icon(Icons.expand_more_rounded, size: 18, color: cores.onSurfaceVariant),
        items: [
          DropdownMenuItem(value: null, child: Text(rotuloDeTodas)),
          for (final opcao in opcoes.entries) DropdownMenuItem(value: opcao.key, child: Text(opcao.value)),
        ],
        onChanged: aoEscolher,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final filtradas = _filtradas;
    final total = filtradas.fold<num>(0, (soma, t) => soma + (t['valor'] as num));
    return Secao(
      titulo: 'Movimentações',
      acoes: [
        Tooltip(
          message: 'Pede à IA a categoria das movimentações de todos os meses que ficaram em "Outros"',
          child: MolaAoPressionar(
            ativa: widget.habilitado,
            child: TextButton.icon(
              onPressed: widget.habilitado ? widget.aoReclassificar : null,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Classificar com IA'),
            ),
          ),
        ),
      ],
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Espaco.pequeno + Espaco.minimo,
            runSpacing: Espaco.pequeno,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Buscar movimentação',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (texto) => setState(() => _busca = texto),
                ),
              ),
              _filtro(
                _categoria,
                'Todas as categorias',
                {for (final categoria in widget.categorias) categoria: categoria},
                (categoria) => setState(() => _categoria = categoria),
              ),
              if (_temForma)
                _filtro(
                  _forma,
                  'Crédito e débito',
                  const {'credito': 'Crédito', 'debito': 'Débito'},
                  (forma) => setState(() => _forma = forma),
                ),
              if (_instituicoes.isNotEmpty)
                _filtro(
                  _instituicaoDoMes,
                  'Todas as instituições',
                  {for (final instituicao in _instituicoes) instituicao: instituicao},
                  (instituicao) => setState(() => _instituicao = instituicao),
                ),
              Text(
                '${filtradas.length} ${filtradas.length == 1 ? 'movimentação' : 'movimentações'}  ·  '
                'total ${formatarReais(total)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cores.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: Espaco.pequeno),
          if (filtradas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Espaco.grande),
              child: Text('Nenhuma movimentação encontrada.', textAlign: TextAlign.center),
            ),
          // ponytail: linhas sem lista preguiçosa para a página rolar inteira; ok para os ~100 lançamentos de um mês.
          for (final transacao in filtradas) _linha(transacao),
        ],
      ),
    );
  }

  /// Etiqueta com a categoria; clicar abre a lista para trocar.
  Widget _etiquetaDaCategoria(Dados transacao) {
    final atual = transacao['categoria'] as String;
    final cores = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      enabled: widget.habilitado,
      tooltip: 'Trocar categoria',
      initialValue: atual,
      position: PopupMenuPosition.under,
      onSelected: (escolhida) {
        if (escolhida != atual) widget.aoCorrigir(transacao['id'] as int, escolhida);
      },
      itemBuilder: (context) => [
        for (final opcao in widget.categorias)
          PopupMenuItem(
            value: opcao,
            child: Row(children: [
              PontoDeCor(visualDaCategoria(opcao).cor),
              const SizedBox(width: Espaco.pequeno + Espaco.minimo),
              Text(opcao),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(Espaco.pequeno + Espaco.minimo, 6, Espaco.minimo, 6),
        decoration: BoxDecoration(
          color: cores.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Raio.pilula),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PontoDeCor(visualDaCategoria(atual).cor),
            const SizedBox(width: Espaco.pequeno),
            Text(atual, style: Theme.of(context).textTheme.labelMedium),
            Icon(Icons.expand_more_rounded, size: 18, color: cores.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _linha(Dados transacao) {
    final textos = Theme.of(context).textTheme;
    final visual = visualDaCategoria(transacao['categoria'] as String);
    final icone = IconeEmCaixa(visual.icone, tamanho: 38);
    final titulo = Text(nomeLegivel(transacao['descricao'] as String), maxLines: 1, overflow: TextOverflow.ellipsis);
    final forma = transacao['forma'] as String?;
    final detalhe = Text(
      [
        formatarData(transacao['data'] as String),
        if (forma == 'credito') 'Crédito',
        if (forma == 'debito') 'Débito',
        // Compra no crédito não muda o saldo: o dinheiro sai ao pagar a fatura.
        if (forma != 'credito') 'saldo depois: ${formatarReais(transacao['saldo_apos'] as num)}',
      ].join('  ·  '),
      style: textos.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    final valor = TextoValor(transacao['valor'] as num, colorido: true, estilo: textos.titleSmall);
    final categoria = _etiquetaDaCategoria(transacao);
    return LayoutBuilder(
      builder: (context, limites) {
        // Estreita: valor e categoria descem para uma linha própria em vez de espremer a descrição.
        if (limites.maxWidth < Largura.media) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: Espaco.pequeno + Espaco.minimo),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icone,
                const SizedBox(width: Espaco.pequeno + Espaco.minimo),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titulo,
                      detalhe,
                      const SizedBox(height: Espaco.minimo),
                      Row(children: [categoria, const Spacer(), valor]),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: Espaco.pequeno,
          leading: icone,
          title: titulo,
          subtitle: detalhe,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            categoria,
            const SizedBox(width: Espaco.pequeno),
            SizedBox(width: larguraDoValor, child: Align(alignment: Alignment.centerRight, child: valor)),
          ]),
        );
      },
    );
  }
}
