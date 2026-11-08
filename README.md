# Projeto Varejo – PostgreSQL + Docker + SQL + Python + Power BI

Base: Online Retail (541.909 linhas, dez/2010 a dez/2011), já limpa com as colunas
`Revenue`, `Tipo`, `AnoMes` e `Duplicada`.

## O que tem aqui
```
docker-compose.yml      PostgreSQL 16 em container
data/                   coloque aqui o CSV (vendas.csv)
sql/01_schema.sql       cria schemas e tabela de staging (automático no 1º start)
sql/02_carga.sql        carrega o CSV na staging
sql/03_modelo.sql       cria o esquema estrela (dim_* e fato_vendas) e a view dw.vw_vendas
sql/04_analises.sql     6 análises: país/mês, top produtos, cancelamento, MoM, RFM, coorte
python/                 exemplo de leitura do banco com pandas + gráfico
```

## Passo a passo
Pré-requisito: Docker Desktop aberto. Rode os comandos dentro desta pasta.

1. **Copie o CSV** `BASE_ORACLE_CORRIGIDO.csv` para `data/` com o nome `vendas.csv`.
2. **Suba o banco:**
   ```
   docker compose up -d
   ```
3. **Carregue os dados:**
   ```
   docker compose exec -T db psql -U analista -d varejo -f /sql/02_carga.sql
   ```
   Deve mostrar `541909`.
4. **Monte o modelo:**
   ```
   docker compose exec -T db psql -U analista -d varejo -f /sql/03_modelo.sql
   ```
   Conferência no fim: `linhas_staging = linhas_fato = 541909` e `receita_liquida = 9353925.40`
   (o mesmo total da aba País-Ano-Mês do Excel).
5. **Analise:** abra o banco no DBeaver (ou pgAdmin) e rode as consultas de `sql/04_analises.sql`.

### Conexão (DBeaver, Power BI, Python)
| Campo | Valor |
|---|---|
| Servidor | `localhost` |
| Porta | `5432` |
| Banco | `varejo` |
| Usuário | `analista` |
| Senha | `analista123` |

No Power BI: *Obter dados → Banco de dados PostgreSQL*, e importe `dw.vw_vendas` (ou as tabelas `dw.*`
para montar o modelo você mesmo, que é um bom exercício).

### Python
```
pip install -r python/requirements.txt
python python/01_receita_mensal.py
```

## Comandos úteis
- Entrar no psql: `docker compose exec db psql -U analista -d varejo`
- Parar: `docker compose down`
- Apagar tudo e recomeçar (inclui os dados): `docker compose down -v`

## Regras de negócio usadas
- Receita líquida = Venda + Cancelamento, sem linhas duplicadas.
- Ajustes de estoque, taxas/serviços e ajustes contábeis ficam fora da view `dw.vw_vendas`.
- Dez/2011 é um mês parcial (a base vai até 09/12/2011).
- Cerca de 25% das linhas não têm `CustomerID`; elas entram nas análises de receita,
  mas ficam fora de RFM e coorte.

## Próximos passos
Dashboard no Power BI, README com as conclusões de negócio e publicação no GitHub.
