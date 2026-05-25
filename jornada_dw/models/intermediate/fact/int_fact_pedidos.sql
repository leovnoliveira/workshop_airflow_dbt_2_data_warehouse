{{
    config(
        materialized = "table",
        unique_key = "sk_pedido",
        tags = ["intermediate", "fact"]
    )
}}

WITH pedidos AS (
    SELECT * FROM {{ ref("stg_pedidos") }}
),

dim_clientes AS (
    SELECT sk_cliente, cpf
    FROM {{ ref("int_dim_clientes") }}
),

dim_date AS (
    SELECT date_day
    FROM {{ ref("int_dim_date") }}
)

SELECT
    -- Chave substituta
    {{ dbt_utils.generate_surrogate_key(["p.id_pedido"]) }} AS sk_pedido,

    -- Chaves estrangeiras
    dc.sk_cliente AS fk_cliente,

    -- Chave de negócio
    p.id_pedido,

    -- Dimensóes de data/hora
    p.dt_pedido,

    DATE_TRUNC('day', p.dt_pedido) AS data_pedido,

    -- Métricas
    p.valor_total_pedido,

    -- Metadados
    CURRENT_TIMESTAMP AS dbt_updated_at,
    '{{ run_started_at }}' AS dbt_loaded_at

FROM pedidos p
LEFT JOIN dim_clientes dc
ON p.cpf = dc.cpf
LEFT JOIN dim_date dd
ON DATE_TRUNC('day', p.dt_pedido) = dd.date_day