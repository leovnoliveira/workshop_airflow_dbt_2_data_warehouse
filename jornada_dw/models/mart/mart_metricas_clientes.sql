{{
    config(
        materialized = "table",
        unique_key = "sk_cliente",
        tags = ["mart", "metrics"]
    )
}}

WITH 
    dim_clientes AS (
        SELECT * FROM {{ ref("int_dim_clientes") }}
    ),

    fact_pedidos AS (
        SELECT
            *,
            CAST(dt_pedido AS DATE) AS data_pedido
        FROM {{ ref("int_fact_pedidos") }}
    ),

    dim_date AS (
        SELECT * FROM {{ ref("int_dim_date") }}
    ),

pedidos_por_cliente AS (
    SELECT
        dc.sk_cliente,
        dc.cpf,
        dc.nome,
        dc.sigla_uf,
        dc.cidade,

        -- Métricas de contagem
        COUNT(DISTINCT fp.sk_pedido) AS total_pedidos,

        -- Métricas financeiras
        SUM(fp.valor_total_pedido) AS valor_total_gasto,
        AVG(fp.valor_total_pedido) AS ticket_medio,

        -- Datas importantes
        MIN(fp.dt_pedido) AS data_primeiro_pedido,
        MAX(fp.dt_pedido) AS data_ultimo_pedido,

        -- Análise temporal
        MIN(dd.year_number) AS primeiro_ano_compra,
        MAX(dd.year_number) AS ultimo_ano_compra,
        COUNT(DISTINCT dd.year_number) AS total_anos_ativos,

        -- Estacionalidade
        COUNT(DISTINCT CASE WHEN dd.month_name in ('December', 'January', 'February') THEN fp.sk_pedido END) AS pedidos_verao,
        COUNT(DISTINCT CASE WHEN dd.month_name in ('March', 'April', 'May') THEN fp.sk_pedido END) AS pedidos_outono,
        COUNT(DISTINCT CASE WHEN dd.month_name in ('June', 'July', 'August') THEN fp.sk_pedido END) AS pedidos_inverno,
        COUNT(DISTINCT CASE WHEN dd.month_name in ('September', 'October', 'November') THEN fp.sk_pedido END) AS pedidos_primavera,

        -- Dias da semana com mais compras
        COUNT(DISTINCT CASE WHEN dd.day_of_week_name = 'Sunday' THEN fp.sk_pedido END) AS pedidos_domingo,
        COUNT(DISTINCT CASE WHEN dd.day_of_week_name = 'Monday' THEN fp.sk_pedido END) AS pedidos_segunda,
        COUNT(DISTINCT CASE WHEN dd.day_of_week_name = 'Tuesday' THEN fp.sk_pedido END) AS pedidos_terca,
        COUNT(DISTINCT CASE WHEN dd.day_of_week_name = 'Wednesday' THEN fp.sk_pedido END) AS pedidos_quarta,
        COUNT(DISTINCT CASE WHEN dd.day_of_week_name = 'Thursday' THEN fp.sk_pedido END) AS pedidos_quinta,
        COUNT(DISTINCT CASE WHEN dd.day_of_week_name = 'Friday' THEN fp.sk_pedido END) AS pedidos_sexta,
        COUNT(DISTINCT CASE WHEN dd.day_of_week_name = 'Saturday' THEN fp.sk_pedido END) AS pedidos_sabado,

        -- Frquencia e recencia
        (CURRENT_DATE - MAX(fp.dt_pedido)::date) AS dias_desde_ultimo_pedido,

        -- Cálculo da frequencia média de compras (em dias)
        CASE
            WHEN COUNT(fp.sk_pedido) > 1 
            THEN (MAX(fp.dt_pedido)::date - MIN(fp.dt_pedido)::date)::float / 
                NULLIF(COUNT(fp.sk_pedido) -1, 0)
            ELSE NULL
        END AS frequencia_media_dias,

        -- Valor médio por mês
        CASE
            WHEN COUNT(DISTINCT to_char(fp.dt_pedido, 'YYYY-MM')) > 0
            THEN SUM(fp.valor_total_pedido) / COUNT(DISTINCT to_char(fp.dt_pedido, 'YYYY-MM'))
            ELSE NULL
        END AS valor_medio_mes,

        -- Frequencia de compra por mes
        CASE
            WHEN COUNT(DISTINCT to_char(fp.dt_pedido, 'YYYY-MM')) > 0
            THEN COUNT(fp.sk_pedido)::float / COUNT(DISTINCT to_char(fp.dt_pedido, 'YYYY-MM'))
            ELSE 0
        END AS frequencia_compra_mes
    
    FROM dim_clientes dc
    LEFT JOIN fact_pedidos fp
        ON dc.sk_cliente = fp.fk_cliente
    LEFT JOIN dim_date dd 
        oN DATE_TRUNC('day', fp.dt_pedido) = dd.date_day
    GROUP BY 1,2,3,4,5
)

SELECT
    *,
    -- Análise RFM completa
    CASE
        WHEN valor_total_gasto IS NULL OR valor_total_gasto = 0 THEN 'Inativo'
        WHEN valor_total_gasto > 5000 AND dias_desde_ultimo_pedido <= 30 AND frequencia_compra_mes >= 2 THEN 'Campeão'
        WHEN valor_total_gasto > 3000 AND dias_desde_ultimo_pedido <= 60 THEN  'Cliente Fiel'
        WHEN valor_total_gasto > 0 AND dias_desde_ultimo_pedido <= 90 THEN 'Potencial'
        WHEN valor_total_gasto > 0 THEN 'Em Observação'
        ELSE 'Inativo'
    END AS segmento_rfm,

    -- Score RFM (1-5, sendo 5 o melhor)
    CASE
        WHEN valor_total_gasto IS NULL OR valor_total_gasto = 0 THEN 1
        WHEN valor_total_gasto > 5000 THEN 5
        WHEN valor_total_gasto > 3000 THEN 4
        WHEN valor_total_gasto > 1000 THEN 3
        WHEN valor_total_gasto > 0 THEN 2
        ELSE 1
    END AS score_valor,

    CASE
        WHEN dias_desde_ultimo_pedido IS NULL THEN 1
        WHEN dias_desde_ultimo_pedido <= 30 THEN 5
        WHEN dias_desde_ultimo_pedido > 30 AND dias_desde_ultimo_pedido <= 60 THEN 4
        WHEN dias_desde_ultimo_pedido > 60 AND dias_desde_ultimo_pedido <= 90 THEN 3
        WHEN dias_desde_ultimo_pedido > 90 AND dias_desde_ultimo_pedido <= 180 THEN 2
        ELSE 1
    END AS score_recencia,

    CASE
        WHEN frequencia_compra_mes IS NULL OR frequencia_compra_mes = 0 THEN 1
        WHEN frequencia_compra_mes >= 4 THEN 5
        WHEN frequencia_compra_mes >= 2 AND frequencia_compra_mes < 4 THEN 4
        WHEN frequencia_compra_mes >= 1 AND frequencia_compra_mes < 2 THEN 3
        WHEN frequencia_compra_mes > 0  AND frequencia_compra_mes < 1 THEN 2 
        ELSE 1
    END AS score_frequencia,

    -- Estação preferida
    CASE
        WHEN pedidos_verao > pedidos_outono and pedidos_verao > pedidos_inverno and pedidos_verao > pedidos_primavera then 'Verão'
        WHEN pedidos_outono > pedidos_verao and pedidos_outono > pedidos_inverno and pedidos_outono > pedidos_primavera then 'Outono'
        WHEN pedidos_inverno > pedidos_verao and pedidos_inverno > pedidos_outono and pedidos_inverno > pedidos_primavera then 'Inverno'
        WHEN pedidos_primavera > pedidos_verao and pedidos_primavera > pedidos_outono and pedidos_primavera > pedidos_inverno then 'Primavera'
        ELSE 'Sem preferência'
    END AS estacao_preferida,
    
    -- Análise de crescimento
    CASE
        WHEN total_anos_ativos > 1 and total_pedidos > 0 then
            CASE 
                WHEN (SELECT AVG(total_pedidos::float / total_anos_ativos) 
                      FROM pedidos_por_cliente 
                      WHERE total_anos_ativos > 1) > 0
                THEN (total_pedidos::float / total_anos_ativos) / 
                     (SELECT AVG(total_pedidos::float / total_anos_ativos) 
                      FROM pedidos_por_cliente 
                      WHERE total_anos_ativos > 1)
                ELSE 0
            END
        ELSE 0
    END AS taxa_crescimento_vs_media,
    
    -- Metadados
    current_timestamp as dbt_updated_at,
    '{{ run_started_at }}' as dbt_loaded_at
FROM pedidos_por_cliente
ORDER BY 
    CASE WHEN valor_total_gasto IS NULL THEN 1 ELSE 0 END,  -- Inativos por último
    valor_total_gasto DESC  -- Maiores valores primeiro

