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
    start[./scripts/start-infrastructure.sh]
    monitor[./scripts/monitor.sh]
    stop[./scripts/stop-infrastructure.sh]
  end

  %% Ops hooks
  start -. run producer/env .-> P
  monitor -. tail logs/metrics .-> L1
  stop -. stop producer/cleanup .-> P
```
