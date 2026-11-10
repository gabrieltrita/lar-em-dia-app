import sys

from openpyxl import Workbook
from openpyxl.formatting.rule import CellIsRule
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

MONTHS = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
INCOME = ["Salário", "13º salário", "Férias", "Renda extra", "Aluguel recebido", "Outras receitas"]
FIXED = ["Aluguel ou financiamento", "Condomínio", "Luz", "Água", "Gás", "Internet", "Celular", "Escola", "Plano de saúde", "Assinaturas e streaming", "Parcelas do cartão", "IPVA e IPTU", "Outras fixas"]
VARIABLE = ["Mercado", "Farmácia", "Transporte e combustível", "Restaurantes e delivery", "Lazer", "Roupas", "Viagens", "Presentes", "Outras variáveis"]
MONEY = '"R$" #,##0.00;[Red]-"R$" #,##0.00'
BRAND = "2E7D5B"
HEADER = Font(bold=True, color="FFFFFF")
HEADER_FILL = PatternFill("solid", fgColor=BRAND)
SECTION_FILL = PatternFill("solid", fgColor="E3F2EA")
TOTAL_FILL = PatternFill("solid", fgColor="F3F7F5")
FIRST, LAST = 2, 13
TOTAL_COLUMN = 14


def columns():
    return [get_column_letter(c) for c in range(FIRST, LAST + 1)]


def write_header(sheet, row):
    sheet.cell(row, 1, "")
    for offset, month in enumerate(MONTHS):
        sheet.cell(row, FIRST + offset, month)
    sheet.cell(row, TOTAL_COLUMN, "Total do ano")
    for column in range(1, TOTAL_COLUMN + 1):
        cell = sheet.cell(row, column)
        cell.font = HEADER
        cell.fill = HEADER_FILL
        cell.alignment = Alignment(horizontal="center")


def write_section(sheet, row, title, items):
    sheet.cell(row, 1, title).font = Font(bold=True, color=BRAND)
    for column in range(1, TOTAL_COLUMN + 1):
        sheet.cell(row, column).fill = SECTION_FILL
    first = row + 1
    for index, item in enumerate(items):
        current = first + index
        sheet.cell(current, 1, item)
        for letter in columns():
            sheet[f"{letter}{current}"].number_format = MONEY
        total = sheet.cell(current, TOTAL_COLUMN, f"=SUM(B{current}:M{current})")
        total.number_format = MONEY
    last = first + len(items) - 1
    total_row = last + 1
    sheet.cell(total_row, 1, f"Total de {title.lower()}").font = Font(bold=True)
    for column in range(FIRST, TOTAL_COLUMN + 1):
        letter = get_column_letter(column)
        cell = sheet.cell(total_row, column, f"=SUM({letter}{first}:{letter}{last})")
        cell.number_format = MONEY
        cell.font = Font(bold=True)
    for column in range(1, TOTAL_COLUMN + 1):
        sheet.cell(total_row, column).fill = TOTAL_FILL
    return total_row


def build_budget(sheet):
    sheet.title = "Orçamento"
    sheet["A1"] = "Orçamento familiar"
    sheet["A1"].font = Font(bold=True, size=16, color=BRAND)
    sheet["A2"] = "Saldo na conta no começo do ano"
    sheet["A2"].font = Font(bold=True)
    sheet["B2"] = 0
    sheet["B2"].number_format = MONEY
    write_header(sheet, 4)
    income_total = write_section(sheet, 5, "Receitas", INCOME)
    fixed_total = write_section(sheet, income_total + 2, "Despesas fixas", FIXED)
    variable_total = write_section(sheet, fixed_total + 2, "Despesas variáveis", VARIABLE)
    leftover = variable_total + 2
    balance = leftover + 1
    sheet.cell(leftover, 1, "Sobra do mês").font = Font(bold=True)
    sheet.cell(balance, 1, "Saldo no fim do mês").font = Font(bold=True, color=BRAND)
    for index, letter in enumerate(columns()):
        sheet[f"{letter}{leftover}"] = f"={letter}{income_total}-{letter}{fixed_total}-{letter}{variable_total}"
        previous = "$B$2" if index == 0 else f"{columns()[index - 1]}{balance}"
        sheet[f"{letter}{balance}"] = f"={previous}+{letter}{leftover}"
        for row in (leftover, balance):
            sheet[f"{letter}{row}"].number_format = MONEY
            sheet[f"{letter}{row}"].font = Font(bold=True)
    sheet.cell(leftover, TOTAL_COLUMN, f"=SUM(B{leftover}:M{leftover})").number_format = MONEY
    red = PatternFill("solid", fgColor="FDE2E1")
    sheet.conditional_formatting.add(f"B{balance}:M{balance}", CellIsRule(operator="lessThan", formula=["0"], fill=red, font=Font(bold=True, color="C62828")))
    sheet.column_dimensions["A"].width = 34
    for column in range(FIRST, TOTAL_COLUMN + 1):
        sheet.column_dimensions[get_column_letter(column)].width = 14
    sheet.freeze_panes = "B5"


def build_guide(sheet):
    sheet.title = "Como usar"
    lines = [
        "Como usar a planilha",
        "",
        "1. Na aba Orçamento, informe em B2 o saldo da conta no começo do ano ou do mês em que você está começando.",
        "2. Preencha as receitas de cada mês. Lembre do 13º em novembro e dezembro e das férias.",
        "3. Preencha as despesas fixas do ano todo e uma estimativa das variáveis. Troque pela realidade quando o mês acabar.",
        "4. A linha Saldo no fim do mês fica vermelha quando um mês vai ficar negativo. Ajuste antes de ele chegar.",
        "",
        "Pode renomear e inserir linhas dentro de cada grupo: as fórmulas de total continuam certas.",
        "Coloque as contas anuais, como IPVA, IPTU e material escolar, no mês em que vencem.",
        "",
        "Feito pelo Lar em Dia, o orçamento da família com projeção do saldo mês a mês.",
    ]
    for index, line in enumerate(lines, start=1):
        sheet.cell(index, 1, line)
    sheet["A1"].font = Font(bold=True, size=14, color=BRAND)
    sheet.column_dimensions["A"].width = 110


def main(path):
    workbook = Workbook()
    build_budget(workbook.active)
    build_guide(workbook.create_sheet())
    workbook.properties.creator = "Lar em Dia"
    workbook.properties.title = "Orçamento familiar"
    workbook.save(path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "web/planilha-orcamento-familiar.xlsx")
