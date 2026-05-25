WITH source AS (
    SELECT * FROM {{ ref('cadastros')}}
),

transformado AS (
    SELECT
        -- chaves
        id AS id_cliente,
        cpf,

        -- Dados pessoais 
        nome,
        data_nascimento AS dt_nascimento,
        sexo,

        -- Dados de contato
        email,
        telefone,

        -- Endereco
        cep,
        cidade,
        sigla_uf,

        -- Datas
        data_cadastro as dt_cadastro,

        -- Metadados
        current_timestamp AS etl_inserted_at

    FROM source
)

SELECT * FROM transformado