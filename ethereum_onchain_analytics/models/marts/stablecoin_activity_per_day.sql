with stablecoin_transfers as (

    select
        t.date,
        t.token_address,
        s.type,
        s.symbol,
        {{ convertion('t.value', 's.decimals') }} as total_usd_value_transferred

    from {{ ref('stg_token_transfers') }} t

    left join {{ ref('stablecoins') }} s
    on t.token_address = s.contract_address

    where s.contract_address is not null 
    
    group by t.date, t.token_address, s.type, s.symbol
)

select
    date,
    token_address,
    type,
    symbol,
    total_usd_value_transferred
from stablecoin_transfers