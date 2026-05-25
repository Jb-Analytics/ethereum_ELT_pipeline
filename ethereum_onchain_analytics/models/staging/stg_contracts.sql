with source_data as (

    select 

        address,
        block_number,
        bytecode,
        date,
        last_modified

    from {{ source('raw_eth', 'contracts') }}
)

select * from source_data