with source_data as (
    select 

        transaction_hash,
        date,
        token_address,
        value

    from {{ source('raw_eth', 'token_transfers') }}
)

select * from source_data