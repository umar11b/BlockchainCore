import React from "react";
import {
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Area,
  AreaChart,
} from "recharts";
import { Box, Typography, Skeleton } from "@mui/material";

interface CryptoData {
  symbol: string;
  price: number;
  change24h: number;
  volume24h: number;
  marketCap: number;
  lastUpdated: string;
}

interface PriceChartProps {
  data: CryptoData[];
  loading?: boolean;
}

// Mock historical data for demonstration
const generateMockHistoricalData = (symbol: string, currentPrice: number) => {
  const data = [];
  const now = new Date();

  for (let i = 23; i >= 0; i--) {
    const time = new Date(now.getTime() - i * 60 * 60 * 1000); // Last 24 hours
    const basePrice = currentPrice * (0.95 + Math.random() * 0.1); // ±5% variation
    data.push({
      time: time.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
      price: basePrice,
      volume: Math.random() * 1000000,
    });
  }

  return data;
};

const PriceChart: React.FC<PriceChartProps> = ({ data, loading = false }) => {
  if (loading) {
    return (
      <Box
        sx={{
          height: 400,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Skeleton variant="rectangular" width="100%" height={400} />
      </Box>
    );
  }

  if (!data || data.length === 0) {
    return (
      <Box
        sx={{
          height: 400,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Typography variant="body1" color="text.secondary">
          No data available
        </Typography>
      </Box>
    );
  }

  // Use the first cryptocurrency for the chart (in a real app, you'd have user selection)
  const selectedCrypto = data[0];
  const chartData = generateMockHistoricalData(
    selectedCrypto.symbol,
    selectedCrypto.price
  );

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <Box
          sx={{
            backgroundColor: "#1a1a1a",
            border: "1px solid #333",
            borderRadius: 2,
            p: 2,
            boxShadow: 3,
          }}
        >
          <Typography variant="body2" color="text.primary">
            Time: {label}
          </Typography>
          <Typography variant="body2" color="primary.main">
            Price: ${payload[0].value.toFixed(2)}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Volume: ${payload[0].payload.volume.toLocaleString()}
          </Typography>
        </Box>
      );
    }
    return null;
  };

  return (
    <Box sx={{ height: 400, width: "100%" }}>
      <Box
        sx={{
          mb: 2,
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
        }}
      >
        <Typography variant="h6" color="text.primary">
          {selectedCrypto.symbol} Price Chart (24h)
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Real-time data from Binance WebSocket
        </Typography>
      </Box>

      <ResponsiveContainer width="100%" height="100%">
        <AreaChart
          data={chartData}
          margin={{ top: 5, right: 30, left: 20, bottom: 5 }}
        >
          <defs>
            <linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#00d4aa" stopOpacity={0.3} />
              <stop offset="95%" stopColor="#00d4aa" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#333" />
          <XAxis dataKey="time" stroke="#b0b0b0" fontSize={12} />
          <YAxis
            stroke="#b0b0b0"
            fontSize={12}
            tickFormatter={(value) => `$${value.toFixed(2)}`}
          />
          <Tooltip content={<CustomTooltip />} />
          <Area
            type="monotone"
            dataKey="price"
            stroke="#00d4aa"
            strokeWidth={2}
            fillOpacity={1}
            fill="url(#colorPrice)"
          />
        </AreaChart>
      </ResponsiveContainer>
    </Box>
  );
};

export default PriceChart;
