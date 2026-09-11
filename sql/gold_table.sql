CREATE TABLE IF NOT EXISTS `snappy-mapper-498509-e0.analytics_lakehouse.currency_rates_gold`
(
  base_currency STRING,
  target_currency STRING,
  exchange_rate NUMERIC,
  rate_date DATE,
  ingested_at TIMESTAMP)PARTITION BY rate_date
CLUSTER BY target_currency, base_currency;

