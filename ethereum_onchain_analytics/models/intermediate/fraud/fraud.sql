select
    t.from_address,
    c.bytecode,
    count(c.bytecode) bytecode_count

from {{ref('int_transactions_enriched')}} t

left join {{ref('stg_contracts')}} c 
on t.receipt_contract_address = c.address

where t.transaction_category='contract_creation'
and c.bytecode is not null

group by 1,2
