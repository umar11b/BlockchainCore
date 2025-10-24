# Multi-Cloud Architecture: AWS + GCP

## 🏗️ **Architecture Overview**

This project implements a **multi-cloud architecture** using both AWS and Google Cloud Platform (GCP) to demonstrate advanced cloud engineering practices, resilience, and cost optimization.

### **Architecture Diagram**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Multi-Cloud Architecture                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐              ┌─────────────────┐          │
│  │   AWS Stack     │              │   GCP Stack     │          │
│  │                 │              │                 │          │
│  │ ┌─────────────┐ │              │ ┌─────────────┐ │          │
│  │ │   SQS       │ │              │ │ Pub/Sub    │ │          │
│  │ └─────────────┘ │              │ └─────────────┘ │          │
│  │        │        │              │        │        │          │
│  │ ┌─────────────┐ │              │ ┌─────────────┐ │          │
│  │ │   Lambda    │ │              │ │Cloud Function│ │          │
│  │ └─────────────┘ │              │ └─────────────┘ │          │
│  │        │        │              │        │        │          │
│  │ ┌─────────────┐ │              │ ┌─────────────┐ │          │
│  │ │ DynamoDB    │ │              │ │ Firestore  │ │          │
│  │ └─────────────┘ │              │ └─────────────┘ │          │
│  │        │        │              │        │        │          │
│  │ ┌─────────────┐ │              │ ┌─────────────┐ │          │
│  │ │     S3      │ │              │ │Cloud Storage│ │          │
│  │ └─────────────┘ │              │ └─────────────┘ │          │
│  └─────────────────┘              └─────────────────┘          │
│           │                                │                   │
│           └──────────────┬─────────────────┘                   │
│                          │                                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Cross-Cloud Synchronization                   │ │
│  │                                                             │ │
│  │  • Data Replication (AWS ↔ GCP)                             │ │
│  │  • Failover Mechanisms                                     │ │
│  │  • Cost Optimization                                       │ │
│  │  • Monitoring & Alerting                                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 **Key Benefits**

### **1. Resilience & High Availability**

- **Multi-cloud redundancy**: If one cloud fails, the other continues
- **Geographic distribution**: Different regions for better latency
- **Disaster recovery**: True cross-cloud backup and recovery

### **2. Cost Optimization**

- **GCP Free Tier**: $0/month for most services
- **AWS Pay-as-you-go**: Only pay for what you use
- **Load balancing**: Route traffic to cheapest available cloud
- **Cost monitoring**: Track spending across both clouds

### **3. Vendor Lock-in Mitigation**

- **Cloud-agnostic patterns**: Learn multiple cloud platforms
- **Portable code**: Easy migration between clouds
- **Skills development**: Valuable for career advancement

### **4. Performance Optimization**

- **Latency reduction**: Route to nearest cloud region
- **Load distribution**: Balance traffic across clouds
- **Auto-scaling**: Scale independently on each cloud

## 🛠️ **Technology Stack**

### **AWS Components**

- **SQS**: Message queuing service
- **Lambda**: Serverless compute
- **DynamoDB**: NoSQL database
- **S3**: Object storage
- **EventBridge**: Event routing
- **CloudWatch**: Monitoring

### **GCP Components**

- **Pub/Sub**: Message queuing service
- **Cloud Functions**: Serverless compute
- **Firestore**: NoSQL database
- **Cloud Storage**: Object storage
- **Cloud Scheduler**: Event scheduling
- **Cloud Monitoring**: Monitoring

### **Cross-Cloud Tools**

- **Terraform**: Infrastructure as Code
- **Docker**: Containerization
- **GitHub Actions**: CI/CD
- **Custom Scripts**: Cross-cloud synchronization

## 📊 **Cost Comparison**

| Service   | AWS Cost      | GCP Free Tier | Monthly Savings |
| --------- | ------------- | ------------- | --------------- |
| Functions | $0.20/1M      | 2M free       | $0.40           |
| Storage   | $0.023/GB     | 5GB free      | $0.115          |
| Database  | $0.25/GB      | 1GB free      | $0.25           |
| Messaging | $0.40/1M      | 10GB free     | $4.00           |
| **Total** | **~$5/month** | **$0/month**  | **$5/month**    |

## 🚀 **Quick Start**

### **1. Deploy AWS Infrastructure**

```bash
# Deploy AWS stack
./scripts/start-infrastructure.sh

# Start AWS producer
./scripts/subscripts/start-producer.sh
```

### **2. Deploy GCP Infrastructure**

```bash
# Deploy GCP stack
./scripts/deploy-gcp.sh

# Start GCP producer
source .env.gcp && python3 src/producer/gcp_producer.py
```

### **3. Start Multi-Cloud Architecture**

```bash
# Start both producers
./scripts/cross-cloud-sync.sh start

# Monitor status
./scripts/cross-cloud-sync.sh monitor

# Check status
./scripts/cross-cloud-sync.sh status
```

## 📁 **Project Structure**

```
BlockchainCore/
├── terraform/                 # AWS Infrastructure
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── terraform-gcp/            # GCP Infrastructure
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── src/
│   ├── lambda/               # AWS Lambda functions
│   │   ├── processor/
│   │   └── processor-gcp/    # GCP Cloud Functions
│   └── producer/
│       ├── main.py           # AWS producer
│       └── gcp_producer.py   # GCP producer
├── scripts/
│   ├── start-infrastructure.sh    # AWS deployment
│   ├── deploy-gcp.sh             # GCP deployment
│   └── cross-cloud-sync.sh       # Multi-cloud management
├── .env                       # AWS environment
├── .env.gcp                   # GCP environment
└── docs/
    └── multi-cloud-architecture.md
```

## 🔧 **Configuration**

### **AWS Environment (.env)**

```bash
# AWS Configuration
AWS_REGION=us-east-1
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/...
DYNAMODB_TABLE=blockchain-core-ohlcv-data
S3_BUCKET=blockchain-core-raw-data-...
TRADING_SYMBOL=BTCUSDT
```

### **GCP Environment (.env.gcp)**

```bash
# GCP Configuration
GCP_PROJECT_ID=your-project-id
GCP_REGION=us-central1
PUBSUB_TOPIC=blockchain-core-trade-data
STORAGE_BUCKET=blockchain-core-raw-data-...
FIRESTORE_DATABASE=blockchain-core-ohlcv-data
TRADING_SYMBOL=BTCUSDT
```

## 📈 **Monitoring & Observability**

### **AWS Monitoring**

- **CloudWatch**: Metrics, logs, alarms
- **X-Ray**: Distributed tracing
- **Cost Explorer**: Cost analysis

### **GCP Monitoring**

- **Cloud Monitoring**: Metrics, logs, alerts
- **Cloud Trace**: Distributed tracing
- **Billing**: Cost analysis

### **Cross-Cloud Monitoring**

- **Custom dashboards**: Unified view
- **Alerting**: Cross-cloud notifications
- **Cost optimization**: Automated recommendations

## 🔄 **Data Flow**

### **1. Data Ingestion**

```
Binance WebSocket → AWS Producer → SQS
                 → GCP Producer → Pub/Sub
```

### **2. Data Processing**

```
SQS → Lambda → DynamoDB
Pub/Sub → Cloud Function → Firestore
```

### **3. Data Storage**

```
Raw Data: S3 + Cloud Storage
Processed Data: DynamoDB + Firestore
```

### **4. Cross-Cloud Sync**

```
AWS → GCP: Data replication
GCP → AWS: Data replication
```

## 🚨 **Disaster Recovery**

### **Failover Scenarios**

1. **AWS Outage**: Traffic routes to GCP
2. **GCP Outage**: Traffic routes to AWS
3. **Regional Outage**: Cross-region failover
4. **Service Outage**: Service-level failover

### **Recovery Procedures**

1. **Automated**: Health checks and auto-failover
2. **Manual**: Admin-triggered failover
3. **Data Recovery**: Cross-cloud data restoration
4. **Monitoring**: Real-time status updates

## 💡 **Best Practices**

### **1. Infrastructure as Code**

- **Terraform**: Declarative infrastructure
- **Version control**: Track all changes
- **Modular design**: Reusable components

### **2. Security**

- **IAM roles**: Least privilege access
- **Encryption**: Data at rest and in transit
- **Network security**: VPCs and firewalls

### **3. Cost Optimization**

- **Resource tagging**: Track costs by project
- **Auto-scaling**: Scale based on demand
- **Reserved instances**: Long-term cost savings

### **4. Monitoring**

- **Health checks**: Automated monitoring
- **Alerting**: Proactive issue detection
- **Logging**: Centralized log management

## 🎯 **Next Steps**

### **Phase 1: Basic Multi-Cloud** ✅

- [x] AWS infrastructure
- [x] GCP infrastructure
- [x] Cross-cloud producers
- [x] Data synchronization

### **Phase 2: Advanced Features** 🔄

- [ ] WebSocket API Gateway
- [ ] Real-time frontend updates
- [ ] Advanced analytics
- [ ] ML-based anomaly detection

### **Phase 3: Enterprise Features** 📋

- [ ] Multi-region deployment
- [ ] Advanced security
- [ ] Compliance features
- [ ] Enterprise monitoring

## 📚 **Resources**

### **Documentation**

- [AWS Documentation](https://docs.aws.amazon.com/)
- [GCP Documentation](https://cloud.google.com/docs)
- [Terraform Documentation](https://terraform.io/docs)

### **Learning Resources**

- [AWS Free Tier](https://aws.amazon.com/free/)
- [GCP Free Tier](https://cloud.google.com/free)
- [Multi-Cloud Best Practices](https://cloud.google.com/architecture)

### **Tools**

- [Terraform](https://terraform.io/)
- [Docker](https://docker.com/)
- [GitHub Actions](https://github.com/features/actions)

---

**🎉 Congratulations!** You now have a production-ready multi-cloud architecture that demonstrates advanced cloud engineering skills and best practices.
