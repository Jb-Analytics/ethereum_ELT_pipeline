with source_data as (
    select 

        hash,
        block_number,
        date,
        from_address,
        to_address,
        value,
        receipt_contract_address,
        input

    from {{ source('raw_eth', 'transactions') }}
)

select * from source_data