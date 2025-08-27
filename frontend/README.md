# BlockchainCore Frontend

A modern, real-time cryptocurrency analytics dashboard built with React, TypeScript, and Material-UI.

## Features

- **Real-time Data Visualization**: Live cryptocurrency price charts and metrics
- **Anomaly Detection Alerts**: Real-time notifications for price spikes, volume spikes, and SMA divergences
- **Professional UI**: Dark theme with modern design using Material-UI
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Interactive Charts**: Price charts with tooltips and real-time updates
- **System Status Monitoring**: Live system health indicators

## Tech Stack

- **React 18** with TypeScript
- **Material-UI (MUI)** for UI components
- **Recharts** for data visualization
- **Axios** for API communication
- **WebSocket** for real-time updates

## Getting Started

### Prerequisites

- Node.js 16+
- npm or yarn

### Installation

1. Install dependencies:

```bash
npm install
```

2. Start the development server:

```bash
npm start
```

3. Open [http://localhost:3000](http://localhost:3000) to view it in the browser.

### Available Scripts

- `npm start` - Runs the app in development mode
- `npm test` - Launches the test runner
- `npm run build` - Builds the app for production
- `npm run eject` - Ejects from Create React App (one-way operation)

## Project Structure

```
src/
├── components/          # React components
│   ├── Dashboard.tsx   # Main dashboard layout
│   ├── MetricsCard.tsx # Cryptocurrency metrics cards
│   ├── PriceChart.tsx  # Price chart component
│   └── AlertsPanel.tsx # Anomaly alerts panel
├── services/           # API services
│   └── api.ts         # API functions and mock data
├── App.tsx            # Main app component
└── index.tsx          # App entry point
```

## Configuration

### Environment Variables

Create a `.env` file in the frontend directory:

```env
REACT_APP_API_URL=http://localhost:3001/api
REACT_APP_WS_URL=ws://localhost:3001/ws
```

### API Integration

The frontend is currently using mock data for development. To connect to the real BlockchainCore backend:

1. Update the API endpoints in `src/services/api.ts`
2. Replace mock data with actual API calls
3. Configure WebSocket connection for real-time updates

## Development

### Adding New Components

1. Create new component files in `src/components/`
2. Follow the existing TypeScript interface patterns
3. Use Material-UI components for consistency
4. Add proper error handling and loading states

### Styling

- Use Material-UI's `sx` prop for component-specific styles
- Follow the dark theme color palette defined in `App.tsx`
- Use the Inter font family for typography

### State Management

Currently using React hooks for state management. For larger applications, consider:

- Redux Toolkit
- Zustand
- React Query for server state

## Production Build

1. Build the application:

```bash
npm run build
```

2. The build artifacts will be stored in the `build/` directory

3. Deploy the `build/` directory to your hosting service

## Integration with BlockchainCore Backend

To connect this frontend with the BlockchainCore backend:

1. **API Gateway**: Set up AWS API Gateway to expose your Lambda functions
2. **CORS**: Configure CORS headers in API Gateway
3. **Authentication**: Add authentication if required
4. **WebSocket**: Set up WebSocket API Gateway for real-time updates

### Example API Endpoints

```typescript
// Get latest cryptocurrency data
GET /api/crypto/latest

// Get historical data
GET /api/crypto/historical/{symbol}?timeframe=1h

// Get anomalies
GET /api/anomalies

// Get system metrics
GET /api/system/metrics
```

## Contributing

1. Follow the existing code style and patterns
2. Add TypeScript interfaces for all data structures
3. Include proper error handling
4. Test components thoroughly
5. Update documentation as needed

## License

MIT License - see the main project LICENSE file for details.
