select
  sum(value) as total_amount
from {{ ref('int_transactions_enriched') }}
having total_amount < 0