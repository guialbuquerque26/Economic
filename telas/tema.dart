import 'package:flutter/material.dart';

/// Design system do app: tudo que é cor, espaço, forma e movimento sai daqui.
const corDeAcao = Color(0xFFFF6A3D);
const _textoSobreAcao = Color(0xFF2A1208);

abstract final class Espaco {
  static const minimo = 4.0;
  static const pequeno = 8.0;
  static const medio = 16.0;
  static const grande = 24.0;
  static const enorme = 40.0;
}

abstract final class Raio {
  static const pequeno = 12.0;
  static const medio = 18.0;
  static const grande = 28.0;
  static const pilula = 999.0;
}

/// Larguras em que o painel muda de forma.
abstract final class Largura {
  static const media = 600.0;
  static const larga = 1000.0;
  static const maxima = 1280.0;
}

/// Durações e curvas do app. Com animações desligadas no sistema, tudo acontece na hora.
abstract final class Movimento {
  static const rapido = Duration(milliseconds: 180);
  static const medio = Duration(milliseconds: 420);
  static const lento = Duration(milliseconds: 800);
  static const saida = Curves.easeOutExpo;

  static Duration de(BuildContext context, Duration duracao) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duracao;
}

/// Algarismos de largura fixa: valores alinham em coluna.
const algarismosAlinhados = [FontFeature.tabularFigures()];

/// Cor e ícone de cada categoria: a mesma marca na lista de gastos, nas movimentações e na evolução.
typedef Visual = ({Color cor, IconData icone});

const _visuaisDasCategorias = <String, Visual>{
  'Alimentação': (cor: Color(0xFF8D6E4E), icone: Icons.restaurant_rounded),
  'Contas da casa': (cor: Color(0xFF3A86E8), icone: Icons.home_rounded),
  'Transporte': (cor: Color(0xFF14A38B), icone: Icons.directions_car_rounded),
  'Saúde': (cor: Color(0xFFE5484D), icone: Icons.favorite_rounded),
  'Lazer': (cor: Color(0xFFD6409F), icone: Icons.celebration_rounded),
  'Compras': (cor: Color(0xFF8E4EC6), icone: Icons.shopping_bag_rounded),
  'Pix para pessoas': (cor: Color(0xFF0091B3), icone: Icons.people_rounded),
  'Receitas': (cor: Color(0xFF30A46C), icone: Icons.trending_up_rounded),
  'Investimentos': (cor: Color(0xFF5B5BD6), icone: Icons.savings_rounded),
  'Entre minhas contas': (cor: Color(0xFF7C7A88), icone: Icons.swap_horiz_rounded),
  'Fatura do cartão': (cor: Color(0xFFC98A00), icone: Icons.credit_card_rounded),
};
const _visualPadrao = (cor: Color(0xFF8B8D98), icone: Icons.more_horiz_rounded);

Visual visualDaCategoria(String categoria) => _visuaisDasCategorias[categoria] ?? _visualPadrao;

/// Verde e vermelho dos valores, com versões próprias para o modo escuro.
@immutable
class CoresFinanceiras extends ThemeExtension<CoresFinanceiras> {
  const CoresFinanceiras({required this.positivo, required this.negativo});

  final Color positivo;
  final Color negativo;

  static const claro = CoresFinanceiras(positivo: Color(0xFF23774A), negativo: Color(0xFFA8174A));
  static const escuro = CoresFinanceiras(positivo: Color(0xFF86D6A6), negativo: Color(0xFFFF9FBC));

  Color doValor(num valor) => valor < 0 ? negativo : positivo;

  @override
  CoresFinanceiras copyWith({Color? positivo, Color? negativo}) =>
      CoresFinanceiras(positivo: positivo ?? this.positivo, negativo: negativo ?? this.negativo);

  @override
  CoresFinanceiras lerp(CoresFinanceiras? outra, double t) => outra == null
      ? this
      : CoresFinanceiras(
          positivo: Color.lerp(positivo, outra.positivo, t)!, negativo: Color.lerp(negativo, outra.negativo, t)!);
}

extension TemaDoContexto on BuildContext {
  CoresFinanceiras get coresFinanceiras => Theme.of(this).extension<CoresFinanceiras>()!;
}

/// Sombra macia dos cartões: sempre para baixo, na cor do fundo.
List<BoxShadow> sombraDoCartao(Brightness brilho) => [
      BoxShadow(
        color: const Color(0xFF5A3A1E).withValues(alpha: brilho == Brightness.light ? 0.08 : 0.28),
        offset: const Offset(0, 8),
        blurRadius: 24,
      ),
    ];

TextTheme _textos(TextTheme base, Color cor) {
  TextStyle? estilo(TextStyle? origem, double tamanho, FontWeight peso, {double altura = 1.3}) =>
      origem?.copyWith(fontSize: tamanho, fontWeight: peso, height: altura, letterSpacing: 0);
  return base
      .copyWith(
        displaySmall: estilo(base.displaySmall, 34, FontWeight.w800, altura: 1.18),
        headlineSmall: estilo(base.headlineSmall, 26, FontWeight.w800, altura: 1.2),
        titleLarge: estilo(base.titleLarge, 21, FontWeight.w800, altura: 1.25),
        titleMedium: estilo(base.titleMedium, 17, FontWeight.w700),
        titleSmall: estilo(base.titleSmall, 15, FontWeight.w700),
        bodyLarge: estilo(base.bodyLarge, 16, FontWeight.w400, altura: 1.5),
        bodyMedium: estilo(base.bodyMedium, 15, FontWeight.w400, altura: 1.45),
        bodySmall: estilo(base.bodySmall, 13, FontWeight.w400, altura: 1.4),
        labelLarge: estilo(base.labelLarge, 14, FontWeight.w700),
        labelMedium: estilo(base.labelMedium, 13, FontWeight.w600),
        labelSmall: estilo(base.labelSmall, 12, FontWeight.w600),
      )
      .apply(fontFamily: 'Nunito', bodyColor: cor, displayColor: cor);
}

ThemeData temaDoApp(Brightness brilho) {
  final claro = brilho == Brightness.light;
  final fundo = claro ? const Color(0xFFFFF4E6) : const Color(0xFF1D1714);
  final cartao = claro ? const Color(0xFFFFFFFF) : const Color(0xFF2A221E);
  final campo = claro ? const Color(0xFFFFFAF4) : const Color(0xFF362C27);
  final trilho = claro ? const Color(0xFFF6E8D6) : const Color(0xFF3B302A);
  final borda = claro ? const Color(0xFFEFE0CD) : const Color(0xFF473A33);
  final texto = claro ? const Color(0xFF2B241F) : const Color(0xFFF7EEE2);
  final secundario = claro ? const Color(0xFF6F625A) : const Color(0xFFC2B5A8);
  final acao = claro ? corDeAcao : const Color(0xFFFF7E57);
  // Coral puro não tem contraste como letra sobre branco: textos clicáveis usam este tom.
  final acaoEmTexto = claro ? const Color(0xFFBF3A12) : const Color(0xFFFFA587);
  final erro = claro ? CoresFinanceiras.claro.negativo : CoresFinanceiras.escuro.negativo;

  final cores = ColorScheme.fromSeed(seedColor: corDeAcao, brightness: brilho).copyWith(
    primary: acao,
    onPrimary: _textoSobreAcao,
    primaryContainer: claro ? const Color(0xFFFFE3D8) : const Color(0xFF55291A),
    onPrimaryContainer: claro ? const Color(0xFF6B2108) : const Color(0xFFFFDBCE),
    secondary: acaoEmTexto,
    surface: cartao,
    onSurface: texto,
    onSurfaceVariant: secundario,
    surfaceContainerLowest: cartao,
    surfaceContainerLow: campo,
    surfaceContainer: fundo,
    surfaceContainerHigh: trilho,
    surfaceContainerHighest: trilho,
    outline: claro ? const Color(0xFF9C8F80) : const Color(0xFF8A7B6F),
    outlineVariant: borda,
    error: erro,
    errorContainer: claro ? const Color(0xFFFCE3DE) : const Color(0xFF4A211C),
    onErrorContainer: claro ? const Color(0xFF7C1D15) : const Color(0xFFFFD9D3),
  );
  final base = ThemeData(colorScheme: cores, useMaterial3: true, fontFamily: 'Nunito');
  final textos = _textos(base.textTheme, texto);
  final formaDePilula = WidgetStateProperty.all<OutlinedBorder>(const StadiumBorder());
  final letraDeBotao = WidgetStateProperty.all(textos.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w800));
  const alturaDeBotao = Size(0, 46);
  const recuoDeBotao = EdgeInsets.symmetric(horizontal: 22);
  final cantoDoCampo = BorderRadius.circular(Raio.medio);
  // Teclado: o botão focado ganha um anel na cor do texto.
  final anelDeFoco = WidgetStateProperty.resolveWith<BorderSide?>(
    (estados) => estados.contains(WidgetState.focused) ? BorderSide(color: texto, width: 2) : null,
  );

  return base.copyWith(
    scaffoldBackgroundColor: fundo,
    textTheme: textos,
    appBarTheme: AppBarTheme(
      backgroundColor: fundo,
      foregroundColor: texto,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: 76,
      titleSpacing: Espaco.grande,
      titleTextStyle: textos.titleLarge,
    ),
    focusColor: acao.withValues(alpha: 0.24),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: formaDePilula,
        side: anelDeFoco,
        textStyle: letraDeBotao,
        minimumSize: WidgetStateProperty.all(alturaDeBotao),
        padding: WidgetStateProperty.all(recuoDeBotao),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: formaDePilula,
        textStyle: letraDeBotao,
        minimumSize: WidgetStateProperty.all(alturaDeBotao),
        padding: WidgetStateProperty.all(recuoDeBotao),
        foregroundColor: WidgetStateProperty.all(acaoEmTexto),
        side: WidgetStateProperty.resolveWith(
          (estados) => anelDeFoco.resolve(estados) ?? BorderSide(color: borda, width: 1.5),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: formaDePilula,
        side: anelDeFoco,
        textStyle: letraDeBotao,
        foregroundColor: WidgetStateProperty.all(acaoEmTexto),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: campo,
      hintStyle: textos.bodyMedium?.copyWith(color: secundario),
      labelStyle: textos.bodyMedium?.copyWith(color: secundario),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: cantoDoCampo, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: cantoDoCampo, borderSide: BorderSide(color: borda)),
      focusedBorder: OutlineInputBorder(borderRadius: cantoDoCampo, borderSide: BorderSide(color: acao, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: cantoDoCampo, borderSide: BorderSide(color: erro)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: cantoDoCampo, borderSide: BorderSide(color: erro, width: 2)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: acao,
      selectionColor: acao.withValues(alpha: 0.28),
      selectionHandleColor: acao,
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(Raio.pilula),
      thickness: WidgetStateProperty.all(8),
      thumbColor: WidgetStateProperty.all(cores.outline.withValues(alpha: 0.45)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: texto, borderRadius: BorderRadius.circular(Raio.pequeno)),
      textStyle: textos.bodySmall?.copyWith(color: claro ? cartao : fundo, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    dividerTheme: DividerThemeData(color: borda, space: 1, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: acao, linearTrackColor: Colors.transparent),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.medio)),
      titleTextStyle: textos.titleSmall,
      subtitleTextStyle: textos.bodySmall?.copyWith(color: secundario),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cartao,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.grande)),
      titleTextStyle: textos.titleLarge,
      contentTextStyle: textos.bodyMedium,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cartao,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: const Color(0xFF5A3A1E).withValues(alpha: 0.3),
      textStyle: textos.bodyMedium,
      labelTextStyle: WidgetStateProperty.all(textos.bodyMedium),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.medio)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: texto,
      contentTextStyle: textos.bodyMedium?.copyWith(color: claro ? cartao : fundo, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.medio)),
    ),
    extensions: [claro ? CoresFinanceiras.claro : CoresFinanceiras.escuro],
  );
}
