# Frontend-Backend Integration Guide

This guide explains how to connect the React frontend to your BlockchainCore AWS infrastructure for real-time data updates.

## 🚀 **Real-Time Updates Overview**

The frontend supports **multiple real-time update methods**:

1. **WebSocket Connection** - True real-time updates (recommended)
2. **Polling Fallback** - Automatic fallback if WebSocket fails
3. **Hybrid Approach** - WebSocket for live data + polling for system metrics

## 📋 **Integration Steps**

### **Step 1: Deploy the API Lambda Function**

```bash
# Deploy the API handler Lambda
./scripts/deploy-api.sh
```

This creates a Lambda function that serves as your API backend, connecting to:
- **DynamoDB** - Latest OHLCV data
- **S3** - Historical data
- **CloudWatch** - System metrics
- **SNS** - Anomaly alerts

### **Step 2: Set Up API Gateway**

1. **Create API Gateway** in AWS Console
2. **Create REST API** with the following endpoints:
   ```
   GET /crypto/latest-ohlcv
   GET /crypto/historical/{symbol}
   GET /anomalies/recent
   GET /system/metrics
   ```
3. **Integrate with Lambda** function `blockchaincore-api`
4. **Enable CORS** for all endpoints

### **Step 3: Configure Frontend Environment**

Create `.env` file in the `frontend/` directory:

```env
# API Gateway URL (replace with your actual URL)
REACT_APP_AWS_API_URL=https://your-api-gateway-url.amazonaws.com/prod

# WebSocket URL (optional, for real-time updates)
REACT_APP_WS_URL=wss://your-websocket-api.amazonaws.com/prod
```

### **Step 4: Test the Integration**

```bash
cd frontend
npm start
```

Visit `http://localhost:3000` to see real-time data from your AWS infrastructure.

## 🔄 **Real-Time Update Methods**

### **Method 1: WebSocket (Recommended)**

The frontend automatically tries to connect to WebSocket for real-time updates:

```typescript
// In aws-api.ts
export const createRealTimeConnection = (onMessage: (data: any) => void) => {
  const ws = new WebSocket(wsUrl);
  
  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    onMessage(data);
  };
};
```

**Benefits:**
- True real-time updates
- Lower latency
- Reduced server load
- Better user experience

### **Method 2: Polling Fallback**

If WebSocket fails, the frontend automatically falls back to polling:

```typescript
const createPollingConnection = (onMessage: (data: any) => void) => {
  const interval = setInterval(async () => {
    const [ohlcvData, anomalies] = await Promise.all([
      fetchLatestOHLCVData(),
      fetchAnomalies()
    ]);
    
    onMessage({
      type: 'data_update',
      data: { ohlcv: ohlcvData, anomalies }
    });
  }, 5000); // Updates every 5 seconds
};
```

### **Method 3: Hybrid Approach**

The frontend uses both methods:
- **WebSocket** for live price updates and anomaly alerts
- **Polling** for system metrics and historical data

## 📊 **Data Flow**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   API Gateway   │    │   AWS Services  │
│                 │    │                 │    │                 │
│ React Dashboard │◄──►│ REST API        │◄──►│ Lambda Functions│
│                 │    │ WebSocket API   │    │                 │
│ Real-time UI    │◄──►│                 │◄──►│ DynamoDB        │
│                 │    │                 │    │ S3              │
│ Live Updates    │    │                 │    │ CloudWatch      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔧 **API Endpoints**

### **GET /crypto/latest-ohlcv**
Returns latest OHLCV data from DynamoDB:
```json
[
  {
    "symbol": "BTCUSDT",
    "timestamp": "2024-01-15T10:30:00Z",
    "open": 43250.67,
    "high": 43300.00,
    "low": 43200.00,
    "close": 43275.50,
    "volume": 28450000000
  }
]
```

### **GET /crypto/historical/{symbol}**
Returns historical data from S3:
```json
[
  {
    "symbol": "BTCUSDT",
    "timestamp": "2024-01-15T09:00:00Z",
    "open": 43200.00,
    "high": 43300.00,
    "low": 43150.00,
    "close": 43250.67,
    "volume": 28450000000
  }
]
```

### **GET /anomalies/recent**
Returns recent anomaly alerts:
```json
[
  {
    "id": "1",
    "type": "price_spike",
    "symbol": "BTCUSDT",
    "message": "Price increased by 8.5% in the last 5 minutes",
    "severity": "high",
    "timestamp": "2024-01-15T10:30:00Z",
    "price_change": 8.5
  }
]
```

### **GET /system/metrics**
Returns system health metrics:
```json
{
  "sqsQueueDepth": 15,
  "lambdaExecutions": 1250,
  "dynamoDbReads": 5000,
  "s3StorageUsed": 1024000,
  "lastUpdated": "2024-01-15T10:30:00Z"
}
```

## 🚨 **WebSocket Messages**

### **Price Update**
```json
{
  "type": "price_update",
  "data": [
    {
      "symbol": "BTCUSDT",
      "price": 43275.50,
      "timestamp": "2024-01-15T10:30:00Z"
    }
  ]
}
```

### **Anomaly Alert**
```json
{
  "type": "anomaly_alert",
  "data": {
    "id": "2",
    "type": "volume_spike",
    "symbol": "ETHUSDT",
    "message": "Volume spike detected: 3.2x above average",
    "severity": "medium",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### **Data Update**
```json
{
  "type": "data_update",
  "data": {
    "ohlcv": [...],
    "anomalies": [...]
  }
}
```

## 🔍 **Troubleshooting**

### **Frontend Shows Mock Data**
- Check if API Gateway URL is correct in `.env`
- Verify API Gateway is deployed and accessible
- Check browser console for CORS errors

### **WebSocket Connection Fails**
- Verify WebSocket API Gateway is configured
- Check if WebSocket URL is correct
- Frontend will automatically fall back to polling

### **Data Not Updating**
- Check Lambda function logs in CloudWatch
- Verify DynamoDB table has data
- Check API Gateway integration settings

### **CORS Errors**
- Ensure CORS is enabled in API Gateway
- Check that all required headers are allowed
- Verify the origin is correctly configured

## 🎯 **Performance Optimization**

### **Frontend Optimizations**
- Data is cached and only updates when changed
- WebSocket connection is reused
- Automatic reconnection on connection loss
- Efficient React state updates

### **Backend Optimizations**
- Lambda function uses connection pooling
- DynamoDB queries are optimized
- CloudWatch metrics are cached
- API Gateway caching can be enabled

## 🔐 **Security Considerations**

### **API Security**
- Use API Gateway API keys for authentication
- Implement rate limiting
- Use HTTPS for all communications
- Consider AWS Cognito for user authentication

### **Data Security**
- DynamoDB encryption at rest
- S3 bucket encryption
- IAM roles with least privilege
- VPC configuration for Lambda functions

## 📈 **Monitoring**

### **Frontend Monitoring**
- Real-time connection status
- Data update frequency
- Error rates and types
- User interaction metrics

### **Backend Monitoring**
- Lambda function performance
- API Gateway metrics
- DynamoDB read/write capacity
- SQS queue depth
- CloudWatch alarms for anomalies

## 🚀 **Next Steps**

1. **Deploy the API Lambda** using the provided script
2. **Set up API Gateway** with the required endpoints
3. **Configure environment variables** in the frontend
4. **Test the integration** with real data
5. **Monitor performance** and optimize as needed
6. **Add authentication** if required
7. **Deploy to production** using your preferred hosting service

The frontend is now ready to display real-time data from your BlockchainCore infrastructure! 🎉
