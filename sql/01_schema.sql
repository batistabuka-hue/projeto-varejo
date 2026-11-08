-- Executado automaticamente na primeira vez que o container sobe.
CREATE SCHEMA IF NOT EXISTS stg;   -- dados brutos, exatamente como no CSV
CREATE SCHEMA IF NOT EXISTS dw;    -- modelo analítico (esquema estrela)

-- Tudo como TEXT de propósito: o CSV traz "" (aspas vazias) em campos numéricos
-- e a conversão de tipos é feita (e documentada) no 03_modelo.sql.
CREATE TABLE IF NOT EXISTS stg.vendas_raw (
    invoiceno   text,
    stockcode   text,
    description text,
    quantity    text,
    invoicedate text,
    unitprice   text,
    customerid  text,
    country     text,
    revenue     text,
    tipo        text,
    anomes      text,
    duplicada   text
);
