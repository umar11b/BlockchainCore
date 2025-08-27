import axios from 'axios';

// AWS API Gateway base URL - you'll need to set this up
const AWS_API_BASE_URL = process.env.REACT_APP_AWS_API_URL || 'https://your-api-gateway-url.amazonaws.com/prod';

// Create axios instance for AWS API
const awsApi = axios.create({
  baseURL: AWS_API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Types for your backend data
interface OHLCVData {
  symbol: string;
  timestamp: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

interface AnomalyAlert {
  id: string;
  type: 'price_spike' | 'volume_spike' | 'sma_divergence';
  symbol: string;
  message: string;
  severity: 'low' | 'medium' | 'high';
  timestamp: string;
  price_change?: number;
  volume_change?: number;
}

interface SystemMetrics {
  sqsQueueDepth: number;
  lambdaExecutions: number;
  dynamoDbReads: number;
  s3StorageUsed: number;
  lastUpdated: string;
}

// API functions to connect to your AWS backend
export const fetchLatestOHLCVData = async (): Promise<OHLCVData[]> => {
  try {
    // This would call your Lambda function or API Gateway endpoint
    // that queries DynamoDB for the latest OHLCV data
    const response = await awsApi.get('/crypto/latest-ohlcv');
    return response.data;
  } catch (error) {
    console.error('Error fetching OHLCV data:', error);
    throw error;
  }
};

export const fetchHistoricalData = async (
  symbol: string, 
  timeframe: string = '1h',
  limit: number = 24
): Promise<OHLCVData[]> => {
  try {
    // This would call your Lambda function that queries S3 for historical data
    const response = await awsApi.get(`/crypto/historical/${symbol}`, {
      params: { timeframe, limit }
    });
    return response.data;
  } catch (error) {
    console.error('Error fetching historical data:', error);
    throw error;
  }
};

export const fetchAnomalies = async (): Promise<AnomalyAlert[]> => {
  try {
    // This would call your Lambda function that queries SNS or stores anomalies
    const response = await awsApi.get('/anomalies/recent');
    return response.data;
  } catch (error) {
    console.error('Error fetching anomalies:', error);
    throw error;
  }
};

export const fetchSystemMetrics = async (): Promise<SystemMetrics> => {
  try {
    // This would call CloudWatch metrics or your monitoring Lambda
    const response = await awsApi.get('/system/metrics');
    return response.data;
  } catch (error) {
    console.error('Error fetching system metrics:', error);
    throw error;
  }
};

// WebSocket connection for real-time updates
export const createRealTimeConnection = (onMessage: (data: any) => void) => {
  // In production, this would connect to AWS API Gateway WebSocket API
  const wsUrl = process.env.REACT_APP_WS_URL || 'wss://your-websocket-api.amazonaws.com/prod';
  
  try {
    const ws = new WebSocket(wsUrl);
    
    ws.onopen = () => {
      console.log('WebSocket connected to AWS');
      // Subscribe to real-time updates
      ws.send(JSON.stringify({
        action: 'subscribe',
        channels: ['price_updates', 'anomaly_alerts']
      }));
    };
    
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      onMessage(data);
    };
    
    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
    
    ws.onclose = () => {
      console.log('WebSocket disconnected');
    };
    
    return {
      close: () => ws.close(),
      send: (message: any) => ws.send(JSON.stringify(message))
    };
  } catch (error) {
    console.error('Failed to create WebSocket connection:', error);
    // Fallback to polling
    return createPollingConnection(onMessage);
  }
};

// Fallback polling connection
const createPollingConnection = (onMessage: (data: any) => void) => {
  const interval = setInterval(async () => {
    try {
      const [ohlcvData, anomalies] = await Promise.all([
        fetchLatestOHLCVData(),
        fetchAnomalies()
      ]);
      
      onMessage({
        type: 'data_update',
        data: { ohlcv: ohlcvData, anomalies }
      });
    } catch (error) {
      console.error('Polling error:', error);
    }
  }, 5000); // Poll every 5 seconds
  
  return {
    close: () => clearInterval(interval),
    send: () => {} // No-op for polling
  };
};

// Utility function to format data for the frontend
export const formatCryptoData = (ohlcvData: OHLCVData[]) => {
  return ohlcvData.map(item => ({
    symbol: item.symbol,
    price: item.close,
    change24h: calculate24hChange(ohlcvData, item.symbol),
    volume24h: item.volume,
    marketCap: 0, // You'd need to fetch this separately
    lastUpdated: item.timestamp,
  }));
};

const calculate24hChange = (data: OHLCVData[], symbol: string): number => {
  const symbolData = data.filter(item => item.symbol === symbol);
  if (symbolData.length < 2) return 0;
  
  const latest = symbolData[symbolData.length - 1];
  const previous = symbolData[symbolData.length - 2];
  
  return ((latest.close - previous.close) / previous.close) * 100;
};

export default awsApi;
