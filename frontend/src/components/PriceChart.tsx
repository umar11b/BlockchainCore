import React, { useState, useEffect } from "react";
import {
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Area,
  AreaChart,
} from "recharts";
import {
  Box,
  Typography,
  Skeleton,
  ToggleButtonGroup,
  ToggleButton,
  CircularProgress,
  Chip,
} from "@mui/material";
import { fetchHistoricalData } from "../services/aws-api";

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
  selectedSymbol?: string;
  loading?: boolean;
}

// Mock historical data for demonstration
const generateMockHistoricalData = (
  symbol: string,
  currentPrice: number,
  timeframe: "1h" | "24h"
) => {
  const data = [];
  const now = new Date();

  if (timeframe === "1h") {
    // Generate 60 data points for 1 hour (1 minute intervals)
    let lastPrice = currentPrice;
    for (let i = 59; i >= 0; i--) {
      const time = new Date(now.getTime() - i * 60 * 1000); // Last 60 minutes
      // Create smoother price movement
      const change = (Math.random() - 0.5) * 0.002; // ±0.1% change per minute
      lastPrice = lastPrice * (1 + change);
      data.push({
        time: time.toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        }),
        timestamp: time.getTime(),
        price: lastPrice,
        volume: Math.random() * 1000000,
      });
    }
  } else {
    // Generate 24 data points for 24 hours (1 hour intervals)
    let lastPrice = currentPrice;
    for (let i = 23; i >= 0; i--) {
      const time = new Date(now.getTime() - i * 60 * 60 * 1000); // Last 24 hours
      // Create smoother price movement
      const change = (Math.random() - 0.5) * 0.02; // ±1% change per hour
      lastPrice = lastPrice * (1 + change);
      data.push({
        time: time.toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        }),
        timestamp: time.getTime(),
        price: lastPrice,
        volume: Math.random() * 1000000,
      });
    }
  }

  return data;
};

const PriceChart: React.FC<PriceChartProps> = ({
  data,
  selectedSymbol,
  loading = false,
}) => {
  const [timeframe, setTimeframe] = useState<"1h" | "24h">("1h");
  const [chartData, setChartData] = useState<any[]>([]);
  const [historicalLoading, setHistoricalLoading] = useState(false);

  // Find the selected cryptocurrency or default to the first one
  const selectedCrypto =
    data.find((crypto) => crypto.symbol === selectedSymbol) || data[0];

  useEffect(() => {
    if (!selectedCrypto) return;

    const fetchData = async () => {
      setHistoricalLoading(true);
      try {
        // Try to fetch real historical data from AWS
        const hours = timeframe === "1h" ? 1 : 24;
        const historicalData = await fetchHistoricalData(
          selectedCrypto.symbol,
          timeframe,
          hours
        );

        if (historicalData && historicalData.length > 0) {
          // Use real data
          const formattedData = historicalData.map((item) => ({
            time: new Date(item.timestamp).toLocaleTimeString([], {
              hour: "2-digit",
              minute: "2-digit",
            }),
            timestamp: item.timestamp,
            price: item.close,
            volume: item.volume,
          }));
          setChartData(formattedData);
        } else {
          // Fallback to mock data
          const mockData = generateMockHistoricalData(
            selectedCrypto.symbol,
            selectedCrypto.price,
            timeframe
          );
          setChartData(mockData);
        }
      } catch (error) {
        console.error("Error fetching historical data:", error);
        // Fallback to mock data
        const mockData = generateMockHistoricalData(
          selectedCrypto.symbol,
          selectedCrypto.price,
          timeframe
        );
        setChartData(mockData);
      } finally {
        setHistoricalLoading(false);
      }
    };

    fetchData();
  }, [selectedCrypto, timeframe]);

  const handleTimeframeChange = (
    event: React.MouseEvent<HTMLElement>,
    newTimeframe: "1h" | "24h" | null
  ) => {
    if (newTimeframe !== null) {
      setTimeframe(newTimeframe);
    }
  };

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
        <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
          <Typography variant="h6" color="text.primary">
            {selectedCrypto.symbol} Price Chart
          </Typography>
          <Chip
            label="Selected"
            size="small"
            color="primary"
            variant="outlined"
            sx={{ ml: 1 }}
          />
          {historicalLoading && <CircularProgress size={20} />}
        </Box>

        <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
          <ToggleButtonGroup
            value={timeframe}
            exclusive
            onChange={handleTimeframeChange}
            size="small"
            sx={{
              "& .MuiToggleButton-root": {
                color: "#b0b0b0",
                borderColor: "#333",
                "&.Mui-selected": {
                  backgroundColor: "#00d4aa",
                  color: "#000",
                  "&:hover": {
                    backgroundColor: "#00d4aa",
                  },
                },
                "&:hover": {
                  backgroundColor: "#333",
                },
              },
            }}
          >
            <ToggleButton value="1h">1H</ToggleButton>
            <ToggleButton value="24h">24H</ToggleButton>
          </ToggleButtonGroup>

          <Typography variant="body2" color="text.secondary">
            Real-time data from Binance WebSocket
          </Typography>
        </Box>
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
