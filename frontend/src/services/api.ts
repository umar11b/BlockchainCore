import axios from "axios";

// API base URL - in production this would point to your AWS API Gateway
const API_BASE_URL =
  process.env.REACT_APP_API_URL || "http://localhost:3001/api";

// Create axios instance with default config
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    "Content-Type": "application/json",
  },
});

// Mock data for development - replace with real API calls
const mockCryptoData = [
  {
    symbol: "BTCUSDT",
    price: 43250.67,
    change24h: 2.34,
    volume24h: 28450000000,
    marketCap: 847000000000,
    lastUpdated: new Date().toISOString(),
  },
  {
    symbol: "ETHUSDT",
    price: 2650.89,
    change24h: -1.23,
    volume24h: 15600000000,
    marketCap: 318000000000,
    lastUpdated: new Date().toISOString(),
  },
  {
    symbol: "ADAUSDT",
    price: 0.4856,
    change24h: 5.67,
    volume24h: 890000000,
    marketCap: 17200000000,
    lastUpdated: new Date().toISOString(),
  },
  {
    symbol: "DOTUSDT",
    price: 7.23,
    change24h: -0.89,
    volume24h: 450000000,
    marketCap: 8500000000,
    lastUpdated: new Date().toISOString(),
  },
];

const mockAnomalies = [
  {
    id: "1",
    type: "price_spike" as const,
    symbol: "BTCUSDT",
    message: "Price increased by 8.5% in the last 5 minutes",
    severity: "high" as const,
    timestamp: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
  },
  {
    id: "2",
    type: "volume_spike" as const,
    symbol: "ETHUSDT",
    message: "Volume spike detected: 3.2x above average",
    severity: "medium" as const,
    timestamp: new Date(Date.now() - 15 * 60 * 1000).toISOString(),
  },
  {
    id: "3",
    type: "sma_divergence" as const,
    symbol: "ADAUSDT",
    message: "SMA divergence detected: price vs 20-period SMA",
    severity: "low" as const,
    timestamp: new Date(Date.now() - 30 * 60 * 1000).toISOString(),
  },
];

// API functions
export const fetchLatestData = async () => {
  try {
    // In production, this would call your actual API
    // const response = await api.get('/crypto/latest');
    // return response.data;

    // For now, return mock data with slight variations
    return mockCryptoData.map((crypto) => ({
      ...crypto,
      price: crypto.price * (0.995 + Math.random() * 0.01), // ±0.5% variation
      change24h: crypto.change24h + (Math.random() - 0.5) * 2, // ±1% variation
      lastUpdated: new Date().toISOString(),
    }));
  } catch (error) {
    console.error("Error fetching latest data:", error);
    // Return mock data as fallback
    return mockCryptoData;
  }
};

export const fetchAnomalies = async () => {
  try {
    // In production, this would call your actual API
    // const response = await api.get('/anomalies');
    // return response.data;

    // For now, return mock data
    return mockAnomalies;
  } catch (error) {
    console.error("Error fetching anomalies:", error);
    // Return mock data as fallback
    return mockAnomalies;
  }
};

export const fetchHistoricalData = async (
  symbol: string,
  timeframe: string = "1h"
) => {
  try {
    // In production, this would call your actual API
    // const response = await api.get(`/crypto/historical/${symbol}?timeframe=${timeframe}`);
    // return response.data;

    // For now, return mock historical data
    const data = [];
    const now = new Date();
    const basePrice =
      mockCryptoData.find((c) => c.symbol === symbol)?.price || 100;

    for (let i = 23; i >= 0; i--) {
      const time = new Date(now.getTime() - i * 60 * 60 * 1000);
      data.push({
        time: time.toISOString(),
        price: basePrice * (0.95 + Math.random() * 0.1),
        volume: Math.random() * 1000000,
      });
    }

    return data;
  } catch (error) {
    console.error("Error fetching historical data:", error);
    return [];
  }
};

export const fetchSystemMetrics = async () => {
  try {
    // In production, this would call your actual API
    // const response = await api.get('/system/metrics');
    // return response.data;

    // For now, return mock system metrics
    return {
      sqsQueueDepth: Math.floor(Math.random() * 100),
      lambdaExecutions: Math.floor(Math.random() * 1000),
      dynamoDbReads: Math.floor(Math.random() * 5000),
      s3StorageUsed: Math.floor(Math.random() * 1000000),
      lastUpdated: new Date().toISOString(),
    };
  } catch (error) {
    console.error("Error fetching system metrics:", error);
    return null;
  }
};

// WebSocket connection for real-time updates
export const createWebSocketConnection = (onMessage: (data: any) => void) => {
  // In production, this would connect to your WebSocket endpoint
  // const ws = new WebSocket('wss://your-api-gateway-url/websocket');

  // For now, simulate real-time updates with setInterval
  const interval = setInterval(() => {
    const update = {
      type: "price_update",
      data: mockCryptoData.map((crypto) => ({
        symbol: crypto.symbol,
        price: crypto.price * (0.995 + Math.random() * 0.01),
        timestamp: new Date().toISOString(),
      })),
    };
    onMessage(update);
  }, 5000); // Update every 5 seconds

  return {
    close: () => clearInterval(interval),
  };
};

export default api;
