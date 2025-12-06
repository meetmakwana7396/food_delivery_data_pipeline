# producers/orders_cdc_producer.py
import argparse
import time
import json
import datetime
import psycopg2
from psycopg2 import sql
import yaml
from kafka import KafkaProducer

def load_config(path):
    with open(path) as f:
        return yaml.safe_load(f)

def get_last_ts(path):
    try:
        with open(path) as f:
            return datetime.datetime.fromisoformat(f.read().strip())
    except FileNotFoundError:
        # very old past so all existing rows go once
        return datetime.datetime(1970, 1, 1)

def save_last_ts(path, ts):
    from pathlib import Path
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        f.write(ts.isoformat())

def main(config_path):
    cfg = load_config(config_path)
    pg = cfg["postgres"]
    streaming = cfg["streaming"]
    kafka_cfg = cfg["kafka"]

    producer = KafkaProducer(
        bootstrap_servers=kafka_cfg["brokers"],
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    )

    last_ts_path = streaming["last_processed_timestamp_location"]

    while True:
        last_ts = get_last_ts(last_ts_path)

        conn = psycopg2.connect(
            host=pg["host"],
            port=pg["port"],
            dbname=pg["db"],
            user=pg["user"],
            password=pg["password"],
        )
        cur = conn.cursor()

        query = sql.SQL("""
            SELECT order_id, customer_name, restaurant_name, item,
                   amount, order_status, created_at
            FROM {table}
            WHERE created_at > %s
            ORDER BY created_at ASC;
        """).format(
            table=sql.Identifier(pg["table"])
        )
        cur.execute(query, (last_ts,))

        rows = cur.fetchall()
        if rows:
            for r in rows:
                event = {
                    "order_id": r[0],
                    "customer_name": r[1],
                    "restaurant_name": r[2],
                    "item": r[3],
                    "amount": float(r[4]),
                    "order_status": r[5],
                    "created_at": r[6].isoformat(),
                }
                producer.send(kafka_cfg["topic"], event)

            # update last_ts to latest row created_at
            new_last_ts = rows[-1][6]
            save_last_ts(last_ts_path, new_last_ts)

        cur.close()
        conn.close()

        producer.flush()
        time.sleep(streaming["batch_interval"])

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    args = parser.parse_args()
    main(args.config)
