import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'estado_financas.dart';
import 'formatacao.dart';
import 'preferencias.dart';
import 'secoes/componentes.dart';
import 'secoes/secao_dicas.dart';
import 'secoes/secao_evolucao.dart';
import 'secoes/secao_gastos.dart';
import 'secoes/secao_metricas.dart';
import 'secoes/secao_movimentacoes.dart';
import 'secoes/secao_previstas.dart';
import 'secoes/seletor_de_mes.dart';
import 'tela_conexao.dart';
import 'tela_perfil.dart';
import 'tema.dart';

const _intervaloDaBusca = Duration(hours: 3);

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({
    super.key,
    required this.estado,
    this.aoSair,
    this.tema,
    this.email,
    this.perfil = const {},
    this.aoSalvarPerfil,
  });

  final EstadoFinancas estado;
  final Future<void> Function()? aoSair;
  final PreferenciaTema? tema;
  final String? email;
  final Dados perfil;
  final Future<String?> Function(Dados dados)? aoSalvarPerfil;

  @override
  State<TelaPrincipal> createState() => _EstadoTelaPrincipal();
}

class _EstadoTelaPrincipal extends State<TelaPrincipal> {
  final _chaveDasDicas = GlobalKey();
  Timer? _buscaPeriodica;

  EstadoFinancas get _estado => widget.estado;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  Future<void> _abrir() async {
    await _rodar(_estado.carregar()); // a primeira chamada abre o serviço se ele ainda não estiver rodando
    await _rodar(_estado.carregarConexao());
    await _rodar(_estado.buscarConexao(_perguntarFonte));
    if (mounted) _buscaPeriodica = Timer.periodic(_intervaloDaBusca, (_) => _buscarNoIntervalo());
  }

  /// Pula a vez se o app estiver ocupado, como com a pergunta de fonte aberta.
  void _buscarNoIntervalo() {
    if (!_estado.carregando) _rodar(_estado.buscarConexao(_perguntarFonte));
  }

  @override
  void dispose() {
    _buscaPeriodica?.cancel();
    super.dispose();
  }

  Future<Map<String, String>?> _perguntarFonte(List<Dados> pendentes) async =>
      mounted ? perguntarFonte(context, pendentes) : null;

  /// Espera a ação terminar e mostra a mensagem que ela devolver.
  Future<void> _rodar(Future<String?> acao, {Duration duracao = const Duration(seconds: 4)}) async {
    final mensagem = await acao;
    if (mensagem == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), duration: duracao));
  }

  Future<void> _importar() async {
    final escolha = await FilePicker.platform.pickFiles(
      dialogTitle: 'Escolha os extratos do seu banco',
      type: FileType.custom,
      allowedExtensions: ['ofx', 'csv', 'xlsx', 'pdf', 'txt'],
      allowMultiple: true,
    );
    final caminhos = [
      for (final arquivo in escolha?.files ?? <PlatformFile>[])
        if (arquivo.path != null) arquivo.path!,
    ];
    if (caminhos.isNotEmpty) await _rodar(_estado.importar(caminhos, _perguntarFonte), duracao: const Duration(seconds: 10));
  }

  Future<void> _excluirMes() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('Excluir ${formatarMesPorExtenso(_estado.mes!)}?'),
        content: Text(
          'Todas as movimentações deste mês serão apagadas e não poderão ser recuperadas. '
          'Se precisar, é só importar o extrato de novo. '
          'As dicas já geradas continuam guardadas neste computador e voltam a aparecer se você importar o mês de novo.'
          '${_estado.conexaoAtiva ? ' Este mês não será buscado de novo pela conexão com o banco.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(contexto).colorScheme.error,
              foregroundColor: Theme.of(contexto).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmado == true) await _rodar(_estado.excluirMes());
  }

  Future<void> _informarSaldo() async {
    final controle = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Saldo atual da conta'),
        content: TextField(
          controller: controle,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(prefixText: 'R\$ ', hintText: '0,00'),
          onSubmitted: (valor) => Navigator.pop(contexto, valor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(contexto, controle.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (texto == null) return;
    final valor = lerReais(texto);
    await _rodar(valor == null ? Future.value('Valor inválido. Use o formato 1234,56.') : _estado.informarSaldo(valor));
  }

  void _abrirConexao() {
    _rodar(_estado.carregarConexao());
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TelaConexao(estado: _estado)));
  }

  void _abrirPerfil() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TelaPerfil(email: widget.email, perfil: widget.perfil, aoSalvar: widget.aoSalvarPerfil!),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _estado,
      builder: (context, _) {
        final ocupado = _estado.carregando;
        final mes = _estado.mes;
        final largura = MediaQuery.sizeOf(context).width;
        final estreita = largura < Largura.media;
        // Os meses sobem para o topo só quando cabem ao lado dos botões; senão abrem o painel.
        final mesNoTopo = mes != null && largura >= Largura.larga;
        // A barra do topo acompanha a coluna dos cartões, mesmo em janela maximizada.
        final margem = ((largura - Largura.maxima) / 2).clamp(Espaco.grande, double.infinity);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: margem,
            title: Row(
              children: [
                Marca(estilo: Theme.of(context).textTheme.titleLarge, comNome: !estreita),
                if (mesNoTopo) ...[
                  const SizedBox(width: Espaco.grande),
                  Flexible(child: Align(alignment: Alignment.centerLeft, child: _linhaDoMes(mes, ocupado))),
                ],
              ],
            ),
            actions: [
              MolaAoPressionar(
                ativa: !ocupado,
                child: estreita
                    ? IconButton.filled(
                        tooltip: 'Importar extratos',
                        icon: const Icon(Icons.upload_file_rounded),
                        onPressed: ocupado ? null : _importar,
                      )
                    : FilledButton.icon(
                        onPressed: ocupado ? null : _importar,
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Importar extratos'),
                      ),
              ),
              if (widget.tema != null) ...[
                const SizedBox(width: Espaco.pequeno + Espaco.minimo),
                _MenuDoUsuario(
                  tema: widget.tema!,
                  email: widget.email,
                  nome: nomeParaExibir(widget.perfil),
                  aoAbrirConexao: widget.aoSalvarPerfil == null ? null : _abrirConexao,
                  aoAbrirPerfil: widget.aoSalvarPerfil == null ? null : _abrirPerfil,
                  aoSair: widget.aoSair,
                ),
              ],
              SizedBox(width: margem),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: SizedBox(height: 3, child: ocupado ? const LinearProgressIndicator() : null),
            ),
          ),
          body: mes == null ? _semDados(ocupado) : _painel(mes, ocupado, mostrarMes: !mesNoTopo),
        );
      },
    );
  }

  Widget _linhaDoMes(String mes, bool ocupado) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SeletorDeMes(
              meses: _estado.meses,
              mes: mes,
              habilitado: !ocupado,
              aoEscolher: _escolherMes,
            ),
          ),
          const SizedBox(width: Espaco.minimo),
          MolaAoPressionar(
            ativa: !ocupado,
            child: IconButton(
              tooltip: 'Excluir este mês',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: ocupado ? null : _excluirMes,
            ),
          ),
        ],
      );

  void _escolherMes(String mes) {
    if (mes != _estado.mes) _rodar(_estado.escolherMes(mes));
  }

  /// Rola com calma até a seção de dicas.
  void _verDicas() {
    final contexto = _chaveDasDicas.currentContext;
    if (contexto == null) return;
    Scrollable.ensureVisible(contexto, duration: Movimento.de(context, Movimento.medio), curve: Movimento.saida);
  }

  /// Primeiro o mês em palavras; depois o que fazer, para onde foi o dinheiro e os meses; por fim as movimentações.
  Widget _painel(String mes, bool ocupado, {required bool mostrarMes}) {
    final dica = ultimaDicaDoMes(_estado.dicas, mes);
    final conselho = dica == null ? null : conselhoDoMes(dica);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Espaco.grande, Espaco.pequeno, Espaco.grande, Espaco.enorme),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Largura.maxima),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mostrarMes) ...[
                Align(alignment: Alignment.centerLeft, child: _linhaDoMes(mes, ocupado)),
                const SizedBox(height: Espaco.medio),
              ],
              SecaoMetricas(
                resumo: _estado.resumo!,
                mes: mes,
                nome: nomeParaExibir(widget.perfil),
                conselho: conselho,
                habilitado: !ocupado,
                aoGerarDicas: () => _rodar(_estado.gerarDicas()),
                aoVerDicas: _verDicas,
                aoInformarSaldo: _informarSaldo,
              ),
              const SizedBox(height: Espaco.medio),
              _colunasDoMes(mes, ocupado),
              const SizedBox(height: Espaco.medio),
              if (_estado.previstas.isNotEmpty) ...[
                SecaoPrevistas(previstas: _estado.previstas),
                const SizedBox(height: Espaco.medio),
              ],
              SecaoMovimentacoes(
                transacoes: _estado.transacoes,
                categorias: _estado.categorias,
                habilitado: !ocupado,
                aoCorrigir: (id, categoria) => _rodar(_estado.corrigirCategoria(id, categoria)),
                aoReclassificar: () => _rodar(_estado.reclassificar(), duracao: const Duration(seconds: 8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dicas e gastos lado a lado, cada um na altura do próprio conteúdo; os meses ocupam a largura toda.
  Widget _colunasDoMes(String mes, bool ocupado) {
    final dicas = KeyedSubtree(
      key: _chaveDasDicas,
      child: SecaoDicas(
        dicas: _estado.dicas,
        mes: mes,
        habilitado: !ocupado,
        aoGerar: () => _rodar(_estado.gerarDicas()),
      ),
    );
    final gastos = SecaoGastos(resumo: _estado.resumo!);
    final maiores = _estado.resumo!['maiores_estabelecimentos'] as Dados;
    final lugares = [
      if (maiores.isNotEmpty) ...[const SizedBox(height: Espaco.medio), SecaoLugares(maiores: maiores)],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, limites) {
            if (limites.maxWidth < Largura.larga) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [dicas, const SizedBox(height: Espaco.medio), gastos, ...lugares],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [dicas, ...lugares]),
                ),
                const SizedBox(width: Espaco.medio),
                Expanded(child: gastos),
              ],
            );
          },
        ),
        const SizedBox(height: Espaco.medio),
        SecaoEvolucao(evolucao: _estado.evolucao!, mes: mes, aoEscolherMes: ocupado ? null : _escolherMes),
      ],
    );
  }

  Widget _semDados(bool ocupado) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final nome = nomeParaExibir(widget.perfil);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Espaco.grande),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: EntradaSuave(
            child: Cartao(
              preenchimento: const EdgeInsets.all(Espaco.enorme),
              filho: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nome == null ? 'Que bom ter você aqui' : '$nome, que bom ter você aqui',
                      style: textos.displaySmall, textAlign: TextAlign.center),
                  const SizedBox(height: Espaco.pequeno + Espaco.minimo),
                  Text('Importe o extrato da sua conta para começar.',
                      style: textos.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: Espaco.pequeno),
                  Text(
                    'Aceita OFX, CSV, Excel ou PDF de qualquer banco. Se o banco oferecer, prefira o OFX.',
                    style: textos.bodyMedium?.copyWith(color: cores.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Espaco.grande),
                  MolaAoPressionar(
                    ativa: !ocupado,
                    child: FilledButton.icon(
                      onPressed: ocupado ? null : _importar,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Importar extrato'),
                    ),
                  ),
                  const SizedBox(height: Espaco.grande),
                  const AvisoDePrivacidade(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo com a inicial da pessoa; abre o menu da conta com as informações pessoais, o tema e a saída.
class _MenuDoUsuario extends StatelessWidget {
  const _MenuDoUsuario({
    required this.tema,
    this.email,
    this.nome,
    this.aoAbrirConexao,
    this.aoAbrirPerfil,
    this.aoSair,
  });

  final PreferenciaTema tema;
  final String? email;
  final String? nome;
  final VoidCallback? aoAbrirConexao;
  final VoidCallback? aoAbrirPerfil;
  final Future<void> Function()? aoSair;

  static const _opcoes = [
    (ThemeMode.system, 'Automático (igual ao Windows)'),
    (ThemeMode.light, 'Claro'),
    (ThemeMode.dark, 'Escuro'),
  ];

  PopupMenuItem<ThemeMode> _acao(IconData icone, String texto, VoidCallback aoTocar) => PopupMenuItem(
        onTap: aoTocar,
        child: Row(
          children: [
            Icon(icone, size: 20),
            const SizedBox(width: Espaco.pequeno + Espaco.minimo),
            Flexible(child: Text(texto)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Sua conta',
      position: PopupMenuPosition.under,
      onSelected: tema.escolher,
      itemBuilder: (context) => [
        if (email != null) ...[
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nome != null) Text(nome!, style: textos.titleSmall?.copyWith(color: cores.onSurface)),
                Text(email!, style: textos.bodySmall?.copyWith(color: cores.onSurfaceVariant)),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        if (aoAbrirConexao != null) _acao(Icons.account_balance_rounded, 'Conexão com o banco', aoAbrirConexao!),
        if (aoAbrirPerfil != null) ...[
          _acao(Icons.badge_rounded, 'Minhas informações', aoAbrirPerfil!),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          enabled: false,
          height: 32,
          child: Text('Tema', style: textos.labelMedium?.copyWith(color: cores.onSurfaceVariant)),
        ),
        for (final (modo, nome) in _opcoes)
          CheckedPopupMenuItem(value: modo, checked: tema.value == modo, child: Text(nome)),
        if (aoSair != null) ...[
          const PopupMenuDivider(),
          _acao(Icons.logout_rounded, 'Sair da conta', aoSair!),
        ],
      ],
      child: MolaAoPressionar(child: AvatarDaPessoa(nome: nome ?? email)),
    );
  }
}
