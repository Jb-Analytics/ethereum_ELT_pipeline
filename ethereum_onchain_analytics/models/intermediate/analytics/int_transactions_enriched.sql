{{ config(
    materialized='incremental',
    incremental_strategy='append',
)}}

with token_transfer_counts as (
    select
    transaction_hash,
    count(*) as token_transfer_count
    from {{ ref('stg_token_transfers') }} 
    group by transaction_hash
),

transactions_enriched as (
    select 
        t.hash,
        t.block_number,
        t.date,
        t.from_address,
        t.to_address,
        t.value,
        t.receipt_contract_address,
        t.input,
        tt.token_transfer_count,

        case 
            when t.receipt_contract_address != '' then 'contract_creation'
            when tt.transaction_hash is not null then 'token_transfer'
            when t.input = '0x' and t.value > 0 then 'simple_eth_transfer'
            else 'other'
        end as transaction_category

    from {{ ref('stg_transactions') }} t
    left join token_transfer_counts tt 
    on t.hash = tt.transaction_hash

{% if is_incremental() %}

where t.date > (select max(date) from {{ this }})

{% endif %}
)

select * from transactions_enriched