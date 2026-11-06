// Pré-visualizações das seções do painel (flutter widget-preview start) e dados de exemplo usados nos testes.
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'formatacao.dart';
import 'secoes/secao_dicas.dart';
import 'secoes/secao_evolucao.dart';
import 'secoes/secao_gastos.dart';
import 'secoes/secao_metricas.dart';
import 'secoes/secao_movimentacoes.dart';
import 'secoes/secao_previstas.dart';
import 'tela_perfil.dart';
import 'tema.dart';

const exemploCategorias = ['Alimentação', 'Transporte', 'Fatura do cartão', 'Outros'];

const Dados exemploResumo = {
  'saldo_atual': 1500.5,
  'saldo_informado': null,
  'entradas': 3726.87,
  'saidas': 3110.77,
  'sobra_do_mes': 616.1,
  'gastos_por_categoria': {'Fatura do cartão': 343.43, 'Alimentação': 187.81, 'Transporte': 40.43},
  'maiores_estabelecimentos': {'PAO DE ACUCAR': 120.5, '99 TECNOLOGIA': 40.43},
  'movimentacoes_internas': {'Investimentos': -200.41},
};

const List<Dados> exemploPrevistas = [
  {'data': '2026-11-17', 'valor': -25.27, 'descricao': 'Loja de roupas', 'parcela': 1, 'total_parcelas': 3},
  {'data': '2026-11-28', 'valor': -29.33, 'descricao': 'Mercado', 'parcela': 2, 'total_parcelas': 2},
  {'data': '2026-12-17', 'valor': -25.27, 'descricao': 'Loja de roupas', 'parcela': 2, 'total_parcelas': 3},
];

const List<Dados> exemploTransacoes = [
  {
    'id': 1,
    'data': '2026-10-02',
    'valor': -14.28,
    'descricao': 'Compra no débito - PAO DE ACUCAR',
    'categoria': 'Alimentação',
    'saldo_apos': 100,
  },
  {
    'id': 2,
    'data': '2026-10-03',
    'valor': -17.5,
    'descricao': 'Pix - 99 TECNOLOGIA',
    'categoria': 'Transporte',
    'saldo_apos': 82.5,
  },
  {
    'id': 3,
    'data': '2026-10-04',
    'valor': -9.9,
    'descricao': 'Débito em conta',
    'categoria': 'Outros',
    'saldo_apos': 72.6
  },
];

const Dados exemploEvolucao = {
  'meses': [
    {
      'mes': '2026-09',
      'entradas': 3595.88,
      'saidas': 3119.77,
      'sobra_do_mes': 476.11,
      'gastos_por_categoria': {'Alimentação': 260.0}
    },
    {
      'mes': '2026-10',
      'entradas': 3200.88,
      'saidas': 3249.18,
      'sobra_do_mes': -48.3,
      'gastos_por_categoria': {'Alimentação': 187.81}
    },
  ],
  'media_gastos_por_categoria': {'Alimentação': 223.9},
};

const List<Dados> exemploDicas = [
  {
    'mes': '2026-10',
    'criada_em': '2026-10-30T20:10:00',
    'texto': '',
    'itens': [
      {'tipo': 'saldo', 'titulo': 'Comece a reserva', 'texto': 'Guarde parte da sobra todo mês.', 'valor': 300},
      {
        'tipo': 'alerta',
        'titulo': 'Saídas acima das entradas',
        'texto': 'Você gastou mais do que recebeu neste mês.',
        'valor': 48.3
      },
      {
        'tipo': 'cortar',
        'titulo': 'Alimentação subiu',
        'texto': 'Ficou acima da média dos últimos meses; reduza pedidos por aplicativo.',
        'valor': 120
      },
      {'tipo': 'comparar', 'titulo': 'Transporte caiu', 'texto': 'Gastou menos que em setembro.', 'valor': null},
      {
        'tipo': 'cortar',
        'titulo': null,
        'texto':
            'reduzir “Outros” em cerca de R\$ 200,00; cortar “Lazer” em R\$ 50,00; ajustar “Compras” em R\$ 30,00. '
                'Total de cortes sugeridos: R\$ 280,00.',
        'valor': null,
      },
      {'tipo': 'dica', 'titulo': null, 'texto': 'Lazer subiu em relação a setembro.', 'valor': null},
    ],
  },
];

/// Aplica o tema do app (claro ou escuro, conforme a pré-visualização) e dá espaço em volta.
Widget comTemaDoApp(Widget filho) => Builder(
      builder: (context) => Theme(
        data: temaDoApp(MediaQuery.platformBrightnessOf(context)),
        child: Material(child: Padding(padding: const EdgeInsets.all(Espaco.medio), child: filho)),
      ),
    );

void _semAcao() {}

@Preview(name: 'Métricas', group: 'Painel', wrapper: comTemaDoApp, size: Size(1100, 220))
@Preview(
    name: 'Métricas (escuro)',
    group: 'Painel',
    wrapper: comTemaDoApp,
    size: Size(1100, 220),
    brightness: Brightness.dark)
Widget previaMetricas() => const SecaoMetricas(resumo: exemploResumo, mes: '2026-10', nome: 'Ana');

@Preview(name: 'Gastos', group: 'Painel', wrapper: comTemaDoApp, size: Size(560, 420))
Widget previaGastos() => const SecaoGastos(resumo: exemploResumo);

@Preview(name: 'Evolução', group: 'Painel', wrapper: comTemaDoApp, size: Size(560, 420))
Widget previaEvolucao() => const SecaoEvolucao(evolucao: exemploEvolucao);

@Preview(name: 'Movimentações', group: 'Painel', wrapper: comTemaDoApp, size: Size(760, 420))
Widget previaMovimentacoes() => SecaoMovimentacoes(
      transacoes: exemploTransacoes,
      categorias: exemploCategorias,
      habilitado: true,
      aoCorrigir: (id, categoria) {},
      aoReclassificar: _semAcao,
    );

@Preview(name: 'Previstas', group: 'Painel', wrapper: comTemaDoApp, size: Size(460, 360))
Widget previaPrevistas() => const SecaoPrevistas(previstas: exemploPrevistas);

@Preview(name: 'Dicas', group: 'Painel', wrapper: comTemaDoApp, size: Size(460, 760))
Widget previaDicas() => const SecaoDicas(dicas: exemploDicas, mes: '2026-10', habilitado: true, aoGerar: _semAcao);

Future<String?> _salvarSemAcao(Dados dados) async => null;

@Preview(name: 'Minhas informações', group: 'Conta', wrapper: comTemaDoApp, size: Size(760, 720))
Widget previaPerfil() => const TelaPerfil(
      email: 'ana@exemplo.com',
      perfil: {'nome_completo': 'Ana Souza', 'cidade': 'Recife'},
      aoSalvar: _salvarSemAcao,
    );
