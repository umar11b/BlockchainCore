import React, { useState, useEffect } from "react";
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  AppBar,
  Toolbar,
  IconButton,
  Chip,
  Alert,
  AlertTitle,
} from "@mui/material";
import { Refresh, Analytics, Timeline } from "@mui/icons-material";
import PriceChart from "./PriceChart";
import MetricsCard from "./MetricsCard";
import AlertsPanel from "./AlertsPanel";
import { fetchLatestData, fetchAnomalies } from "../services/api";
import {
  fetchLatestOHLCVData,
  fetchAnomalies as fetchAWSAnomalies,
  createRealTimeConnection,
  formatCryptoData,
} from "../services/aws-api";

interface CryptoData {
  symbol: string;
  price: number;
  change24h: number;
  volume24h: number;
  marketCap: number;
  lastUpdated: string;
}

interface Anomaly {
  id: string;
  type: "price_spike" | "volume_spike" | "sma_divergence";
  symbol: string;
  message: string;
  severity: "low" | "medium" | "high";
  timestamp: string;
}

const Dashboard: React.FC = () => {
  const [cryptoData, setCryptoData] = useState<CryptoData[]>([]);
  const [anomalies, setAnomalies] = useState<Anomaly[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());

  useEffect(() => {
    // Initial data fetch
    const fetchInitialData = async () => {
      try {
        // Try AWS API first, fallback to mock data
        try {
          const [ohlcvData, anomalyData] = await Promise.all([
            fetchLatestOHLCVData(),
            fetchAWSAnomalies(),
          ]);
          const formattedData = formatCryptoData(ohlcvData);
          setCryptoData(formattedData);
          setAnomalies(anomalyData);
        } catch (awsError) {
          console.log("AWS API not available, using mock data");
          const [data, anomalyData] = await Promise.all([
            fetchLatestData(),
            fetchAnomalies(),
          ]);
          setCryptoData(data);
          setAnomalies(anomalyData);
        }
        setLastUpdate(new Date());
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchInitialData();

    // Set up real-time WebSocket connection
    const wsConnection = createRealTimeConnection((message) => {
      if (message.type === "data_update") {
        const { ohlcv, anomalies } = message.data;
        if (ohlcv) {
          const formattedData = formatCryptoData(ohlcv);
          setCryptoData(formattedData);
        }
        if (anomalies) {
          setAnomalies(anomalies);
        }
        setLastUpdate(new Date());
      } else if (message.type === "price_update") {
        // Handle individual price updates
        const updatedData = cryptoData.map((crypto) => {
          const update = message.data.find(
            (u: any) => u.symbol === crypto.symbol
          );
          if (update) {
            return {
              ...crypto,
              price: update.price,
              lastUpdated: update.timestamp,
            };
          }
          return crypto;
        });
        setCryptoData(updatedData);
        setLastUpdate(new Date());
      } else if (message.type === "anomaly_alert") {
        // Handle new anomaly alerts
        setAnomalies((prev) => [message.data, ...prev.slice(0, 9)]); // Keep latest 10
        setLastUpdate(new Date());
      }
    });

    // Cleanup function
    return () => {
      wsConnection.close();
    };
  }, []);

  const handleRefresh = () => {
    setLoading(true);
    // Trigger data refresh
  };

  const getSystemStatus = () => {
    const highSeverityAnomalies = anomalies.filter(
      (a) => a.severity === "high"
    );
    if (highSeverityAnomalies.length > 0) return "warning";
    if (anomalies.length > 0) return "info";
    return "success";
  };

  return (
    <Box sx={{ flexGrow: 1 }}>
      {/* Header */}
      <AppBar
        position="static"
        sx={{ backgroundColor: "transparent", boxShadow: "none", mb: 3 }}
      >
        <Toolbar>
          <Analytics sx={{ mr: 2, color: "primary.main" }} />
          <Typography
            variant="h4"
            component="h1"
            sx={{ flexGrow: 1, fontWeight: 600 }}
          >
            BlockchainCore Analytics
          </Typography>
          <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
            <Chip
              label={`System: ${getSystemStatus()}`}
              color={getSystemStatus()}
              size="small"
              icon={<Timeline />}
            />
            <Typography variant="body2" color="text.secondary">
              Last update: {lastUpdate.toLocaleTimeString()}
            </Typography>
            <IconButton onClick={handleRefresh} disabled={loading}>
              <Refresh />
            </IconButton>
          </Box>
        </Toolbar>
      </AppBar>

      {/* System Status Alert */}
      {anomalies.length > 0 && (
        <Alert severity="warning" sx={{ mb: 3 }}>
          <AlertTitle>Active Alerts</AlertTitle>
          {anomalies.length} anomaly{anomalies.length > 1 ? "s" : ""} detected
          in the last hour
        </Alert>
      )}

      {/* Main Content Grid */}
      <Grid container spacing={3}>
        {/* Metrics Cards */}
        <Grid item xs={12} md={8}>
          <Grid container spacing={2}>
            {cryptoData.map((crypto) => (
              <Grid item xs={12} sm={6} key={crypto.symbol}>
                <MetricsCard data={crypto} />
              </Grid>
            ))}
          </Grid>
        </Grid>

        {/* Alerts Panel */}
        <Grid item xs={12} md={4}>
          <AlertsPanel anomalies={anomalies} />
        </Grid>

        {/* Price Chart */}
        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Real-Time Price Chart
              </Typography>
              <PriceChart data={cryptoData} />
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;
