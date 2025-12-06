#!/usr/bin/env bash
source ~/.bashrc
source ~/bits/DSP/assignment-2/de_env/bin/activate

spark-submit \
  --master local[*] \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1,org.postgresql:postgresql:42.7.3 \
  producers/orders_cdc_producer.py \
  --config configs/orders_stream.yml
