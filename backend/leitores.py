"""Leitura de extratos de qualquer banco: OFX, CSV/Excel (colunas reconhecidas pelo cabeçalho) e PDF.

Todos devolvem a mesma lista: [{"identificador", "data" (AAAA-MM-DD), "valor" (negativo = saída), "descricao"}].
"""

import csv
import hashlib
import html
import io
import re
from datetime import date, datetime, timedelta
from pathlib import Path

from classificador import normalizar

INICIO_DATAS_EXCEL = date(1899, 12, 30)
LINHAS_PARA_ACHAR_CABECALHO = 30

# Nomes de coluna que os bancos usam (já sem acento e em maiúsculas). A ordem importa: "DATA LANCAMENTO" é data.
COLUNAS = {
    "data": ("DATA", "DT", "DATE"),
    "descricao": (
        "DESCRICAO",
        "HISTORICO",
        "LANCAMENTO",
        "DETALHAMENTO",
        "DETALHES",
        "MEMO",
        "TITULO",
        "ESTABELECIMENTO",
    ),
    "valor": ("VALOR", "MONTANTE", "AMOUNT", "QUANTIA"),
    "debito": ("DEBITO", "SAIDA", "SAIDAS"),
    "credito": ("CREDITO", "ENTRADA", "ENTRADAS"),
    "identificador": ("IDENTIFICADOR", "ID"),
}

MENSAGEM_FORMATO = "Formato não suportado. Use o extrato em OFX, CSV, Excel (.xlsx) ou PDF."


def ler_extrato(caminho: str | Path) -> list[dict]:
    caminho = Path(caminho)
    if not caminho.is_file():
        raise ValueError(f"Arquivo não encontrado: {caminho}")
    tipo = caminho.suffix.lower()
    if tipo == ".ofx":
        return _ler_ofx(_decodificar(caminho.read_bytes()))
    if tipo in (".csv", ".txt"):
        return _ler_tabela(_linhas_csv(_decodificar(caminho.read_bytes())))
    if tipo == ".xlsx":
        from openpyxl import load_workbook

        planilha = load_workbook(caminho, read_only=True, data_only=True).active
        return _ler_tabela([list(linha) for linha in planilha.iter_rows(values_only=True)])
    if tipo == ".pdf":
        return _ler_pdf(caminho)
    raise ValueError(MENSAGEM_FORMATO)


# ---------- valores comuns aos formatos ----------


def _decodificar(conteudo: bytes) -> str:
    """Bancos brasileiros ainda exportam no padrão antigo do Windows (cp1252); tenta UTF-8 antes."""
    try:
        return conteudo.decode("utf-8-sig")
    except UnicodeDecodeError:
        return conteudo.decode("cp1252")


def _numero(bruto) -> float | None:
    """'1.234,56', '-50,00', 'R$ 50,00 D', '(50,00)', '1234.56' ou número. None se não for valor."""
    if bruto is None or isinstance(bruto, bool):
        return None
    if isinstance(bruto, (int, float)):
        return float(bruto)
    texto = str(bruto).upper().replace("R$", "").replace(" ", "")
    if not texto:
        return None
    negativo = texto.startswith("-") or texto.endswith(("-", "D")) or (texto.startswith("(") and texto.endswith(")"))
    texto = texto.strip("-+()DC")
    if "," in texto:
        texto = texto.replace(".", "").replace(",", ".")
    try:
        numero = float(texto)
    except ValueError:
        return None
    return -abs(numero) if negativo else numero


def _data(bruto, ano_padrao: int | None = None) -> str | None:
    """Data em AAAA-MM-DD a partir de data do Excel, número de série ou texto. None se não for data."""
    if isinstance(bruto, datetime):
        return bruto.date().isoformat()
    if isinstance(bruto, date):
        return bruto.isoformat()
    if isinstance(bruto, (int, float)) and not isinstance(bruto, bool) and 20000 < bruto < 80000:
        return (INICIO_DATAS_EXCEL + timedelta(days=int(bruto))).isoformat()
    texto = str(bruto or "").strip()[:10]
    for formato in ("%d/%m/%Y", "%d/%m/%y", "%Y-%m-%d", "%d-%m-%Y", "%d.%m.%Y"):
        try:
            return datetime.strptime(texto, formato).date().isoformat()
        except ValueError:
            pass
    if ano_padrao and re.fullmatch(r"\d{2}/\d{2}", texto):
        return datetime.strptime(f"{texto}/{ano_padrao}", "%d/%m/%Y").date().isoformat()
    return None


def _com_identificador(transacoes: list[dict]) -> list[dict]:
    """Quem não tem identificador do banco ganha um a partir de data, valor e descrição.
    O contador separa lançamentos iguais no mesmo dia; reimportar o mesmo extrato gera os mesmos códigos."""
    vistos: dict[str, int] = {}
    for t in transacoes:
        if t.get("identificador"):
            continue
        chave = f"{t['data']}|{t['valor']:.2f}|{t['descricao']}"
        vistos[chave] = vistos.get(chave, 0) + 1
        t["identificador"] = "gerado:" + hashlib.sha1(f"{chave}|{vistos[chave]}".encode()).hexdigest()[:16]
    return transacoes


def _eh_saldo(descricao: str) -> bool:
    return normalizar(descricao).startswith("SALDO")


# ---------- CSV e Excel ----------


def _linhas_csv(texto: str) -> list[list]:
    amostra = texto[:5000]
    try:
        separador = csv.Sniffer().sniff(amostra, delimiters=";,\t|").delimiter
    except csv.Error:
        separador = ","
    return list(csv.reader(io.StringIO(texto), delimiter=separador))


def _papel_da_coluna(nome) -> str | None:
    texto = normalizar(str(nome or ""))
    if not texto or "SALDO" in texto:
        return None
    for papel, nomes in COLUNAS.items():
        if any(texto == n or texto.startswith((n + " ", n + "(")) for n in nomes):
            return papel
    return None


def _achar_cabecalho(linhas: list[list]) -> tuple[int, dict[str, int]]:
    for numero, linha in enumerate(linhas[:LINHAS_PARA_ACHAR_CABECALHO]):
        colunas: dict[str, int] = {}
        for indice, celula in enumerate(linha):
            papel = _papel_da_coluna(celula)
            if papel and papel not in colunas:
                colunas[papel] = indice
        tem_valor = "valor" in colunas or "debito" in colunas or "credito" in colunas
        if "data" in colunas and "descricao" in colunas and tem_valor:
            return numero, colunas
    raise ValueError("Não encontrei as colunas de data, descrição e valor neste arquivo.")


def _ler_tabela(linhas: list[list]) -> list[dict]:
    inicio, colunas = _achar_cabecalho(linhas)

    def celula(linha: list, papel: str):
        indice = colunas.get(papel)
        return linha[indice] if indice is not None and indice < len(linha) else None

    transacoes = []
    for linha in linhas[inicio + 1 :]:
        data = _data(celula(linha, "data"))
        descricao = str(celula(linha, "descricao") or "").strip()
        if not data or not descricao or _eh_saldo(descricao):
            continue
        if "valor" in colunas:
            valor = _numero(celula(linha, "valor"))
        else:  # colunas separadas de débito e crédito
            credito = _numero(celula(linha, "credito")) or 0
            debito = _numero(celula(linha, "debito")) or 0
            valor = abs(credito) - abs(debito)
        if not valor:
            continue
        identificador = str(celula(linha, "identificador") or "").strip()
        transacoes.append({"identificador": identificador, "data": data, "valor": valor, "descricao": descricao})
    if not transacoes:
        raise ValueError("Não encontrei movimentações neste arquivo.")
    return _com_identificador(transacoes)


# ---------- OFX ----------


def _campo_ofx(bloco: str, nome: str) -> str:
    achado = re.search(rf"<{nome}>([^<\r\n]*)", bloco, re.IGNORECASE)
    return html.unescape(achado.group(1).strip()) if achado else ""


def _ler_ofx(conteudo: str) -> list[dict]:
    transacoes = []
    for bloco in re.split(r"<STMTTRN>", conteudo, flags=re.IGNORECASE)[1:]:
        bloco = re.split(r"</STMTTRN>", bloco, flags=re.IGNORECASE)[0]
        postado = _campo_ofx(bloco, "DTPOSTED")[:8]
        valor = _numero(_campo_ofx(bloco, "TRNAMT"))
        partes = [p for p in (_campo_ofx(bloco, "NAME"), _campo_ofx(bloco, "MEMO")) if p]
        if len(postado) != 8 or not valor or not partes:
            continue
        transacoes.append(
            {
                "identificador": _campo_ofx(bloco, "FITID"),
                "data": f"{postado[:4]}-{postado[4:6]}-{postado[6:]}",
                "valor": valor,
                "descricao": " - ".join(dict.fromkeys(partes)),
            }
        )
    if not transacoes:
        raise ValueError("Não encontrei movimentações neste arquivo OFX.")
    return _com_identificador(transacoes)


def saldo_do_extrato(caminho: str | Path) -> tuple[str, float] | None:
    """(data, saldo) que o banco informa no OFX de conta. O de cartão traz a fatura; CSV e PDF não têm campo padrão."""
    caminho = Path(caminho)
    if caminho.suffix.lower() != ".ofx":
        return None
    conteudo = _decodificar(caminho.read_bytes())
    bloco = re.search(r"<LEDGERBAL>(.*?)(?:</LEDGERBAL>|$)", conteudo, re.IGNORECASE | re.DOTALL)
    if bloco is None or re.search(r"<CCSTMTRS>", conteudo, re.IGNORECASE):
        return None
    valor = _numero(_campo_ofx(bloco[1], "BALAMT"))
    data = _campo_ofx(bloco[1], "DTASOF")[:8]
    if valor is None or len(data) != 8:
        return None
    return f"{data[:4]}-{data[4:6]}-{data[6:]}", valor


# ---------- PDF ----------

_DINHEIRO = r"\(?-?(?:R\$\s?)?-?\d{1,3}(?:\.\d{3})*,\d{2}\)?(?:\s?[DC](?![A-Za-z]))?"
_LINHA_PDF = re.compile(rf"^\s*(\d{{2}}/\d{{2}}(?:/\d{{2,4}})?)\s+(.+?)\s+({_DINHEIRO})(?:\s+({_DINHEIRO}))?\s*$")
_SALDO_SEM_DATA = re.compile(rf"SALDO\b.*?({_DINHEIRO})\s*$")


def _ler_pdf(caminho: Path) -> list[dict]:
    from pypdf import PdfReader

    try:
        texto = "\n".join(pagina.extract_text() or "" for pagina in PdfReader(caminho).pages)
    except Exception as erro:  # PDF protegido, corrompido ou só com imagem
        raise ValueError("Não consegui abrir este PDF. Se o banco oferecer, use o extrato em OFX.") from erro
    data_completa = re.search(r"\d{2}/\d{2}/(\d{4})", texto)
    ano = int(data_completa.group(1)) if data_completa else date.today().year

    transacoes = []
    saldo_anterior = None
    for linha in texto.splitlines():
        achado = _LINHA_PDF.match(linha)
        if not achado:
            saldo_sem_data = _SALDO_SEM_DATA.search(normalizar(linha))  # "SALDO ANTERIOR 1.000,00"
            if saldo_sem_data:
                saldo_anterior = _numero(saldo_sem_data.group(1))
            continue
        bruto_data, descricao, bruto_valor, bruto_saldo = achado.groups()
        valor, saldo = _numero(bruto_valor), _numero(bruto_saldo)
        if _eh_saldo(descricao):
            saldo_anterior = saldo if saldo is not None else valor
            continue
        data = _data(bruto_data, ano)
        if not data or not valor:
            continue
        # Sem "-", "D" ou "C" no valor, o sinal sai da diferença entre o saldo desta linha e o anterior.
        # ponytail: sem marca e sem coluna de saldo, o lançamento fica positivo; o aviso pede OFX nesses casos.
        sem_marca = not re.search(r"[-()DC]", bruto_valor)
        if sem_marca and saldo is not None and saldo_anterior is not None:
            diferenca = round(saldo - saldo_anterior, 2)
            if abs(abs(diferenca) - abs(valor)) < 0.01:
                valor = diferenca
        if saldo is not None:
            saldo_anterior = saldo
        transacoes.append({"identificador": "", "data": data, "valor": valor, "descricao": descricao.strip()})
    if not transacoes:
        raise ValueError("Não consegui ler as movimentações deste PDF. Se o banco oferecer, use o extrato em OFX.")
    return _com_identificador(transacoes)
