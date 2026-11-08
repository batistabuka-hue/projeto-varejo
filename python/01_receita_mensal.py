"""Lê a view dw.vw_vendas do PostgreSQL e gera um gráfico de receita líquida por mês."""
import pandas as pd
import matplotlib.pyplot as plt
from sqlalchemy import create_engine

engine = create_engine("postgresql+psycopg2://analista:analista123@localhost:5432/varejo")

df = pd.read_sql(
    """
    SELECT ano_mes, SUM(receita) AS receita_liquida
    FROM dw.vw_vendas
    GROUP BY ano_mes
    ORDER BY ano_mes
    """,
    engine,
)
print(df.to_string(index=False))

ax = df.plot(x="ano_mes", y="receita_liquida", kind="bar", legend=False, figsize=(10, 5))
ax.set_title("Receita líquida por mês (dez/2011 é parcial: só 9 dias)")
ax.set_xlabel("Mês")
ax.set_ylabel("Receita (£)")
plt.tight_layout()
plt.savefig("receita_mensal.png", dpi=150)
print("Gráfico salvo em receita_mensal.png")
