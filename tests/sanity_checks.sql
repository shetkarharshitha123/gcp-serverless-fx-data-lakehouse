-- Partition-Level Aggregation & Volume Check:
SELECT 
  rate_date,
  COUNT(*) AS curated_records_count,
  COUNT(DISTINCT target_currency) AS distinct_currency_count,
  ROUND(AVG(exchange_rate), 4) AS avg_exchange_rate,
  MIN(ingested_at) AS first_ingested_at,
  MAX(ingested_at) AS last_ingested_at
FROM `snappy-mapper-498509-e0.analytics_lakehouse.currency_rates_gold`
GROUP BY rate_date
ORDER BY rate_date DESC;


-- Partition-Level Aggregation & Volume Check:
SELECT 
  rate_date,
  COUNT(*) AS curated_records_count,
  COUNT(DISTINCT target_currency) AS distinct_currency_count,
  ROUND(AVG(exchange_rate), 4) AS avg_exchange_rate,
  MIN(ingested_at) AS first_ingested_at,
  MAX(ingested_at) AS last_ingested_at
FROM `snappy-mapper-498509-e0.analytics_lakehouse.currency_rates_gold`
GROUP BY rate_date
ORDER BY rate_date DESC;

-- Duplicate Key Detection Check
SELECT 
  rate_date,
  base_currency,
  target_currency,
  COUNT(*) AS row_count
FROM `snappy-mapper-498509-e0.analytics_lakehouse.currency_rates_gold`
GROUP BY 1, 2, 3
HAVING row_count > 1;

-- Target Currency Whitelist & Completeness Check
-- Purpose: Verifies that only the 10 intended ISO currency codes were loaded, and checks if any currency was dropped during ingestion.  --- (Expected Result: 0 rows returned)

SELECT
  target_currency,
  COUNT(*) AS record_count,
  MIN(exchange_rate) AS min_rate,
  MAX(exchange_rate) AS max_rate
FROM `snappy-mapper-498509-e0.analytics_lakehouse.currency_rates_gold`
WHERE target_currency NOT IN ('EUR', 'INR', 'GBP', 'JPY', 'AUD', 'CAD', 'SGD', 'CHF', 'CNY', 'AED')
   OR base_currency != 'USD'
GROUP BY target_currency;


-- Date Range & Time-Anomaly Validation
-- Purpose: Ensures there are no future dates, dates outside the 5-day ingestion window, or timestamps where ingestion occurred before the rate date.  ---- (Expected Result: All counts equal 0) 

SELECT
  COUNTIF(rate_date > CURRENT_DATE()) AS future_rate_dates,
  COUNTIF(rate_date < DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)) AS stale_out_of_range_dates,
  COUNTIF(DATE(ingested_at) < rate_date) AS chronological_anomalies
FROM `snappy-mapper-498509-e0.analytics_lakehouse.currency_rates_gold`;



