import datetime
import json
import functions_framework
import requests
from google.cloud import storage

PROJECT_ID = "snappy-mapper-498509-e0"
LANDING_BUCKET = "it-prod-landing-as1-raw"   # Bronze
CURATED_BUCKET = "it-prod-curated-as1-clean"   # Silver
API_URL = "https://open.er-api.com/v6/latest/USD"

@functions_framework.http
def fetch_and_stage_rates(request):
    #entry point is: fetch_and_stage_rates
    # 1. Fetch live rates from external API
    response = requests.get(API_URL, timeout=30)
    response.raise_for_status()
    raw_api_payload = response.json()
    rates_data = raw_api_payload.get("rates", {})

    target_currencies = ["EUR", "INR", "GBP", "JPY", "AUD", "CAD", "SGD", "CHF", "CNY", "AED"]
    client = storage.Client(project=PROJECT_ID)
    landing_bkt = client.bucket(LANDING_BUCKET)
    curated_bkt = client.bucket(CURATED_BUCKET)

    base_time = datetime.datetime.now(datetime.timezone.utc)
    staged_files = []

    # 2. Process 5 consecutive days
    for day_offset in range(5):
        simulated_time = base_time - datetime.timedelta(days=day_offset)
        rate_date_str = simulated_time.strftime("%Y-%m-%d")
        now_ts = datetime.datetime.now(datetime.timezone.utc).isoformat()
        time_tag = int(simulated_time.timestamp())

        # --- A. WRITE UNMODIFIED RAW DATA TO BRONZE / LANDING ---
        raw_partition = simulated_time.strftime("raw_events/year=%Y/month=%m/day=%d/hour=%H")
        raw_blob = landing_bkt.blob(f"{raw_partition}/raw_payload_{time_tag}.json")
        raw_blob.upload_from_string(json.dumps(raw_api_payload), content_type="application/json")

        # --- B. WRITE CLEANSED, VALIDATED DATA TO SILVER / CURATED ---
        curated_records = [
            {
                "base_currency": "USD",
                "target_currency": curr,
                "exchange_rate": round(float(rates_data.get(curr, 1.0)) * (1.0 + (day_offset * 0.002)), 4),
                "rate_date": rate_date_str,
                "ingested_at": now_ts
            }
            for curr in target_currencies if curr in rates_data
        ]

        curated_partition = simulated_time.strftime("curated_events/year=%Y/month=%m/day=%d/hour=%H")
        curated_filename = f"{curated_partition}/rates_{time_tag}.jsonl"
        curated_jsonl = "\n".join([json.dumps(r) for r in curated_records])

        curated_blob = curated_bkt.blob(curated_filename)
        curated_blob.upload_from_string(curated_jsonl, content_type="application/x-ndjson")
        staged_files.append(curated_filename)

    return f"Successfully generated 5 days of data into Bronze ({LANDING_BUCKET}) and Silver ({CURATED_BUCKET}).", 200
