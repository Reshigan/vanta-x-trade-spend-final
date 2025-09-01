import React from 'react';
import { Box, Grid, Paper, Typography, Card, CardContent } from '@mui/material';
import { 
  People, 
  Business, 
  TrendingUp, 
  Storage,
  Security,
  IntegrationInstructions,
  Analytics,
  Warning
} from '@mui/icons-material';
import AdminLayout from '../components/AdminLayout';
import SystemMetrics from '../components/SystemMetrics';
import RecentActivity from '../components/RecentActivity';
import { useSystemHealth } from '../hooks/useSystemHealth';

const DashboardCard = ({ title, value, icon, color }: any) => (
  <Card sx={{ height: '100%' }}>
    <CardContent>
      <Box display="flex" justifyContent="space-between" alignItems="center">
        <Box>
          <Typography color="textSecondary" gutterBottom variant="body2">
            {title}
          </Typography>
          <Typography variant="h4" component="div">
            {value}
          </Typography>
        </Box>
        <Box sx={{ color }}>
          {icon}
        </Box>
      </Box>
    </CardContent>
  </Card>
);

export default function AdminDashboard() {
  const { data: systemHealth } = useSystemHealth();

  return (
    <AdminLayout>
      <Box sx={{ flexGrow: 1, p: 3 }}>
        <Typography variant="h4" gutterBottom>
          System Administration Dashboard
        </Typography>
        
        <Grid container spacing={3}>
          {/* Key Metrics */}
          <Grid item xs={12} sm={6} md={3}>
            <DashboardCard
              title="Total Companies"
              value="12"
              icon={<Business fontSize="large" />}
              color="#1976d2"
            />
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <DashboardCard
              title="Active Users"
              value="847"
              icon={<People fontSize="large" />}
              color="#388e3c"
            />
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <DashboardCard
              title="API Calls (24h)"
              value="1.2M"
              icon={<TrendingUp fontSize="large" />}
              color="#f57c00"
            />
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <DashboardCard
              title="System Health"
              value="99.9%"
              icon={<Analytics fontSize="large" />}
              color="#7b1fa2"
            />
          </Grid>

          {/* System Status */}
          <Grid item xs={12} md={8}>
            <Paper sx={{ p: 2, height: '400px' }}>
              <Typography variant="h6" gutterBottom>
                System Performance
              </Typography>
              <SystemMetrics />
            </Paper>
          </Grid>

          {/* Alerts */}
          <Grid item xs={12} md={4}>
            <Paper sx={{ p: 2, height: '400px' }}>
              <Typography variant="h6" gutterBottom>
                System Alerts
              </Typography>
              <Box sx={{ mt: 2 }}>
                <Box display="flex" alignItems="center" mb={2}>
                  <Warning color="warning" sx={{ mr: 1 }} />
                  <Typography variant="body2">
                    High memory usage on Analytics Service
                  </Typography>
                </Box>
                <Box display="flex" alignItems="center" mb={2}>
                  <Storage color="info" sx={{ mr: 1 }} />
                  <Typography variant="body2">
                    Database backup completed successfully
                  </Typography>
                </Box>
                <Box display="flex" alignItems="center" mb={2}>
                  <Security color="success" sx={{ mr: 1 }} />
                  <Typography variant="body2">
                    Security scan completed - No issues found
                  </Typography>
                </Box>
                <Box display="flex" alignItems="center" mb={2}>
                  <IntegrationInstructions color="primary" sx={{ mr: 1 }} />
                  <Typography variant="body2">
                    SAP integration sync in progress
                  </Typography>
                </Box>
              </Box>
            </Paper>
          </Grid>

          {/* Recent Activity */}
          <Grid item xs={12}>
            <Paper sx={{ p: 2 }}>
              <Typography variant="h6" gutterBottom>
                Recent Administrative Activity
              </Typography>
              <RecentActivity />
            </Paper>
          </Grid>
        </Grid>
      </Box>
    </AdminLayout>
  );
}