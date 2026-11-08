-- Modelo dimensional (esquema estrela) a partir da staging.
-- Pode ser rodado de novo quando quiser: ele recria as tabelas do schema dw.

DROP VIEW  IF EXISTS dw.vw_vendas;
DROP TABLE IF EXISTS dw.fato_vendas, dw.dim_cliente, dw.dim_produto, dw.dim_pais, dw.dim_data;

-- ---------- Dimensão país ----------
CREATE TABLE dw.dim_pais AS
SELECT ROW_NUMBER() OVER (ORDER BY country)::int AS pais_id,
       country AS pais
FROM (SELECT DISTINCT country FROM stg.vendas_raw) c;
ALTER TABLE dw.dim_pais ADD PRIMARY KEY (pais_id);

-- ---------- Dimensão cliente (só clientes identificados) ----------
CREATE TABLE dw.dim_cliente AS
SELECT DISTINCT NULLIF(customerid, '')::numeric::int AS cliente_id
FROM stg.vendas_raw
WHERE NULLIF(customerid, '') IS NOT NULL;
ALTER TABLE dw.dim_cliente ADD PRIMARY KEY (cliente_id);

-- ---------- Dimensão produto (descrição mais frequente de cada StockCode) ----------
CREATE TABLE dw.dim_produto AS
WITH freq AS (
    SELECT stockcode, description, COUNT(*) AS n
    FROM stg.vendas_raw
    WHERE description <> ''
    GROUP BY stockcode, description
), rk AS (
    SELECT stockcode, description,
           ROW_NUMBER() OVER (PARTITION BY stockcode ORDER BY n DESC, description) AS rn
    FROM freq
)
SELECT s.stockcode AS produto_id,
       COALESCE(rk.description, '(sem descrição)') AS descricao
FROM (SELECT DISTINCT stockcode FROM stg.vendas_raw) s
LEFT JOIN rk ON rk.stockcode = s.stockcode AND rk.rn = 1;
ALTER TABLE dw.dim_produto ADD PRIMARY KEY (produto_id);

-- ---------- Dimensão data ----------
CREATE TABLE dw.dim_data AS
SELECT d::date                                   AS data,
       EXTRACT(YEAR    FROM d)::int              AS ano,
       EXTRACT(MONTH   FROM d)::int              AS mes,
       (ARRAY['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho',
              'Agosto','Setembro','Outubro','Novembro','Dezembro'])[EXTRACT(MONTH FROM d)::int] AS nome_mes,
       TO_CHAR(d, 'YYYY-MM')                     AS ano_mes,
       EXTRACT(QUARTER FROM d)::int              AS trimestre,
       EXTRACT(ISODOW  FROM d)::int              AS dia_semana   -- 1 = segunda ... 7 = domingo
FROM GENERATE_SERIES(
        (SELECT MIN(invoicedate::timestamp)::date FROM stg.vendas_raw),
        (SELECT MAX(invoicedate::timestamp)::date FROM stg.vendas_raw),
        INTERVAL '1 day') AS d;
ALTER TABLE dw.dim_data ADD PRIMARY KEY (data);

-- ---------- Fato vendas (uma linha por item de fatura) ----------
CREATE TABLE dw.fato_vendas AS
SELECT ROW_NUMBER() OVER ()::bigint                  AS venda_id,
       r.invoiceno                                    AS fatura,
       r.stockcode                                    AS produto_id,
       NULLIF(r.customerid, '')::numeric::int         AS cliente_id,
       p.pais_id,
       r.invoicedate::timestamp                       AS data_hora,
       r.invoicedate::timestamp::date                 AS data,
       r.quantity::int                                AS quantidade,
       r.unitprice::numeric(12,2)                     AS preco_unitario,
       r.revenue::numeric(14,2)                       AS receita,
       r.tipo,
       (r.duplicada = 'Sim')                          AS duplicada
FROM stg.vendas_raw r
JOIN dw.dim_pais p ON p.pais = r.country;

ALTER TABLE dw.fato_vendas ADD PRIMARY KEY (venda_id);
ALTER TABLE dw.fato_vendas ADD FOREIGN KEY (produto_id) REFERENCES dw.dim_produto (produto_id);
ALTER TABLE dw.fato_vendas ADD FOREIGN KEY (cliente_id) REFERENCES dw.dim_cliente (cliente_id);
ALTER TABLE dw.fato_vendas ADD FOREIGN KEY (pais_id)    REFERENCES dw.dim_pais (pais_id);
ALTER TABLE dw.fato_vendas ADD FOREIGN KEY (data)       REFERENCES dw.dim_data (data);
CREATE INDEX ix_fato_data    ON dw.fato_vendas (data);
CREATE INDEX ix_fato_cliente ON dw.fato_vendas (cliente_id);
CREATE INDEX ix_fato_produto ON dw.fato_vendas (produto_id);
CREATE INDEX ix_fato_pais    ON dw.fato_vendas (pais_id);

-- ---------- View pronta para análise e Power BI ----------
-- Regra de negócio: sem duplicadas e só Venda + Cancelamento
-- (ajustes de estoque, taxas/serviços e ajustes contábeis ficam de fora).
CREATE VIEW dw.vw_vendas AS
SELECT f.venda_id, f.fatura, f.data_hora, f.data,
       d.ano, d.mes, d.nome_mes, d.ano_mes,
       pa.pais, f.cliente_id, f.produto_id, pr.descricao AS produto,
       f.quantidade, f.preco_unitario, f.receita, f.tipo
FROM dw.fato_vendas f
JOIN dw.dim_data    d  ON d.data = f.data
JOIN dw.dim_pais    pa ON pa.pais_id = f.pais_id
JOIN dw.dim_produto pr ON pr.produto_id = f.produto_id
WHERE NOT f.duplicada
  AND f.tipo IN ('Venda', 'Cancelamento');

ANALYZE;

-- ---------- Conferência ----------
SELECT (SELECT COUNT(*) FROM stg.vendas_raw)  AS linhas_staging,
       (SELECT COUNT(*) FROM dw.fato_vendas)  AS linhas_fato,
       (SELECT SUM(receita) FROM dw.vw_vendas) AS receita_liquida;   -- esperado: 9353925.40
