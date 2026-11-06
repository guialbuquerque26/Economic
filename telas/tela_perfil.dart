import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'formatacao.dart';
import 'secoes/componentes.dart';
import 'tema.dart';

const _chaves = ['nome_completo', 'apelido', 'telefone', 'nascimento', 'cidade', 'estado'];
const _larguraDaTela = 640.0;

/// Informações pessoais da conta, todas opcionais. [aoSalvar] devolve a mensagem de erro, ou null se deu certo.
class TelaPerfil extends StatefulWidget {
  const TelaPerfil({super.key, required this.email, required this.perfil, required this.aoSalvar});

  final String? email;
  final Dados perfil;
  final Future<String?> Function(Dados dados) aoSalvar;

  @override
  State<TelaPerfil> createState() => _EstadoTelaPerfil();
}

class _EstadoTelaPerfil extends State<TelaPerfil> {
  final _formulario = GlobalKey<FormState>();
  late final _campos = {
    for (final chave in _chaves) chave: TextEditingController(text: widget.perfil[chave] as String? ?? ''),
  };
  late String? _nome = nomeParaExibir(widget.perfil);
  bool _salvando = false;

  @override
  void dispose() {
    for (final campo in _campos.values) {
      campo.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _salvando = true);
    final dados = {for (final campo in _campos.entries) campo.key: campo.value.text.trim()};
    final erro = await widget.aoSalvar(dados);
    if (!mounted) return;
    setState(() {
      _salvando = false;
      if (erro == null) _nome = nomeParaExibir(dados);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro ?? 'Informações salvas.')));
  }

  String? _validarTelefone(String? texto) {
    final digitos = texto!.replaceAll(RegExp(r'\D'), '').length;
    return digitos == 0 || digitos >= 10 ? null : 'Digite o DDD e o número.';
  }

  String? _validarNascimento(String? texto) =>
      texto!.isEmpty || dataDeNascimentoValida(texto, DateTime.now()) ? null : 'Use uma data válida, como 25/03/1990.';

  TextInputFormatter _mascara(String Function(String) aplicar) => TextInputFormatter.withFunction((_, digitado) {
        final texto = aplicar(digitado.text);
        return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
      });

  Widget _campo(
    String chave,
    String rotulo, {
    String? exemplo,
    TextInputType? teclado,
    String? preenchimento,
    TextInputFormatter? mascara,
    FormFieldValidator<String>? validar,
  }) =>
      TextFormField(
        controller: _campos[chave],
        keyboardType: teclado,
        autofillHints: preenchimento == null ? null : [preenchimento],
        inputFormatters: mascara == null ? null : [mascara],
        validator: validar,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: rotulo, hintText: exemplo),
      );

  Widget _dupla(Widget esquerda, Widget direita, {int pesoEsquerda = 1}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: pesoEsquerda, child: esquerda),
          const SizedBox(width: Espaco.medio),
          Expanded(child: direita),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas informações')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Espaco.grande, Espaco.pequeno, Espaco.grande, Espaco.grande),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _larguraDaTela),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Cartao(
                  filho: Row(
                    children: [
                      AvatarDaPessoa(nome: _nome ?? widget.email, raio: 32),
                      const SizedBox(width: Espaco.medio),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_nome != null) Text(_nome!, style: textos.headlineSmall),
                            if (widget.email != null)
                              Text(widget.email!, style: textos.bodyMedium?.copyWith(color: cores.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Espaco.medio),
                Secao(
                  titulo: 'Seus dados',
                  filho: Form(
                    key: _formulario,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Preencha só o que quiser. Essas informações ficam guardadas na sua conta.',
                            style: textos.bodyMedium?.copyWith(color: cores.onSurfaceVariant),
                          ),
                          const SizedBox(height: Espaco.grande),
                          _campo('nome_completo', 'Nome completo',
                              teclado: TextInputType.name, preenchimento: AutofillHints.name),
                          const SizedBox(height: Espaco.medio),
                          _campo('apelido', 'Como prefere ser chamado', teclado: TextInputType.name),
                          const SizedBox(height: Espaco.medio),
                          _dupla(
                            _campo('telefone', 'Telefone',
                                exemplo: '(11) 91234-5678',
                                teclado: TextInputType.phone,
                                preenchimento: AutofillHints.telephoneNumber,
                                mascara: _mascara(mascararTelefone),
                                validar: _validarTelefone),
                            _campo('nascimento', 'Data de nascimento',
                                exemplo: 'DD/MM/AAAA',
                                teclado: TextInputType.number,
                                preenchimento: AutofillHints.birthday,
                                mascara: _mascara(mascararData),
                                validar: _validarNascimento),
                          ),
                          const SizedBox(height: Espaco.medio),
                          _dupla(
                            _campo('cidade', 'Cidade', preenchimento: AutofillHints.addressCity),
                            _campo('estado', 'Estado', preenchimento: AutofillHints.addressState),
                            pesoEsquerda: 2,
                          ),
                          const SizedBox(height: Espaco.grande),
                          Align(
                            alignment: Alignment.centerRight,
                            child: MolaAoPressionar(
                              child: FilledButton(
                                onPressed: _salvando ? null : _salvar,
                                child: Text(_salvando ? 'Salvando...' : 'Salvar'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
