import React from "react";
import {
  Card,
  CardContent,
  Typography,
  Box,
  Chip,
  Skeleton,
} from "@mui/material";
import { TrendingUp, TrendingDown, AttachMoney } from "@mui/icons-material";

interface CryptoData {
  symbol: string;
  price: number;
  change24h: number;
  volume24h: number;
  marketCap: number;
  lastUpdated: string;
}

interface MetricsCardProps {
  data: CryptoData;
  loading?: boolean;
  onClick?: () => void;
  isSelected?: boolean;
}

const MetricsCard: React.FC<MetricsCardProps> = ({ data, loading = false, onClick, isSelected = false }) => {
  if (loading) {
    return (
      <Card>
        <CardContent>
          <Skeleton variant="text" width="60%" height={32} />
          <Skeleton variant="text" width="40%" height={24} />
          <Skeleton variant="text" width="80%" height={20} />
        </CardContent>
      </Card>
    );
  }

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 2,
      maximumFractionDigits: 6,
    }).format(price);
  };

  const formatVolume = (volume: number) => {
    if (volume >= 1e9) {
      return `$${(volume / 1e9).toFixed(2)}B`;
    } else if (volume >= 1e6) {
      return `$${(volume / 1e6).toFixed(2)}M`;
    } else if (volume >= 1e3) {
      return `$${(volume / 1e3).toFixed(2)}K`;
    }
    return `$${volume.toFixed(2)}`;
  };

  const formatChange = (change: number) => {
    const isPositive = change >= 0;
    const icon = isPositive ? <TrendingUp /> : <TrendingDown />;
    const color = isPositive ? "success" : "error";
    const sign = isPositive ? "+" : "";

    return (
      <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
        {icon}
        <Typography
          variant="body2"
          color={`${color}.main`}
          sx={{ fontWeight: 600 }}
        >
          {sign}
          {change.toFixed(2)}%
        </Typography>
      </Box>
    );
  };

  return (
    <Card
      onClick={onClick}
      sx={{
        height: "100%",
        transition: "transform 0.2s",
        cursor: onClick ? "pointer" : "default",
        border: isSelected ? "2px solid #00d4aa" : "1px solid #333",
        "&:hover": { 
          transform: onClick ? "translateY(-2px)" : "none",
          borderColor: onClick ? "#00d4aa" : "#333"
        },
      }}
    >
      <CardContent>
        <Box
          sx={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "flex-start",
            mb: 2,
          }}
        >
          <Typography variant="h6" component="h3" sx={{ fontWeight: 600 }}>
            {data.symbol}
          </Typography>
          <Chip
            icon={<AttachMoney />}
            label="Live"
            size="small"
            color="primary"
            variant="outlined"
          />
        </Box>

        <Typography
          variant="h4"
          component="div"
          sx={{ mb: 1, fontWeight: 700 }}
        >
          {formatPrice(data.price)}
        </Typography>

        <Box
          sx={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            mb: 2,
          }}
        >
          {formatChange(data.change24h)}
          <Typography variant="caption" color="text.secondary">
            {new Date(data.lastUpdated).toLocaleTimeString()}
          </Typography>
        </Box>

        <Box
          sx={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
          }}
        >
          <Box>
            <Typography
              variant="caption"
              color="text.secondary"
              display="block"
            >
              Volume (24h)
            </Typography>
            <Typography variant="body2" sx={{ fontWeight: 500 }}>
              {formatVolume(data.volume24h)}
            </Typography>
          </Box>
          <Box>
            <Typography
              variant="caption"
              color="text.secondary"
              display="block"
            >
              Market Cap
            </Typography>
            <Typography variant="body2" sx={{ fontWeight: 500 }}>
              {formatVolume(data.marketCap)}
            </Typography>
          </Box>
        </Box>
      </CardContent>
    </Card>
  );
};

export default MetricsCard;
