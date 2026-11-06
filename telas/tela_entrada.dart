import 'package:flutter/material.dart';

import 'secoes/componentes.dart';
import 'tema.dart';

/// Entrar ou criar conta. As ações devolvem a mensagem de erro para mostrar, ou null se deu certo.
class TelaEntrada extends StatefulWidget {
  const TelaEntrada({super.key, required this.aoEntrar, required this.aoCriarConta});

  final Future<String?> Function(String email, String senha) aoEntrar;
  final Future<String?> Function(String email, String senha) aoCriarConta;

  @override
  State<TelaEntrada> createState() => _EstadoTelaEntrada();
}

class _EstadoTelaEntrada extends State<TelaEntrada> {
  static const _larguraLadoALado = 780.0;

  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _ocupado = false;
  String? _mensagem;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  String? _validar() {
    if (!_email.text.contains('@')) return 'Digite um e-mail válido.';
    if (_senha.text.length < 6) return 'A senha precisa ter pelo menos 6 caracteres.';
    return null;
  }

  Future<void> _enviar(Future<String?> Function(String email, String senha) acao) async {
    final invalido = _validar();
    if (invalido != null) {
      setState(() => _mensagem = invalido);
      return;
    }
    setState(() {
      _ocupado = true;
      _mensagem = null;
    });
    final mensagem = await acao(_email.text, _senha.text);
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _mensagem = mensagem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final formulario = _formularioDeEntrada(tema);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Espaco.grande),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: EntradaSuave(
              child: LayoutBuilder(
                builder: (context, limites) {
                  if (limites.maxWidth < _larguraLadoALado) {
                    return Center(
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: formulario),
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: _boasVindas(tema)),
                      const SizedBox(width: Espaco.enorme + Espaco.grande),
                      SizedBox(width: 400, child: formulario),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _boasVindas(ThemeData tema) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Marca(tamanho: 40, estilo: tema.textTheme.headlineSmall),
          const SizedBox(height: Espaco.enorme),
          Text('Entenda para onde vai o seu dinheiro.', style: tema.textTheme.displaySmall),
          const SizedBox(height: Espaco.medio),
          Text(
            'Importe o extrato do seu banco e receba dicas claras de onde cortar e do que fazer com o saldo.',
            style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Espaco.grande),
          Row(
            children: [
              Icon(Icons.lock_rounded, size: 18, color: tema.colorScheme.onSurfaceVariant),
              const SizedBox(width: Espaco.pequeno),
              Expanded(child: Text('Seus extratos ficam neste computador', style: tema.textTheme.titleSmall)),
            ],
          ),
        ],
      );

  Widget _formularioDeEntrada(ThemeData tema) => Cartao(
        preenchimento: const EdgeInsets.all(Espaco.grande + Espaco.pequeno),
        filho: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Que bom ter você aqui', style: tema.textTheme.titleLarge),
              const SizedBox(height: Espaco.pequeno),
              const Text('Entre para usar a análise inteligente dos seus gastos.'),
              const SizedBox(height: Espaco.grande),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: Espaco.medio),
              TextField(
                controller: _senha,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Senha'),
                onSubmitted: (_) => _ocupado ? null : _enviar(widget.aoEntrar),
              ),
              if (_mensagem != null) ...[
                const SizedBox(height: Espaco.medio),
                Text(_mensagem!, style: TextStyle(color: tema.colorScheme.error)),
              ],
              const SizedBox(height: Espaco.grande),
              MolaAoPressionar(
                child: FilledButton(
                  onPressed: _ocupado ? null : () => _enviar(widget.aoEntrar),
                  child: const Text('Entrar'),
                ),
              ),
              const SizedBox(height: Espaco.pequeno),
              OutlinedButton(
                onPressed: _ocupado ? null : () => _enviar(widget.aoCriarConta),
                child: const Text('Criar conta'),
              ),
              if (_ocupado) ...[const SizedBox(height: Espaco.medio), const LinearProgressIndicator()],
              const SizedBox(height: Espaco.grande),
              Text(
                'Seus extratos ficam só neste computador. Para classificar gastos e gerar dicas, enviamos a um '
                'serviço de inteligência artificial nomes de estabelecimentos, totais do mês e saldos. Tentamos '
                'deixar de fora nomes de pessoas e CPFs, mas essa separação é automática e pode falhar. O que '
                'você preencher em "Minhas informações" fica guardado na sua conta. Se usar a conexão opcional com o '
                'banco, seus dados de acesso também ficam na sua conta, criptografados.',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
}
