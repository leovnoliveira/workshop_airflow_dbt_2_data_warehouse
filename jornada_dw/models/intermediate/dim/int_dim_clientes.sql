{{

    config(
        materialized = "table",
        unique_key = "sk_cliente",
        tags = ["intermediate", "dimension"]
    )
}}

WITH clientes AS (
    SELECT * FROM {{ ref("stg_cadastros")}}
)

SELECT
    -- Chave substituta
    {{ dbt_utils.generate_surrogate_key(["cpf"])}} AS sk_cliente,

    -- Chave de negócio
    cpf,

    -- Atributos descritivos
    nome,
    email,
    sigla_uf,
    cidade,
    dt_nascimento,

    -- Datas importantes
    dt_cadastro,

    -- Metadados
    current_timestamp AS dbt_updated_at,
    '{{ run_started_at }}' AS dbt_loaded_at

FROM clientes