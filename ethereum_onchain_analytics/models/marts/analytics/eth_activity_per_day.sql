with eth_transactions as (
    select
        date,
        transaction_category,
        count(*) as transaction_count,
        {{ convertion('value', '18') }} as total_eth_value_transferred
    from {{ ref('int_transactions_enriched') }}
    group by date, transaction_category

)

select 
    date,
    transaction_category,
    transaction_count,
    total_eth_value_transferred
from eth_transactions
