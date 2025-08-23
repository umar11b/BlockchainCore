# BlockchainCore Architecture

This directory contains the source code for the BlockchainCore real-time blockchain data analytics platform.

## System Architecture

```mermaid
flowchart LR
  %% Lanes
  subgraph IaC[Provisioning - Terraform]
    note1[All AWS resources are created by Terraform modules]
  end

  subgraph AWS[AWS Cloud]
    P[Producer: Python (Binance WS)] --> Q[SQS Standard Queue]
    Q --> L1[Lambda Processor]
    L1 -->|raw ndjson (partitioned)| S3[(S3 - Raw Bucket)]
    L1 -->|1‑min OHLCV| DDB[(DynamoDB Table)]
    S3 --> Glue[Glue Crawler]
    Glue --> Catalog[Glue Data Catalog]
    Catalog --> Athena[(Athena Queries)]
    Athena --> S3q[(S3 - Query Results)]
    EB[EventBridge\nrate(1 minute)] --> L2[Lambda Analyzer]
    L2 --> SNS[(SNS Alerts: Email/SMS)]
  end

  subgraph Ops[Operations - Bash Scripts]
    start[./scripts/start.sh]
    monitor[./scripts/monitor.sh]
    stop[./scripts/stop.sh]
  end

  %% Ops hooks
  start -. run producer/env .-> P
  monitor -. tail logs/metrics .-> L1
  stop -. stop producer/cleanup .-> P
```

## Directory Structure

```
src/
├── lambda/
│   ├── anomaly/
│   │   └── detector.py          # Anomaly detection Lambda function
│   └── processor/
│       └── processor.py         # Data processing Lambda function
├── producer/
│   └── main.py                  # Binance WebSocket producer
└── utils/
    └── aws_helpers.py           # AWS utility functions
```

## Components

### Data Producer (`producer/main.py`)
- Connects to Binance WebSocket API
- Streams real-time BTC/USDT trade data
- Sends messages to SQS queue
- Handles connection management and error recovery

### Lambda Processor (`lambda/processor/processor.py`)
- Processes SQS messages in batches
- Calculates 1-minute OHLCV (Open, High, Low, Close, Volume)
- Stores raw data in S3 (partitioned by date/hour)
- Stores processed data in DynamoDB
- Handles data validation and error processing

### Anomaly Detector (`lambda/anomaly/detector.py`)
- Triggered by EventBridge every minute
- Analyzes recent OHLCV data from DynamoDB
- Detects price movements, volume spikes, and SMA divergences
- Sends alerts via SNS for detected anomalies

### AWS Utilities (`utils/aws_helpers.py`)
- Common AWS service interactions
- Error handling and retry logic
- Data formatting and validation helpers

## Data Flow

1. **Ingestion**: Producer connects to Binance WebSocket and streams trade data
2. **Queue**: Messages are buffered in SQS Standard Queue
3. **Processing**: Lambda Processor processes messages and calculates OHLCV
4. **Storage**: Raw data goes to S3, processed data to DynamoDB
5. **Analytics**: Glue Crawler catalogs S3 data for Athena queries
6. **Monitoring**: Anomaly detector runs every minute to check for unusual patterns
7. **Alerting**: SNS sends notifications for detected anomalies

## Operations

The system is managed through bash scripts in the root `scripts/` directory:

- **Start**: Deploys infrastructure and starts producer
- **Monitor**: Interactive dashboard for system monitoring
- **Stop**: Safely shuts down all components and cleans up resources
