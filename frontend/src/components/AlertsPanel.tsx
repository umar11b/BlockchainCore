import React from "react";
import {
  Card,
  CardContent,
  Typography,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  Chip,
  Box,
  Divider,
  Alert,
} from "@mui/material";
import {
  Warning,
  TrendingUp,
  TrendingDown,
  Analytics,
  Notifications,
} from "@mui/icons-material";

interface Anomaly {
  id: string;
  type: "price_spike" | "volume_spike" | "sma_divergence";
  symbol: string;
  message: string;
  severity: "low" | "medium" | "high";
  timestamp: string;
}

interface AlertsPanelProps {
  anomalies: Anomaly[];
}

const AlertsPanel: React.FC<AlertsPanelProps> = ({ anomalies }) => {
  const getAnomalyIcon = (type: string) => {
    switch (type) {
      case "price_spike":
        return <TrendingUp color="warning" />;
      case "volume_spike":
        return <Analytics color="error" />;
      case "sma_divergence":
        return <TrendingDown color="info" />;
      default:
        return <Warning color="warning" />;
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case "high":
        return "error";
      case "medium":
        return "warning";
      case "low":
        return "info";
      default:
        return "default";
    }
  };

  const formatTimeAgo = (timestamp: string) => {
    const now = new Date();
    const time = new Date(timestamp);
    const diffInMinutes = Math.floor(
      (now.getTime() - time.getTime()) / (1000 * 60)
    );

    if (diffInMinutes < 1) return "Just now";
    if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
    if (diffInMinutes < 1440) return `${Math.floor(diffInMinutes / 60)}h ago`;
    return `${Math.floor(diffInMinutes / 1440)}d ago`;
  };

  const getAnomalyTypeLabel = (type: string) => {
    switch (type) {
      case "price_spike":
        return "Price Spike";
      case "volume_spike":
        return "Volume Spike";
      case "sma_divergence":
        return "SMA Divergence";
      default:
        return "Unknown";
    }
  };

  return (
    <Card sx={{ height: "100%" }}>
      <CardContent>
        <Box sx={{ display: "flex", alignItems: "center", mb: 2 }}>
          <Notifications sx={{ mr: 1, color: "primary.main" }} />
          <Typography variant="h6" component="h3">
            Anomaly Alerts
          </Typography>
          {anomalies.length > 0 && (
            <Chip
              label={anomalies.length}
              size="small"
              color="error"
              sx={{ ml: "auto" }}
            />
          )}
        </Box>

        {anomalies.length === 0 ? (
          <Alert severity="success" sx={{ mt: 2 }}>
            <Typography variant="body2">
              No anomalies detected. System is running normally.
            </Typography>
          </Alert>
        ) : (
          <List sx={{ p: 0 }}>
            {anomalies.slice(0, 10).map((anomaly, index) => (
              <React.Fragment key={anomaly.id}>
                <ListItem sx={{ px: 0, py: 1 }}>
                  <ListItemIcon sx={{ minWidth: 40 }}>
                    {getAnomalyIcon(anomaly.type)}
                  </ListItemIcon>
                  <ListItemText
                    primary={
                      <Box
                        sx={{
                          display: "flex",
                          alignItems: "center",
                          gap: 1,
                          mb: 0.5,
                        }}
                      >
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                          {anomaly.symbol}
                        </Typography>
                        <Chip
                          label={getAnomalyTypeLabel(anomaly.type)}
                          size="small"
                          color={getSeverityColor(anomaly.severity)}
                          variant="outlined"
                        />
                      </Box>
                    }
                    secondary={
                      <Box>
                        <Typography
                          variant="body2"
                          color="text.secondary"
                          sx={{ mb: 0.5 }}
                        >
                          {anomaly.message}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          {formatTimeAgo(anomaly.timestamp)}
                        </Typography>
                      </Box>
                    }
                  />
                </ListItem>
                {index < anomalies.length - 1 && <Divider />}
              </React.Fragment>
            ))}
          </List>
        )}

        {anomalies.length > 10 && (
          <Box sx={{ mt: 2, textAlign: "center" }}>
            <Typography variant="body2" color="text.secondary">
              +{anomalies.length - 10} more alerts
            </Typography>
          </Box>
        )}
      </CardContent>
    </Card>
  );
};

export default AlertsPanel;
