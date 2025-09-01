import React, { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  ToggleButton,
  ToggleButtonGroup,
  Chip,
  IconButton,
  Tooltip,
  LinearProgress,
  Alert
} from '@mui/material';
import {
  TrendingUp,
  TrendingDown,
  Info,
  Download,
  Refresh,
  FilterList,
  Assessment,
  MonetizationOn,
  ShoppingCart,
  Store,
  Category
} from '@mui/icons-material';
import { useTheme } from '@mui/material/styles';
import {
  ResponsiveContainer,
  ComposedChart,
  Bar,
  Line,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip as ChartTooltip,
  Legend,
  PieChart,
  Pie,
  Cell,
  Treemap,
  Sankey,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
  ScatterChart,
  Scatter,
  ZAxis
} from 'recharts';
import { HeatMapGrid } from 'react-grid-heatmap';
import { useQuery } from '@tanstack/react-query';
import { format, subMonths } from 'date-fns';

interface ProfitabilityData {
  dimension: string;
  categories: string[];
  data: number[][];
  metadata: {
    min: number;
    max: number;
    average: number;
  };
}

interface PerformanceMetric {
  name: string;
  value: number;
  change: number;
  trend: 'up' | 'down' | 'stable';
  target: number;
  achievement: number;
}

interface OpportunityItem {
  id: string;
  title: string;
  impact: number;
  effort: 'low' | 'medium' | 'high';
  category: string;
  description: string;
  actions: string[];
}

const ExecutiveAnalytics: React.FC = () => {
  const theme = useTheme();
  const [viewMode, setViewMode] = useState<'vendor' | 'product' | 'customer' | 'region'>('vendor');
  const [timeRange, setTimeRange] = useState<'month' | 'quarter' | 'year'>('quarter');
  const [selectedMetric, setSelectedMetric] = useState<'revenue' | 'profit' | 'roi' | 'spend'>('profit');

  // Fetch executive analytics data
  const { data: analyticsData, isLoading, refetch } = useQuery({
    queryKey: ['executive-analytics', viewMode, timeRange, selectedMetric],
    queryFn: async () => {
      const response = await fetch(`/api/v1/analytics/executive?view=${viewMode}&range=${timeRange}&metric=${selectedMetric}`);
      return response.json();
    },
    refetchInterval: 300000 // Refresh every 5 minutes
  });

  // Color scales for heat maps
  const getHeatmapColor = (value: number, min: number, max: number) => {
    const normalized = (value - min) / (max - min);
    if (normalized < 0.33) return theme.palette.error.main;
    if (normalized < 0.67) return theme.palette.warning.main;
    return theme.palette.success.main;
  };

  // Format currency values
  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value);
  };

  // Format percentage values
  const formatPercentage = (value: number) => {
    return `${(value * 100).toFixed(1)}%`;
  };

  // Render KPI Card
  const renderKPICard = (metric: PerformanceMetric) => (
    <Card sx={{ height: '100%', position: 'relative', overflow: 'visible' }}>
      <CardContent>
        <Box display="flex" justifyContent="space-between" alignItems="flex-start">
          <Typography variant="subtitle2" color="textSecondary" gutterBottom>
            {metric.name}
          </Typography>
          <Chip
            size="small"
            icon={metric.trend === 'up' ? <TrendingUp /> : <TrendingDown />}
            label={`${metric.change > 0 ? '+' : ''}${metric.change}%`}
            color={metric.trend === 'up' ? 'success' : 'error'}
            sx={{ height: 24 }}
          />
        </Box>
        <Typography variant="h4" sx={{ my: 1 }}>
          {selectedMetric === 'roi' ? formatPercentage(metric.value) : formatCurrency(metric.value)}
        </Typography>
        <Box sx={{ mt: 2 }}>
          <Box display="flex" justifyContent="space-between" mb={0.5}>
            <Typography variant="caption" color="textSecondary">
              Target Achievement
            </Typography>
            <Typography variant="caption" fontWeight="bold">
              {formatPercentage(metric.achievement)}
            </Typography>
          </Box>
          <LinearProgress
            variant="determinate"
            value={Math.min(metric.achievement * 100, 100)}
            sx={{
              height: 6,
              borderRadius: 3,
              backgroundColor: theme.palette.grey[200],
              '& .MuiLinearProgress-bar': {
                backgroundColor: metric.achievement >= 1 ? theme.palette.success.main : theme.palette.warning.main
              }
            }}
          />
        </Box>
      </CardContent>
    </Card>
  );

  // Render Profitability Heatmap
  const renderProfitabilityHeatmap = (data: ProfitabilityData) => (
    <Card>
      <CardContent>
        <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
          <Typography variant="h6">Profitability Heat Map - {viewMode}</Typography>
          <Box display="flex" gap={1}>
            <Chip label={`Min: ${formatCurrency(data.metadata.min)}`} size="small" />
            <Chip label={`Avg: ${formatCurrency(data.metadata.average)}`} size="small" />
            <Chip label={`Max: ${formatCurrency(data.metadata.max)}`} size="small" />
          </Box>
        </Box>
        <Box sx={{ height: 400, overflowX: 'auto' }}>
          <HeatMapGrid
            data={data.data}
            xLabels={data.categories}
            yLabels={analyticsData?.dimensions || []}
            cellRender={(x, y, value) => (
              <div style={{ fontSize: '11px' }}>{formatCurrency(value)}</div>
            )}
            xLabelsStyle={() => ({
              fontSize: '12px',
              textTransform: 'capitalize'
            })}
            yLabelsStyle={() => ({
              fontSize: '12px',
              textTransform: 'capitalize'
            })}
            cellStyle={(x, y, value) => ({
              background: getHeatmapColor(value, data.metadata.min, data.metadata.max),
              fontSize: '11px',
              color: '#fff',
              border: '1px solid #fff'
            })}
            cellHeight="35px"
            xLabelsPos="top"
            yLabelsPos="left"
            square
          />
        </Box>
      </CardContent>
    </Card>
  );

  // Render Spend vs Budget Gauge
  const renderSpendGauge = () => {
    const spendData = analyticsData?.spendVsBudget || { spent: 0, budget: 0, percentage: 0 };
    const gaugeData = [
      { name: 'Spent', value: spendData.spent },
      { name: 'Remaining', value: spendData.budget - spendData.spent }
    ];

    return (
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>Spend vs Budget</Typography>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={gaugeData}
                cx="50%"
                cy="50%"
                startAngle={180}
                endAngle={0}
                innerRadius={60}
                outerRadius={100}
                paddingAngle={0}
                dataKey="value"
              >
                <Cell fill={theme.palette.primary.main} />
                <Cell fill={theme.palette.grey[300]} />
              </Pie>
              <text x="50%" y="50%" textAnchor="middle" dominantBaseline="middle">
                <tspan x="50%" dy="-10" fontSize="24" fontWeight="bold">
                  {formatPercentage(spendData.percentage)}
                </tspan>
                <tspan x="50%" dy="25" fontSize="14" fill={theme.palette.text.secondary}>
                  Utilized
                </tspan>
              </text>
            </PieChart>
          </ResponsiveContainer>
          <Box display="flex" justifyContent="space-around" mt={2}>
            <Box textAlign="center">
              <Typography variant="caption" color="textSecondary">Spent</Typography>
              <Typography variant="h6">{formatCurrency(spendData.spent)}</Typography>
            </Box>
            <Box textAlign="center">
              <Typography variant="caption" color="textSecondary">Budget</Typography>
              <Typography variant="h6">{formatCurrency(spendData.budget)}</Typography>
            </Box>
          </Box>
        </CardContent>
      </Card>
    );
  };

  // Render Performance Radar Chart
  const renderPerformanceRadar = () => {
    const radarData = analyticsData?.performanceRadar || [];
    
    return (
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>Performance Scorecard</Typography>
          <ResponsiveContainer width="100%" height={300}>
            <RadarChart data={radarData}>
              <PolarGrid stroke={theme.palette.divider} />
              <PolarAngleAxis dataKey="metric" tick={{ fontSize: 12 }} />
              <PolarRadiusAxis angle={90} domain={[0, 100]} tick={{ fontSize: 10 }} />
              <Radar
                name="Current"
                dataKey="current"
                stroke={theme.palette.primary.main}
                fill={theme.palette.primary.main}
                fillOpacity={0.6}
              />
              <Radar
                name="Target"
                dataKey="target"
                stroke={theme.palette.secondary.main}
                fill={theme.palette.secondary.main}
                fillOpacity={0.3}
              />
              <Legend />
            </RadarChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>
    );
  };

  // Render Opportunity Analysis
  const renderOpportunityAnalysis = () => {
    const opportunities: OpportunityItem[] = analyticsData?.opportunities || [];
    
    return (
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>Opportunity Analysis</Typography>
          <ResponsiveContainer width="100%" height={400}>
            <ScatterChart margin={{ top: 20, right: 20, bottom: 20, left: 20 }}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis
                type="number"
                dataKey="effort"
                name="Effort"
                domain={[0, 10]}
                label={{ value: 'Implementation Effort', position: 'insideBottom', offset: -10 }}
              />
              <YAxis
                type="number"
                dataKey="impact"
                name="Impact"
                domain={[0, 100]}
                label={{ value: 'Business Impact ($M)', angle: -90, position: 'insideLeft' }}
              />
              <ZAxis type="number" dataKey="size" range={[100, 1000]} />
              <ChartTooltip
                content={({ active, payload }) => {
                  if (active && payload && payload.length) {
                    const data = payload[0].payload as OpportunityItem;
                    return (
                      <Box sx={{ bgcolor: 'background.paper', p: 2, border: 1, borderColor: 'divider', borderRadius: 1 }}>
                        <Typography variant="subtitle2">{data.title}</Typography>
                        <Typography variant="body2" color="textSecondary">{data.description}</Typography>
                        <Typography variant="caption">Impact: ${data.impact}M | Effort: {data.effort}</Typography>
                      </Box>
                    );
                  }
                  return null;
                }}
              />
              <Scatter
                name="Opportunities"
                data={opportunities.map(opp => ({
                  ...opp,
                  effort: opp.effort === 'low' ? 2 : opp.effort === 'medium' ? 5 : 8,
                  size: opp.impact * 10
                }))}
                fill={theme.palette.primary.main}
              />
              {/* Quadrant labels */}
              <text x="25%" y="15%" textAnchor="middle" fill={theme.palette.success.main} fontWeight="bold">
                Quick Wins
              </text>
              <text x="75%" y="15%" textAnchor="middle" fill={theme.palette.warning.main} fontWeight="bold">
                Major Projects
              </text>
              <text x="25%" y="85%" textAnchor="middle" fill={theme.palette.info.main} fontWeight="bold">
                Fill Ins
              </text>
              <text x="75%" y="85%" textAnchor="middle" fill={theme.palette.error.main} fontWeight="bold">
                Question Marks
              </text>
            </ScatterChart>
          </ResponsiveContainer>
          
          {/* Opportunity List */}
          <Box mt={3}>
            <Typography variant="subtitle2" gutterBottom>Top Opportunities</Typography>
            {opportunities.slice(0, 5).map((opp) => (
              <Box key={opp.id} sx={{ mb: 2, p: 2, bgcolor: 'background.default', borderRadius: 1 }}>
                <Box display="flex" justifyContent="space-between" alignItems="center">
                  <Typography variant="body2" fontWeight="bold">{opp.title}</Typography>
                  <Chip
                    label={`$${opp.impact}M`}
                    size="small"
                    color="primary"
                  />
                </Box>
                <Typography variant="caption" color="textSecondary">{opp.description}</Typography>
                <Box display="flex" gap={0.5} mt={1}>
                  {opp.actions.map((action, idx) => (
                    <Chip key={idx} label={action} size="small" variant="outlined" />
                  ))}
                </Box>
              </Box>
            ))}
          </Box>
        </CardContent>
      </Card>
    );
  };

  // Render Trend Analysis
  const renderTrendAnalysis = () => {
    const trendData = analyticsData?.trends || [];
    
    return (
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>Trend Analysis</Typography>
          <ResponsiveContainer width="100%" height={300}>
            <ComposedChart data={trendData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="period" />
              <YAxis yAxisId="left" />
              <YAxis yAxisId="right" orientation="right" />
              <ChartTooltip formatter={(value: number) => formatCurrency(value)} />
              <Legend />
              <Area
                yAxisId="left"
                type="monotone"
                dataKey="revenue"
                fill={theme.palette.primary.light}
                stroke={theme.palette.primary.main}
                name="Revenue"
              />
              <Bar
                yAxisId="left"
                dataKey="tradeSpend"
                fill={theme.palette.secondary.main}
                name="Trade Spend"
              />
              <Line
                yAxisId="right"
                type="monotone"
                dataKey="roi"
                stroke={theme.palette.success.main}
                strokeWidth={3}
                dot={{ r: 4 }}
                name="ROI %"
              />
            </ComposedChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>
    );
  };

  if (isLoading) {
    return (
      <Box sx={{ p: 3 }}>
        <LinearProgress />
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      {/* Header Controls */}
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">Executive Analytics Dashboard</Typography>
        <Box display="flex" gap={2} alignItems="center">
          <ToggleButtonGroup
            value={viewMode}
            exclusive
            onChange={(e, value) => value && setViewMode(value)}
            size="small"
          >
            <ToggleButton value="vendor">
              <MonetizationOn sx={{ mr: 0.5 }} /> Vendor
            </ToggleButton>
            <ToggleButton value="product">
              <Category sx={{ mr: 0.5 }} /> Product
            </ToggleButton>
            <ToggleButton value="customer">
              <ShoppingCart sx={{ mr: 0.5 }} /> Customer
            </ToggleButton>
            <ToggleButton value="region">
              <Store sx={{ mr: 0.5 }} /> Region
            </ToggleButton>
          </ToggleButtonGroup>

          <FormControl size="small" sx={{ minWidth: 120 }}>
            <InputLabel>Time Range</InputLabel>
            <Select
              value={timeRange}
              onChange={(e) => setTimeRange(e.target.value as any)}
              label="Time Range"
            >
              <MenuItem value="month">Month</MenuItem>
              <MenuItem value="quarter">Quarter</MenuItem>
              <MenuItem value="year">Year</MenuItem>
            </Select>
          </FormControl>

          <FormControl size="small" sx={{ minWidth: 120 }}>
            <InputLabel>Metric</InputLabel>
            <Select
              value={selectedMetric}
              onChange={(e) => setSelectedMetric(e.target.value as any)}
              label="Metric"
            >
              <MenuItem value="revenue">Revenue</MenuItem>
              <MenuItem value="profit">Profit</MenuItem>
              <MenuItem value="roi">ROI</MenuItem>
              <MenuItem value="spend">Spend</MenuItem>
            </Select>
          </FormControl>

          <Tooltip title="Refresh Data">
            <IconButton onClick={() => refetch()}>
              <Refresh />
            </IconButton>
          </Tooltip>

          <Tooltip title="Download Report">
            <IconButton>
              <Download />
            </IconButton>
          </Tooltip>
        </Box>
      </Box>

      {/* KPI Cards */}
      <Grid container spacing={3} mb={3}>
        {analyticsData?.kpis?.map((kpi: PerformanceMetric, index: number) => (
          <Grid item xs={12} sm={6} md={3} key={index}>
            {renderKPICard(kpi)}
          </Grid>
        ))}
      </Grid>

      {/* Main Content Grid */}
      <Grid container spacing={3}>
        {/* Profitability Heatmap */}
        <Grid item xs={12}>
          {analyticsData?.profitabilityHeatmap && renderProfitabilityHeatmap(analyticsData.profitabilityHeatmap)}
        </Grid>

        {/* Spend Gauge and Performance Radar */}
        <Grid item xs={12} md={6}>
          {renderSpendGauge()}
        </Grid>
        <Grid item xs={12} md={6}>
          {renderPerformanceRadar()}
        </Grid>

        {/* Trend Analysis */}
        <Grid item xs={12}>
          {renderTrendAnalysis()}
        </Grid>

        {/* Opportunity Analysis */}
        <Grid item xs={12}>
          {renderOpportunityAnalysis()}
        </Grid>
      </Grid>

      {/* AI Insights Alert */}
      {analyticsData?.aiInsights && (
        <Alert
          severity="info"
          icon={<Assessment />}
          sx={{ mt: 3 }}
          action={
            <Tooltip title="View Details">
              <IconButton size="small">
                <Info />
              </IconButton>
            </Tooltip>
          }
        >
          <Typography variant="subtitle2">AI Insight</Typography>
          <Typography variant="body2">{analyticsData.aiInsights.message}</Typography>
        </Alert>
      )}
    </Box>
  );
};

export default ExecutiveAnalytics;