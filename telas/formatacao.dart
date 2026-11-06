/// Dados como chegam do serviço (JSON).
typedef Dados = Map<String, dynamic>;

/// "R$ 1.234,50". Sem [centavos], arredonda para reais inteiros, para caber em gráficos.
String formatarReais(num valor, {bool centavos = true}) {
  final sinal = valor < 0 ? '-' : '';
  final [inteiro, ...resto] = valor.abs().toStringAsFixed(centavos ? 2 : 0).split('.');
  final milhares = inteiro.replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');
  return '${sinal}R\$ $milhares${resto.isEmpty ? '' : ',${resto.single}'}';
}

String formatarData(String iso) {
  final partes = iso.substring(0, 10).split('-');
  return '${partes[2]}/${partes[1]}/${partes[0]}';
}

String formatarMes(String mes) => '${mes.substring(5)}/${mes.substring(0, 4)}';

const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
const _semAcento = 'aaaaaeeeeiiiiooooouuuuc';

/// Minúsculas e sem acento, para a busca achar "credito" em "Crédito".
String semAcento(String texto) => [
      for (final letra in texto.toLowerCase().split(''))
        _comAcento.contains(letra) ? _semAcento[_comAcento.indexOf(letra)] : letra,
    ].join();

/// Aceita "1.234,56" (padrão brasileiro) ou "1234.56". Devolve null se não for número.
double? lerReais(String texto) {
  final limpo = texto.trim();
  return double.tryParse(limpo.contains(',') ? limpo.replaceAll('.', '').replaceAll(',', '.') : limpo);
}

const _nomesDosMeses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', //
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// "2026-10" vira "outubro de 2026".
String formatarMesPorExtenso(String mes) =>
    '${_nomesDosMeses[int.parse(mes.substring(5)) - 1]} de ${mes.substring(0, 4)}';

String maiusculaInicial(String texto) => texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

/// "2026-10" vira "Out 26".
String formatarMesCurto(String mes) =>
    '${maiusculaInicial(_nomesDosMeses[int.parse(mes.substring(5)) - 1].substring(0, 3))} ${mes.substring(2, 4)}';

/// Como foi o mês, numa frase de gente. O valor vem à parte para receber destaque.
/// Em mês em andamento o salário pode nem ter entrado: a frase fala do gasto até agora e do [saldo], se for conhecido.
({String inicio, String? valor, String fim}) fraseDoMes(
  String mes,
  num sobra, {
  String? nome,
  bool emAndamento = false,
  num? saldo,
}) {
  final nomeDoMes = _nomesDosMeses[int.parse(mes.substring(5)) - 1];
  final abertura = nome == null ? 'Em $nomeDoMes' : '$nome, em $nomeDoMes';
  if (sobra == 0) return (inicio: '$abertura entrou e saiu o mesmo valor.', valor: null, fim: '');
  if (sobra > 0) return (inicio: '$abertura sobraram ', valor: formatarReais(sobra), fim: '.');
  final fim = !emAndamento
      ? ' a mais do que recebeu.'
      : (saldo != null && saldo > 0 ? ' até agora e ainda tem ${formatarReais(saldo)}.' : ' até agora.');
  return (inicio: '$abertura você gastou ', valor: formatarReais(sobra.abs()), fim: fim);
}

/// A IA às vezes escreve "48,30 R$" ou "R$100"; aqui todo valor fica como "R$ 48,30".
String valoresNoPadrao(String texto) => texto
    .replaceAll(RegExp('[  ]'), ' ')
    .replaceAllMapped(RegExp(r'(?<![\d.,$])(?<!R\$ )(\d[\d.,]*) *R\$'), (achado) => 'R\$ ${achado[1]}')
    .replaceAll(RegExp(r'R\$(?=\d)'), r'R$ ')
    .replaceAllMapped(RegExp(r'(R\$ \d+)\.(\d{2})(?!\d)'), (achado) => '${achado[1]},${achado[2]}')
    .replaceAll(RegExp(r' +,'), ',');

/// Valor em reais dentro de um texto que já passou por [valoresNoPadrao].
final valorNoTexto = RegExp(r'R\$ \d+(?:[.,]\d+)*');

/// Linha de uma dica: a categoria citada entre aspas e o valor que fecha a frase, quando houver.
typedef LinhaDaDica = ({String texto, String? categoria, String? valor});

/// Separa o texto de uma dica em linhas. Texto simples vem numa linha só, sem categoria nem valor.
List<LinhaDaDica> linhasDaDica(String texto) {
  final linhas = [
    for (final linha in valoresNoPadrao(texto).split('\n'))
      if (linha.trim().isNotEmpty) linha.replaceFirst(RegExp(r'^\s*[•*-]\s*'), '').trim(),
  ];
  final partes = linhas.length == 1 ? _partesDaFrase(linhas.single) : linhas;
  if (partes.length == 1) return [(texto: maiusculaInicial(partes.single), categoria: null, valor: null)];
  return partes.map(_lerLinha).toList();
}

/// Três ou mais trechos separados por ";" formam uma lista; uma frase depois do último vira item próprio.
List<String> _partesDaFrase(String frase) {
  final trechos = [
    for (final trecho in frase.split(';'))
      if (trecho.trim().isNotEmpty) trecho.trim(),
  ];
  if (trechos.length < 3) return [frase];
  return [...trechos.take(trechos.length - 1), ...trechos.last.split(RegExp(r'(?<=\.)\s+(?=[A-ZÀ-Ú])'))];
}

final _ligacaoNoFim = RegExp(r'(\s+(em|de|para|por)(\s+cerca\s+de)?|:)\s*$');

LinhaDaDica _lerLinha(String linha) {
  final categoria = RegExp('[“"]([^”"]+)[”"]').firstMatch(linha)?[1];
  final texto = linha.replaceAll(RegExp('[“”"]'), '');
  final valor = valorNoTexto.allMatches(texto).singleOrNull;
  final fechaAFrase = valor != null && RegExp(r'^\.?$').hasMatch(texto.substring(valor.end));
  if (!fechaAFrase) return (texto: maiusculaInicial(texto), categoria: categoria, valor: null);
  // O valor vai para a coluna da direita: sem ligação solta como "Cortar Lazer em".
  final inicio = texto.substring(0, valor.start).replaceFirst(_ligacaoNoFim, '').trim();
  return (texto: maiusculaInicial(inicio), categoria: categoria, valor: valor[0]);
}

const _palavrasPequenas = {'DE', 'DA', 'DO', 'DOS', 'DAS', 'E'};
const _siglas = {'BCO', 'CPF', 'CNPJ', 'DOC', 'PIX', 'TED'};

/// Extratos vêm em maiúsculas: "PAO DE ACUCAR" aparece como "Pao de Acucar".
String nomeLegivel(String texto) =>
    texto.replaceAllMapped(RegExp(r'(?<!\p{L})\p{Lu}{2,}(?!\p{L})', unicode: true), (achado) {
      final palavra = achado[0]!;
      if (_palavrasPequenas.contains(palavra)) return palavra.toLowerCase();
      if (palavra.length <= 2 || _siglas.contains(palavra)) return palavra;
      return maiusculaInicial(palavra.toLowerCase());
    });

/// Conselho em uma frase para a abertura do painel: o assunto da dica e a primeira linha do texto.
String resumoDaDica(String? titulo, String texto) {
  final linhas = linhasDaDica(texto);
  if (linhas.isEmpty) return titulo ?? '';
  final linha = linhas.first;
  final frase = linha.valor == null ? linha.texto : '${linha.texto}: ${linha.valor}.';
  return titulo == null ? frase : '$titulo. $frase';
}

/// Como chamar a pessoa no app: o nome que ela preferiu ou, sem ele, o primeiro nome.
String? nomeParaExibir(Dados perfil) {
  final preferido = (perfil['apelido'] as String?)?.trim() ?? '';
  if (preferido.isNotEmpty) return preferido;
  final completo = (perfil['nome_completo'] as String?)?.trim() ?? '';
  return completo.isEmpty ? null : completo.split(RegExp(r'\s+')).first;
}

String _soDigitos(String texto, int maximo) {
  final digitos = texto.replaceAll(RegExp(r'\D'), '');
  return digitos.length > maximo ? digitos.substring(0, maximo) : digitos;
}

/// "01011990" vira "01/01/1990" enquanto a pessoa digita.
String mascararData(String texto) {
  final saida = StringBuffer();
  for (final (posicao, digito) in _soDigitos(texto, 8).split('').indexed) {
    if (posicao == 2 || posicao == 4) saida.write('/');
    saida.write(digito);
  }
  return saida.toString();
}

/// "11912345678" vira "(11) 91234-5678"; o fixo, com um dígito a menos, vira "(11) 3234-5678".
String mascararTelefone(String texto) {
  final digitos = _soDigitos(texto, 11);
  if (digitos.length <= 2) return digitos.isEmpty ? '' : '($digitos';
  final corte = digitos.length == 11 ? 7 : 6;
  if (digitos.length <= corte) return '(${digitos.substring(0, 2)}) ${digitos.substring(2)}';
  return '(${digitos.substring(0, 2)}) ${digitos.substring(2, corte)}-${digitos.substring(corte)}';
}

/// Data "DD/MM/AAAA" que existe no calendário, de 1900 até [hoje].
bool dataDeNascimentoValida(String texto, DateTime hoje) {
  final partes = texto.split('/').map(int.tryParse).toList();
  if (partes.length != 3 || partes.contains(null)) return false;
  final [dia!, mes!, ano!] = partes;
  final data = DateTime(ano, mes, dia);
  return data.day == dia && data.month == mes && ano >= 1900 && !data.isAfter(hoje);
}
