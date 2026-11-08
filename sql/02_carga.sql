-- Carrega data/vendas.csv na tabela de staging.
TRUNCATE stg.vendas_raw;

COPY stg.vendas_raw
FROM '/data/vendas.csv'
WITH (FORMAT csv, DELIMITER ';', HEADER true, ENCODING 'UTF8');

SELECT COUNT(*) AS linhas_carregadas FROM stg.vendas_raw;   -- esperado: 541909
