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
import { Analytics } from "@mui/icons-material";
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
  const [isPolling, setIsPolling] = useState(false);
  const [selectedSymbol, setSelectedSymbol] = useState<string>("BTCUSDT");

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

    // Set up polling for real-time updates (since WebSocket is not configured yet)
    const pollingInterval = setInterval(async () => {
      try {
        console.log("Polling for new data...");
        setIsPolling(true);
        const [ohlcvData, anomalyData] = await Promise.all([
          fetchLatestOHLCVData(),
          fetchAWSAnomalies(),
        ]);

        if (ohlcvData && ohlcvData.length > 0) {
          const formattedData = formatCryptoData(ohlcvData);
          setCryptoData(formattedData);
        }

        if (anomalyData && anomalyData.length > 0) {
          setAnomalies(anomalyData);
        }

        setLastUpdate(new Date());
        setIsPolling(false);
      } catch (error) {
        console.error("Polling error:", error);
        // Fallback to mock data if AWS API fails
        try {
          const [data, anomalyData] = await Promise.all([
            fetchLatestData(),
            fetchAnomalies(),
          ]);
          setCryptoData(data);
          setAnomalies(anomalyData);
          setLastUpdate(new Date());
        } catch (fallbackError) {
          console.error("Fallback error:", fallbackError);
        }
        setIsPolling(false);
      }
    }, 1000); // Poll every 1 second

    // Cleanup function
    return () => {
      clearInterval(pollingInterval);
    };
  }, []);



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
                <MetricsCard
                  data={crypto}
                  onClick={() => setSelectedSymbol(crypto.symbol)}
                  isSelected={selectedSymbol === crypto.symbol}
                />
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
              <PriceChart data={cryptoData} selectedSymbol={selectedSymbol} />
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;
