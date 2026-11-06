import re
import unicodedata

CATEGORIAS = [
    "Alimentação",
    "Contas da casa",
    "Transporte",
    "Saúde",
    "Lazer",
    "Compras",
    "Pix para pessoas",
    "Receitas",
    "Investimentos",
    "Entre minhas contas",
    "Fatura do cartão",
    "Outros",
]

# Movimentações que mudam o saldo mas não são gasto nem receita de verdade.
INTERNAS = {"Investimentos", "Entre minhas contas"}

# Padrões já normalizados (maiúsculas, sem acento). Vence o padrão mais longo que casar.
REGRAS_INICIAIS = {
    "APLICACAO RDB": "Investimentos",
    "RESGATE RDB": "Investimentos",
    "APLICACAO": "Investimentos",
    "RESGATE": "Investimentos",
    "PAGAMENTO DE FATURA": "Fatura do cartão",
    "PAGAMENTO FATURA": "Fatura do cartão",
    "PAGTO FATURA": "Fatura do cartão",
    "PAG FATURA": "Fatura do cartão",
    "VALOR ADICIONADO NA CONTA POR CARTAO DE CREDITO": "Fatura do cartão",
    "PAO DE ACUCAR": "Alimentação",
    "IFOOD": "Alimentação",
    "ENEL DISTRIBUICAO": "Contas da casa",
    "TELECOM": "Contas da casa",
    "99 TECNOLOGIA": "Transporte",
    "UBER": "Transporte",
    "FARMACIA": "Saúde",
    "DROGARIA": "Saúde",
}

CPF_MASCARADO = re.compile(r"\.\d{3}\.\d{3}-")
TRANSFERENCIA = re.compile(r"\b(PIX|TED|DOC|TEF|TRANSF\w*)\b")
# Sinais de que o outro lado é empresa: nome jurídico, palavras de empresa ou CNPJ.
EMPRESA = re.compile(
    r"\b(LTDA|S\.A|S/A|S A|ME|EPP|EIRELI|CIA|COMERCIO|SERVICOS|PAGAMENTOS|BANCO|INSTITUICAO|TECNOLOGIA|"
    r"DISTRIBUICAO|SUPERMERCADO|SUPERMERCADOS|LOJA|LOJAS|FARMACIA|DROGARIA|RESTAURANTE)\b|\d{2}\.?\d{3}\.?\d{3}/\d{4}"
)


def normalizar(texto: str) -> str:
    sem_acento = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return sem_acento.upper().strip()


def contraparte(descricao: str) -> str:
    """'Compra no débito - PAO DE ACUCAR-2374' -> 'PAO DE ACUCAR-2374' ('Estorno - Compra ... - Uber' -> 'UBER')."""
    partes = descricao.split(" - ")
    if len(partes) > 2 and normalizar(partes[0]) == "ESTORNO":
        partes = partes[1:]
    return normalizar(partes[1] if len(partes) > 1 else partes[0])


def _onde_procurar(descricao: str) -> str:
    """Tipo da movimentação e nome de quem pagou ou recebeu. Banco, conta, CPF e CNPJ ficam de fora:
    sem isso, uma regra curta como '99' casava com números de conta de outras pessoas."""
    return f"{normalizar(descricao.split(' - ')[0])} | {contraparte(descricao)}"


def _casa(padrao: str, texto: str) -> bool:
    """Palavra inteira: '99' casa com '99' e '99 TECNOLOGIA', mas não com '99FOOD' nem '0599'."""
    return re.search(rf"(?<![A-Z0-9]){re.escape(padrao)}(?![A-Z0-9])", texto) is not None


def eh_pessoa_fisica(descricao: str) -> bool:
    """Pessoas nunca vão para a IA. No Nubank o CPF mascarado entrega; nos outros bancos, uma transferência
    (PIX, TED, DOC...) sem nenhum sinal de empresa é tratada como pessoa, por segurança."""
    if CPF_MASCARADO.search(descricao):
        return True
    texto = normalizar(descricao)
    return bool(TRANSFERENCIA.search(texto)) and not EMPRESA.search(texto)


def classificar_local(descricao: str, valor: float, regras: dict[str, str]) -> str | None:
    """Categoria pelas regras; None quando só a IA consegue decidir."""
    texto = _onde_procurar(descricao)
    casados = [padrao for padrao in regras if _casa(padrao, texto)]
    if casados:
        categoria = regras[max(casados, key=len)]
        # Dinheiro vindo de outra conta própria é a renda que abastece esta conta: conta como entrada.
        return "Receitas" if categoria == "Entre minhas contas" and valor > 0 else categoria
    if valor > 0:
        return "Receitas"
    if eh_pessoa_fisica(descricao):
        return "Pix para pessoas"
    return None
