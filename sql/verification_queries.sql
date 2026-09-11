SELECT 
  rate_date,
  COUNT(*) AS curated_records_count,
  ROUND(AVG(exchange_rate), 4) AS avg_exchange_rate,
  MIN(ingested_at) AS first_ingested
FROM ` snappy-mapper-498509-e0.analytics_lakehouse.currency_rates_gold`GROUP BY rate_dateORDER BY rate_date DESC;

