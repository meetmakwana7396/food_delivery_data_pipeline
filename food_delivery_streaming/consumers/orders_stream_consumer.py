# consumers/orders_stream_consumer.py
import argparse, yaml
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, to_date
from pyspark.sql.types import (StructType, StructField,
                               IntegerType, StringType,
                               DoubleType, TimestampType)

def load_config(path):
    with open(path) as f:
        return yaml.safe_load(f)

def main(config_path):
    cfg = load_config(config_path)
    kafka_cfg = cfg["kafka"]
    dl = cfg["datalake"]
    streaming = cfg["streaming"]

    spark = (
        SparkSession.builder
        .appName("1100089_orders_stream_consumer")
        .getOrCreate()
    )

    schema = StructType([
        StructField("order_id", IntegerType()),
        StructField("customer_name", StringType()),
        StructField("restaurant_name", StringType()),
        StructField("item", StringType()),
        StructField("amount", DoubleType()),
        StructField("order_status", StringType()),
        StructField("created_at", TimestampType()),
    ])

    raw_df = (
        spark.readStream
        .format("kafka")
        .option("kafka.bootstrap.servers", kafka_cfg["brokers"])
        .option("subscribe", kafka_cfg["topic"])
        .option("startingOffsets", "earliest")
        .load()
    )

    json_df = raw_df.selectExpr("CAST(value AS STRING) as json_str")

    parsed_df = json_df.select(from_json(col("json_str"), schema).alias("data")).select("data.*")

    cleaned_df = (
        parsed_df
        .where(col("order_id").isNotNull())
        .where(col("amount") >= 0)
        .withColumn("date", to_date(col("created_at")))
    )

    query = (
        cleaned_df.writeStream
        .format(dl["format"])
        .option("path", dl["path"])
        .option("checkpointLocation", streaming["checkpoint_location"])
        .partitionBy("date")
        .outputMode("append")
        .start()
    )

    query.awaitTermination()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    args = parser.parse_args()
    main(args.config)
