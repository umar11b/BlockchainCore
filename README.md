# BlockchainCore: Real-Time Blockchain Data Analytics on AWS

A comprehensive real-time data pipeline for ingesting, processing, and analyzing live cryptocurrency trade data using AWS services.

NOTE: Git commit history is gone since main branch was changed

## 📋 Table of Contents

### 🚀 Getting Started

- [Architecture Overview](#architecture-overview)
- [Project Status](#-project-status)
- [Project Roadmap](#️-project-roadmap-future-plans)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)

### ⚙️ Configuration & Management

- [Configuration](#configuration)
- [Monitoring](#monitoring)
- [Technology Choices](#technology-choice-sqs--lambda-vs-alternatives)

### 🛠️ Development & Operations

- [Development](#development)
- [Security](#security)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](docs/troubleshooting.md)

### 📚 Documentation & Support

- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

---

[↑ Back to Top](#blockchaincore-real-time-blockchain-data-analytics-on-aws)

## Architecture Overview

![Architecture Diagram](BlockchainCore.jpeg)

**Architecture Flow:**

- 🔧 **Infrastructure**: Terraform provisions all AWS resources
- 📡 **Ingestion**: Binance WebSocket → Python Producer → SQS Queue
- ⚡ **Processing**: Lambda processes messages → stores in S3 + DynamoDB
- 📊 **Analytics**: Glue crawls S3 → Athena queries historical data
- 🚨 **Monitoring**: EventBridge triggers anomaly detection → SNS alerts
- 📈 **Observability**: CloudWatch collects logs and metrics from all services
- 🖥️ **Frontend**: React dashboard with real-time data visualization

**Frontend Architecture:**

- **React 18** with TypeScript for type safety
- **Material-UI v5** for professional dark theme design
- **Recharts** for interactive cryptocurrency price charts
- **Axios** for API communication with AWS backend
- **Real-time polling** with 1-second updates for live data
- **Responsive design** that works on desktop and mobile

## 📊 Project Status

| Component                      | Status      | Notes                                              |
| ------------------------------ | ----------- | -------------------------------------------------- |
| **Infrastructure (Terraform)** | ✅ Complete | SQS, Lambda, DynamoDB, S3, EventBridge deployed    |
| **Data Producer**              | ✅ Complete | Binance WebSocket → SQS streaming working          |
| **Data Processor**             | ✅ Complete | SQS → OHLCV → DynamoDB/S3 processing               |
| **Anomaly Detection**          | ✅ Complete | EventBridge → Lambda → SNS alerts                  |
| **Cost Optimization**          | ✅ Complete | Migrated from Kinesis to SQS (~$13/month savings)  |
| **Monitoring & Logging**       | ✅ Complete | CloudWatch metrics and logs active                 |
| **Frontend Dashboard**         | ✅ Complete | Interactive React dashboard with real-time data    |
| **Multi-Symbol Support**       | 📋 Planned  | Add ETH, ADA, and other trading pairs              |
| **Advanced Analytics**         | 📋 Planned  | ML-based anomaly detection                         |
| **Mobile Alerts**              | 📋 Planned  | Push notifications for anomalies                   |
| **Script Improvements**        | 📋 Planned  | Fix EventBridge deletion issues, add WebSocket API |

## 📝 TODO & Known Issues

### 🔧 **Infrastructure Scripts**

- [ ] **Fix EventBridge deletion**: Currently requires manual target removal before rule deletion
- [ ] **Add WebSocket API Gateway**: For true real-time frontend updates instead of polling
- [ ] **Improve timeout handling**: Better macOS compatibility for timeout commands
- [ ] **Add force destroy option**: Skip confirmation for automated deployments

### 🐛 **Known Issues**

- [ ] **Lambda hanging**: Sometimes Lambda deployment hangs during function creation
- [ ] **S3 bucket cleanup**: Occasional issues with versioned bucket cleanup
- [ ] **Terraform state conflicts**: Resources sometimes get stuck in deletion

### 🔗 **Quick Fixes**

- **EventBridge stuck?** → [Manual cleanup guide](docs/troubleshooting.md#eventbridge-cleanup)
- **Lambda hanging?** → [Skip and retry](docs/troubleshooting.md#lambda-hanging)
- **S3 cleanup issues?** → [Force bucket deletion](docs/troubleshooting.md#s3-cleanup)

## 🗺️ Project Roadmap (Future Plans)

### Multi-Cloud Architecture

| Cloud Platform    | Components                              | Status     | Description                                         |
| ----------------- | --------------------------------------- | ---------- | --------------------------------------------------- |
| **Azure**         | Event Hubs → Functions → Blob → Synapse | 📋 Planned | Azure-native data pipeline with real-time analytics |
| **Homelab (k3s)** | NATS/Redpanda + MinIO + Grafana         | 📋 Planned | Self-hosted streaming and storage with monitoring   |

### Azure Implementation Plan

| Component      | Technology         | Purpose                    | Integration                            |
| -------------- | ------------------ | -------------------------- | -------------------------------------- |
| **Event Hubs** | Azure Event Hubs   | Real-time data ingestion   | Replace SQS for Azure pipeline         |
| **Functions**  | Azure Functions    | Serverless processing      | Replace Lambda for data transformation |
| **Storage**    | Azure Blob Storage | Data lake storage          | Replace S3 for raw data storage        |
| **Analytics**  | Azure Synapse      | Data warehouse & analytics | Replace Athena for advanced queries    |
| **Monitoring** | Azure Monitor      | Observability              | Replace CloudWatch for metrics         |

### Homelab (k3s) Implementation Plan

| Component         | Technology    | Purpose                 | Integration                   |
| ----------------- | ------------- | ----------------------- | ----------------------------- |
| **Streaming**     | NATS/Redpanda | Message streaming       | Alternative to SQS/Event Hubs |
| **Storage**       | MinIO         | S3-compatible storage   | Self-hosted object storage    |
| **Monitoring**    | Grafana       | Visualization & alerts  | Real-time dashboards          |
| **Orchestration** | k3s           | Container orchestration | Kubernetes-based deployment   |

### Cross-Cloud Benefits

- **Resilience**: Multi-cloud redundancy for high availability
- **Cost Optimization**: Leverage best pricing across providers
- **Performance**: Geographic distribution for lower latency
- **Learning**: Hands-on experience with multiple cloud platforms
- **Control**: Self-hosted components for data sovereignty

[↑ Back to Top](#blockchaincore-real-time-blockchain-data-analytics-on-aws)

## Technology Choice: SQS + Lambda vs Alternatives

| Technology               | Monthly Cost (Baseline)    | Best For                                             | Trade-offs                             | Why We Chose SQS                          |
| ------------------------ | -------------------------- | ---------------------------------------------------- | -------------------------------------- | ----------------------------------------- |
| **Kinesis Data Streams** | ~$13-15 (fixed shard cost) | High-throughput, multiple consumers, strict ordering | Expensive idle cost, shard management  | Too expensive for our scale               |
| **SQS + Lambda** ✅      | ~$10-12 (pay-per-request)  | Single consumer, simple processing, cost-effective   | No replay capability, single consumer  | **Most cost-effective for our use case**  |
| **Kinesis Firehose**     | ~$1-3 (archival only)      | Direct S3 archival, Parquet conversion               | Sink-oriented, needs separate hot path | Good complement but not complete solution |

**Our Choice: SQS + Lambda**

- Eliminates fixed monthly costs (~$13/month savings)
- Perfect for single consumer pattern (processor → S3 + DynamoDB)
- Sub-second latency is sufficient for our needs
- Scales linearly with usage
- Simple operations and maintenance

[↑ Back to Top](#blockchaincore-real-time-blockchain-data-analytics-on-aws)

## Features

- **Real-time Data Ingestion**: Live cryptocurrency trade data from Binance WebSocket API
- **Message Processing**: AWS SQS + Lambda for cost-effective, scalable data processing
- **Data Storage**:
  - Raw trade data in S3 (partitioned by date/hour)
  - Cleaned OHLCV data in DynamoDB
- **Data Analytics**: AWS Glue Catalog + Athena for historical data queries
- **Anomaly Detection**: Automated detection of price movements, volume spikes, and SMA divergences
- **Alerting**: SNS notifications for detected anomalies
- **Frontend Dashboard**: Interactive React dashboard with real-time cryptocurrency data visualization
- **Interactive Charts**: Clickable cryptocurrency cards with 1H/24H price charts
- **Real-time Updates**: Live data polling with visual feedback
- **Professional UI**: Material-UI dark theme with responsive design
- **Infrastructure as Code**: Terraform for AWS resource management
- **CI/CD**: GitHub Actions for automated deployments

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Python 3.9+
- Node.js 18+ (for frontend development)
- Docker (for local development)
- GitHub repository with Actions enabled

[↑ Back to Top](#blockchaincore-real-time-blockchain-data-analytics-on-aws)

## Quick Start

### 🚀 **Easy Management Scripts**

We've created convenient scripts to manage your infrastructure safely:

#### **1. Start Everything (Infrastructure + Producer)**

```bash
./scripts/start-infrastructure.sh
```

- ✅ **Deploys all AWS infrastructure**
- ✅ **Automatically starts the data producer**
- ✅ **Creates `.env` file with environment variables**
- ✅ **Shows important URLs and configuration**
- ✅ **Everything runs with one command!**

#### **2. Monitor Everything**

```bash
./scripts/monitor.sh
```

- Interactive dashboard for monitoring
- Check SQS, DynamoDB, S3, Lambda status
- View logs and cost estimates
- Real-time log following

#### **3. Stop Everything (SAFE SHUTDOWN)**

```bash
./scripts/stop-infrastructure.sh
```

- **Safely destroys all infrastructure**
- **Stops all costs immediately**
- **Requires confirmation to prevent accidents**
- **Complete cleanup including S3 bucket versions**
- **Enhanced verification reporting**

#### **4. Frontend Development**

```bash
cd frontend
npm install
npm start
```

- **Interactive cryptocurrency dashboard**
- **Real-time data updates every 1 second**
- **Clickable cryptocurrency cards**
- **Professional Material-UI design**
- **1H/24H interactive price charts**

#### **Frontend Development Output**

```bash
$ cd frontend && npm start

Compiled successfully!

You can now view blockchaincore in the browser.

  Local:            http://localhost:3000
  On Your Network:  http://192.168.1.100:3000

Note that the development build is not optimized.
To create a production build, use npm run build.

✅ Real-time data polling every 1 second
✅ Interactive cryptocurrency selection
✅ Professional Material-UI dark theme
✅ Responsive design for all devices
```

**Shutdown Options:**

- `yes` - Full cleanup (including S3 bucket)
- `fast` - Quick shutdown (skip S3 cleanup)
- `cancel` - Cancel operation

##### **Performance Comparison**

| Method            | Time             | S3 Cleanup           | Use Case           |
| ----------------- | ---------------- | -------------------- | ------------------ |
| **Fast Shutdown** | ~30 seconds      | Skipped              | Quick cost control |
| **Full Cleanup**  | Minutes to hours | Bulk deletion        | Complete cleanup   |
| **Old Method**    | Hours to days    | Individual deletions | Legacy approach    |

**Examples:**

```bash
# Fast shutdown (recommended for daily use)
echo "fast" | ./scripts/stop-infrastructure.sh

# Full cleanup (thorough cleanup)
echo "yes" | ./scripts/stop-infrastructure.sh

# Interactive (choose at runtime)
./scripts/stop-infrastructure.sh
```

### 🛠️ **Enhanced Infrastructure Management**

Our infrastructure scripts now include:

- **Retry Logic**: Automatic retry with timeout for Terraform operations
- **Force Cleanup**: Removes stuck resources that prevent deletion
- **Comprehensive Verification**: Detailed reporting of what was destroyed
- **macOS Compatibility**: Works on both Linux and macOS systems
- **Error Handling**: Graceful handling of AWS API failures

### 📺 **Terminal Output Examples**

#### **Monitor Script Output**

```bash
$ ./scripts/monitor.sh

╔══════════════════════════════════════════════════════════════╗
║                BlockchainCore Monitoring                     ║
╚══════════════════════════════════════════════════════════════╝

[INFO] Checking AWS configuration...
[SUCCESS] AWS CLI configured

📊 Infrastructure Status:
✅ SQS Queue: blockchain-core-trade-data (0 messages)
✅ DynamoDB Table: blockchain-core-ohlcv-data (1,247 items)
✅ S3 Bucket: blockchain-core-raw-data-abc123 (2.3 GB)
✅ Lambda Functions: 2 active (processor, anomaly-detector)
✅ EventBridge Rule: blockchain-core-anomaly-detection (ENABLED)

💰 Estimated Monthly Cost: $12.45
📈 Data Processing: 1,247 OHLCV records today
🚨 Recent Alerts: 3 anomalies detected in last hour

📋 Monitoring Options:
1. View SQS Queue Status
2. Check DynamoDB Data
3. Monitor S3 Storage
4. View Lambda Logs
5. Check EventBridge Rules
6. Monitor CloudWatch Metrics
7. View Recent Anomalies
8. Cost Analysis
9. Exit

Enter your choice (1-9):
```

#### **Stop Infrastructure Output**

```bash
$ ./scripts/stop-infrastructure.sh

🛑 Stopping BlockchainCore Infrastructure...
==========================================
  BlockchainCore Complete Shutdown
==========================================

[WARNING] ⚠️  WARNING: This will destroy ALL infrastructure and data!
[WARNING]    This action cannot be undone.

Options:
  'yes'     - Full cleanup (including S3 bucket)
  'fast'    - Quick shutdown (skip S3 cleanup)
  'cancel'  - Cancel operation

Choose option: yes
[INFO] Destroying infrastructure...
[INFO] Checking AWS configuration...
[SUCCESS] AWS CLI configured
[INFO] Checking Terraform installation...
[SUCCESS] Terraform found: Terraform v1.5.7
[INFO] Checking if infrastructure exists...
[SUCCESS] Infrastructure found
[INFO] Stopping any running producers...
[SUCCESS] No running producer processes found
[INFO] Cleaning up orphaned resources...
[INFO] Checking for orphaned DynamoDB tables...
[INFO] Deleting orphaned DynamoDB table: blockchain-core-ohlcv-data
[INFO] Checking for orphaned Lambda functions...
[INFO] Deleting orphaned Lambda function: blockchain-core-anomaly-detector
[INFO] Deleting orphaned Lambda function: blockchain-core-processor
[SUCCESS] Orphaned resources cleanup completed

🔍 Destruction Verification Report
==================================
✅ Terraform state: All resources destroyed
✅ DynamoDB: No blockchain-core tables found
✅ Lambda: No blockchain-core functions found
✅ SQS: No blockchain-core queues found
✅ S3: No blockchain-core buckets found
✅ SNS: No blockchain-core topics found
✅ CloudWatch Events: No blockchain-core rules found
✅ IAM: No blockchain-core roles found

📊 Destruction Summary:
======================
🎉 SUCCESS: All infrastructure has been completely destroyed!

💰 Cost Savings:
================
✅ No more SQS charges
✅ No more Lambda charges
✅ No more DynamoDB charges
✅ No more S3 charges (except minimal storage)
✅ No more CloudWatch charges
✅ No more EventBridge charges

Your monthly AWS bill should now be minimal!
```

### 📋 **Manual Steps (Alternative)**

If you prefer manual control:

1. **Clone and Setup**:

   ```bash
   git clone <repository-url>
   cd BlockchainCore
   pip install -r requirements.txt
   ```

2. **Configure AWS**:

   ```bash
   aws configure
   ```

3. **Deploy Infrastructure**:

   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

4. **Deploy Lambda Functions**:

   ```bash
   # This will be automated via GitHub Actions
   # or run manually:
   ./scripts/deploy-lambda.sh
   ```

5. **Start Data Producer**:
   ```bash
   python src/producer/main.py
   ```

## Configuration

### Environment Variables

- `BINANCE_WEBSOCKET_URL`: Binance WebSocket endpoint
- `SQS_QUEUE_URL`: AWS SQS queue URL for data processing
- `S3_BUCKET_NAME`: S3 bucket for raw data storage
- `DYNAMODB_TABLE_NAME`: DynamoDB table for OHLCV data
- `SNS_TOPIC_ARN`: SNS topic for alerts

### Anomaly Detection Parameters

- Price movement threshold: 5%
- Volume spike threshold: 3x average
- SMA divergence threshold: 2%
- Analysis window: 1 minute

[↑ Back to Top](#blockchaincore-real-time-blockchain-data-analytics-on-aws)

## Monitoring

- **CloudWatch Metrics**: SQS queue depth, Lambda execution times, error rates
- **CloudWatch Logs**: Detailed logging for all Lambda functions
- **SNS Alerts**: Real-time notifications for anomalies and system issues

## Development

### Local Development

```bash
# Start local development environment
docker-compose up -d

# Run tests
pytest tests/

# Format code
black src/
isort src/
```

### Adding New Data Sources

1. Create a new producer in `src/producer/`
2. Update the SQS queue configuration
3. Modify the processor Lambda if needed
4. Update Terraform configuration

### Adding New Anomaly Detection Rules

1. Modify `src/lambda/anomaly/detector.py`
2. Add new detection logic
3. Update SNS notification format if needed
4. Deploy updated Lambda function

## Security

- IAM roles with least privilege access
- VPC configuration for Lambda functions
- KMS encryption for sensitive data
- CloudTrail logging for audit trails

[↑ Back to Top](#blockchaincore-real-time-blockchain-data-analytics-on-aws)

## Cost Optimization

- S3 lifecycle policies for data retention
- DynamoDB on-demand billing
- Lambda function optimization
- CloudWatch log retention policies

## Troubleshooting

For detailed troubleshooting information, see our [Troubleshooting Guide](docs/troubleshooting.md).

Common issues include:

- Producer WebSocket connection problems
- DynamoDB data type errors
- SQS queue issues
- Lambda function processing errors
- Script execution problems

[↑ Back to Top](#blockchaincore-real-time-blockchain-data-analytics-on-aws)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

[↑ Back to Top](#blockchaincore-real-time-blockchain-data-analytics-on-aws)

## Support

For issues and questions:

- Create a GitHub issue
- Check the [Troubleshooting Guide](docs/troubleshooting.md)
- Review CloudWatch logs for detailed error information

[↑ Back to Top](#blockchaincore-real-time-blockchain-data-analytics-on-aws)
