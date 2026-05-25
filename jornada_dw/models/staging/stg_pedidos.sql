WITH source AS (
    SELECT * FROM {{ ref("pedidos") }}

),

transformado AS (
    SELECT 
        -- Chaves
        id_pedido,
        cpf,

        -- Valores monetários
        valor_pedido,
        valor_frete,
        valor_desconto,
        (valor_pedido + valor_frete - COALESCE(valor_desconto, 0)) AS valor_total_pedido,

        -- Cupom
        cupom,
        CASE WHEN cupom IS NOT NULL THEN true ELSE false END AS tem_cupom,

        -- Endereco de entrega
        endereco_entrega_logradouro,
        endereco_entrega_numero,
        endereco_entrega_bairro,
        endereco_entrega_cidade,
        endereco_entrega_estado,
        endereco_entrega_pais,

        -- Status e datas
        status_pedido,
        data_pedido AS dt_pedido,

        -- Metadados
        current_timestamp AS etl_inserted_at

    FROM source ADD
)

SELECT * FROM transformado 