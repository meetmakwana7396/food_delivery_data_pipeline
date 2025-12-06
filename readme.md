# 🚀 Food Delivery Real-Time Streaming Pipeline

This project implements a **real-time data streaming solution** for a Food Delivery platform (similar to Zomato/Swiggy).
Whenever a new food order is inserted into **PostgreSQL**, it is:

1️⃣ Detected by a **CDC Poller (Spark Producer)**
2️⃣ Published as a **JSON event into a Kafka topic**
3️⃣ Consumed by **Spark Structured Streaming**
4️⃣ Processed, cleaned & stored in **Data Lake (Parquet format)**

📌 The project follows the pipeline defined in the assignment PDF 

---

## 🏗️ Architecture — End-to-End Flow

```
PostgreSQL ➜ Spark CDC Producer ➜ Kafka Topic ➜ Spark Streaming Consumer ➜ Data Lake (Parquet)
```

### Key Design Highlights

| Component                | Role                                                      |
| ------------------------ | --------------------------------------------------------- |
| PostgreSQL               | Source table `1100089_orders`                                     |
| Spark CDC Producer       | Detects new `created_at` rows and publishes JSON to Kafka |
| Kafka                    | Topic `1100089_food_orders_raw`                      |
| Spark Streaming Consumer | Cleans + writes Parquet partitioned by date               |
| Data Lake                | Append-only storage for analytics                         |

---

## 📂 Project Folder Structure

```
1100089/food_delivery_streaming/<s3 or local>/
├── db/
│   └── orders.sql
├── producers/
│   └── orders_cdc_producer.py
├── consumers/
│   └── orders_stream_consumer.py
├── scripts/
│   ├── producer_spark_submit.sh
│   └── consumer_spark_submit.sh
├── configs/
│   └── orders_stream.yml
└── README.md   ← (this file)
```

---

## 🗄️ PostgreSQL Setup

1. Run the SQL script:

```
bash scripts/db_setup.sh
```

This will:
✔ create `orders` table
✔ insert initial sample records
✔ ensure `created_at` timestamps are populated

Later during testing, insert additional records to validate incremental ingestion.

---

## 🔄 Spark CDC Producer (PostgreSQL ➜ Kafka)

Script: `producers/orders_cdc_producer.py`

### Responsibilities

* Poll PostgreSQL every **5 seconds**
* Fetch rows where `created_at > last_processed_timestamp`
* Convert to JSON with **strict schema**
* Publish events to Kafka topic `1100089_food_orders_raw`
* Maintain timestamp state in location defined in config

---

## 📥 Spark Kafka Consumer (Kafka ➜ Data Lake)

Script: `consumers/orders_stream_consumer.py`

### Processing Logic

| Step | Action                                                       |
| ---- | ------------------------------------------------------------ |
| 1    | Read Kafka topic stream                                      |
| 2    | Parse JSON into Spark DataFrame using explicit schema        |
| 3    | Data cleaning — remove null `order_id` and negative `amount` |
| 4    | Write Parquet to Data Lake                                   |
| 5    | Partition by date (`YYYY-MM-DD` derived from `created_at`)   |
| 6    | Maintain checkpoint for state + Kafka offsets                |

---

## ⚙️ Configuration File

Location: `configs/orders_stream.yml`
Contains PostgreSQL, Kafka, Data Lake & streaming params.

> ❗ Only the variables listed in the assignment must be used to pass evaluation 

---

## ▶️ How to Run

### Start Producer

```
bash scripts/producer_spark_submit.sh
```

### Start Consumer

```
bash scripts/consumer_spark_submit.sh
```

> Both scripts internally call `spark-submit` and read `configs/orders_stream.yml`.

---

## 🧪 Incremental Testing & Evaluation

Instructor validation pattern (automated): 

| Step                            | Expected Outcome                 |
| ------------------------------- | -------------------------------- |
| Insert 5 new rows in PostgreSQL | Producer detects & publishes     |
| Run producer + consumer         | Data Lake row count increases    |
| Insert 5 more rows              | No duplicates                    |
| Repeat                          | Continuous incremental ingestion |

---

## ✔️ Final Output Expectation

Data Lake directory example:

```
datalake/food/1100089/output/orders/
└── date=2025-12-06/
       part-0000.parquet
```

Checkpoint:

```
datalake/food/1100089/checkpoints/orders/
```

Last processed timestamp:

```
datalake/food/1100089/lastprocess/orders/
```

---

## 🧰 Tech Stack Used

| Component  | Tool                           |
| ---------- | ------------------------------ |
| Database   | PostgreSQL                     |
| Messaging  | Kafka                          |
| Processing | Spark Structured Streaming     |
| Language   | Python (pyspark)               |
| Storage    | Parquet (S3 / Local Data Lake) |

---

## 👨‍💻 Author

**Name:** *Meet k. Makwana*

**Roll Number:** *2025em1100089*

---

### 📌 Notes for Evaluator

* All components are parameterized via a **single config file**
* Streaming scripts are **continuous jobs**
* **Incremental ingestion without duplication** is achieved
