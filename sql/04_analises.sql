-- Análises para treinar SQL. Rode uma por vez no DBeaver/pgAdmin ou via psql.
-- Atenção: dez/2011 tem só 9 dias de dados (a base termina em 09/12/2011).

-- 1) Receita líquida por país e mês (equivale às abas do Excel)
SELECT pais, ano, mes, nome_mes,
       SUM(receita)               AS receita_liquida,
       COUNT(DISTINCT fatura)     AS faturas
FROM dw.vw_vendas
GROUP BY pais, ano, mes, nome_mes
ORDER BY pais, ano, mes;

-- 2) Top 10 produtos por receita (só vendas)
SELECT produto_id, produto, SUM(receita) AS receita, SUM(quantidade) AS qtd
FROM dw.vw_vendas
WHERE tipo = 'Venda'
GROUP BY produto_id, produto
ORDER BY receita DESC
LIMIT 10;

-- 3) Taxa de cancelamento por país
SELECT pais,
       SUM(receita) FILTER (WHERE tipo = 'Venda')                       AS vendido,
       -SUM(receita) FILTER (WHERE tipo = 'Cancelamento')               AS cancelado,
       ROUND(-100.0 * SUM(receita) FILTER (WHERE tipo = 'Cancelamento')
             / NULLIF(SUM(receita) FILTER (WHERE tipo = 'Venda'), 0), 2) AS pct_cancelado
FROM dw.vw_vendas
GROUP BY pais
ORDER BY vendido DESC NULLS LAST;

-- 4) Crescimento mês a mês (window function LAG)
WITH mensal AS (
    SELECT ano_mes, SUM(receita) AS receita
    FROM dw.vw_vendas
    GROUP BY ano_mes
)
SELECT ano_mes,
       receita,
       LAG(receita) OVER (ORDER BY ano_mes) AS mes_anterior,
       ROUND(100.0 * (receita / NULLIF(LAG(receita) OVER (ORDER BY ano_mes), 0) - 1), 1) AS var_pct
FROM mensal
ORDER BY ano_mes;

-- 5) RFM: recência, frequência e valor por cliente (notas de 1 a 5; 5 = melhor)
WITH base AS (
    SELECT cliente_id,
           MAX(data)               AS ultima_compra,
           COUNT(DISTINCT fatura)  AS frequencia,
           SUM(receita)            AS valor
    FROM dw.vw_vendas
    WHERE tipo = 'Venda' AND cliente_id IS NOT NULL
    GROUP BY cliente_id
), ref_data AS (
    SELECT MAX(data) + 1 AS dt FROM dw.fato_vendas
)
SELECT b.cliente_id,
       (r.dt - b.ultima_compra)                           AS recencia_dias,
       b.frequencia,
       b.valor,
       NTILE(5) OVER (ORDER BY (r.dt - b.ultima_compra) DESC) AS r_nota,
       NTILE(5) OVER (ORDER BY b.frequencia)                  AS f_nota,
       NTILE(5) OVER (ORDER BY b.valor)                       AS m_nota
FROM base b
CROSS JOIN ref_data r
ORDER BY b.valor DESC;

-- 6) Retenção por coorte: quantos clientes de cada mês de entrada voltam nos meses seguintes
WITH primeira AS (
    SELECT cliente_id, DATE_TRUNC('month', MIN(data))::date AS coorte
    FROM dw.vw_vendas
    WHERE tipo = 'Venda' AND cliente_id IS NOT NULL
    GROUP BY cliente_id
), atividade AS (
    SELECT DISTINCT cliente_id, DATE_TRUNC('month', data)::date AS mes_compra
    FROM dw.vw_vendas
    WHERE tipo = 'Venda' AND cliente_id IS NOT NULL
)
SELECT p.coorte,
       (EXTRACT(YEAR FROM AGE(a.mes_compra, p.coorte)) * 12
        + EXTRACT(MONTH FROM AGE(a.mes_compra, p.coorte)))::int AS meses_apos_entrada,
       COUNT(*) AS clientes_ativos
FROM primeira p
JOIN atividade a USING (cliente_id)
GROUP BY p.coorte, meses_apos_entrada
ORDER BY p.coorte, meses_apos_entrada;
