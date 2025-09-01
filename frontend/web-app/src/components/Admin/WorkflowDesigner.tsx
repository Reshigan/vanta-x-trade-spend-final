import React, { useState, useCallback, useRef } from 'react';
import ReactFlow, {
  Node,
  Edge,
  Controls,
  Background,
  MiniMap,
  addEdge,
  Connection,
  useNodesState,
  useEdgesState,
  MarkerType,
  Position,
  Handle,
  NodeProps,
  getBezierPath,
  EdgeProps
} from 'reactflow';
import 'reactflow/dist/style.css';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Chip,
  IconButton,
  Drawer,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  Divider,
  Alert,
  Tabs,
  Tab,
  Switch,
  FormControlLabel,
  Autocomplete,
  Paper
} from '@mui/material';
import {
  PlayArrow,
  Save,
  Add,
  Delete,
  Edit,
  Settings,
  Person,
  Email,
  Timer,
  CheckCircle,
  Cancel,
  Warning,
  Assignment,
  AccountTree,
  Rule,
  NotificationsActive,
  Group,
  Schedule
} from '@mui/icons-material';
import { useTheme } from '@mui/material/styles';

// Custom Node Types
const ApprovalNode: React.FC<NodeProps> = ({ data, selected }) => {
  const theme = useTheme();
  
  return (
    <Card
      sx={{
        minWidth: 200,
        border: selected ? `2px solid ${theme.palette.primary.main}` : '1px solid #ddd',
        boxShadow: selected ? 3 : 1
      }}
    >
      <CardContent sx={{ p: 2 }}>
        <Box display="flex" alignItems="center" mb={1}>
          <Person sx={{ mr: 1, color: theme.palette.primary.main }} />
          <Typography variant="subtitle2">{data.label}</Typography>
        </Box>
        <Typography variant="caption" color="textSecondary">
          {data.approver || 'Not assigned'}
        </Typography>
        {data.sla && (
          <Chip
            size="small"
            icon={<Timer />}
            label={`SLA: ${data.sla}`}
            sx={{ mt: 1 }}
          />
        )}
      </CardContent>
      <Handle type="target" position={Position.Top} />
      <Handle type="source" position={Position.Bottom} />
    </Card>
  );
};

const ConditionNode: React.FC<NodeProps> = ({ data, selected }) => {
  const theme = useTheme();
  
  return (
    <Card
      sx={{
        minWidth: 180,
        border: selected ? `2px solid ${theme.palette.warning.main}` : '1px solid #ddd',
        boxShadow: selected ? 3 : 1,
        bgcolor: theme.palette.warning.light + '20'
      }}
    >
      <CardContent sx={{ p: 2 }}>
        <Box display="flex" alignItems="center" mb={1}>
          <Rule sx={{ mr: 1, color: theme.palette.warning.main }} />
          <Typography variant="subtitle2">{data.label}</Typography>
        </Box>
        <Typography variant="caption" color="textSecondary">
          {data.condition || 'No condition set'}
        </Typography>
      </CardContent>
      <Handle type="target" position={Position.Top} />
      <Handle type="source" position={Position.Bottom} id="yes" style={{ left: '25%' }} />
      <Handle type="source" position={Position.Bottom} id="no" style={{ left: '75%' }} />
    </Card>
  );
};

const NotificationNode: React.FC<NodeProps> = ({ data, selected }) => {
  const theme = useTheme();
  
  return (
    <Card
      sx={{
        minWidth: 180,
        border: selected ? `2px solid ${theme.palette.info.main}` : '1px solid #ddd',
        boxShadow: selected ? 3 : 1,
        bgcolor: theme.palette.info.light + '20'
      }}
    >
      <CardContent sx={{ p: 2 }}>
        <Box display="flex" alignItems="center" mb={1}>
          <Email sx={{ mr: 1, color: theme.palette.info.main }} />
          <Typography variant="subtitle2">{data.label}</Typography>
        </Box>
        <Typography variant="caption" color="textSecondary">
          {data.recipients?.length || 0} recipients
        </Typography>
      </CardContent>
      <Handle type="target" position={Position.Top} />
      <Handle type="source" position={Position.Bottom} />
    </Card>
  );
};

// Custom Edge with Label
const CustomEdge: React.FC<EdgeProps> = ({
  id,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  data,
  markerEnd
}) => {
  const [edgePath, labelX, labelY] = getBezierPath({
    sourceX,
    sourceY,
    sourcePosition,
    targetX,
    targetY,
    targetPosition
  });

  return (
    <>
      <path
        id={id}
        className="react-flow__edge-path"
        d={edgePath}
        markerEnd={markerEnd}
        style={{ stroke: data?.color || '#b1b1b7', strokeWidth: 2 }}
      />
      {data?.label && (
        <text>
          <textPath
            href={`#${id}`}
            style={{ fontSize: 12 }}
            startOffset="50%"
            textAnchor="middle"
          >
            {data.label}
          </textPath>
        </text>
      )}
    </>
  );
};

const nodeTypes = {
  approval: ApprovalNode,
  condition: ConditionNode,
  notification: NotificationNode
};

const edgeTypes = {
  custom: CustomEdge
};

interface WorkflowDesignerProps {
  workflowId?: string;
  onSave?: (workflow: any) => void;
}

const WorkflowDesigner: React.FC<WorkflowDesignerProps> = ({ workflowId, onSave }) => {
  const theme = useTheme();
  const reactFlowWrapper = useRef<HTMLDivElement>(null);
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [selectedNode, setSelectedNode] = useState<Node | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(true);
  const [nodeDialogOpen, setNodeDialogOpen] = useState(false);
  const [workflowSettings, setWorkflowSettings] = useState({
    name: 'New Workflow',
    type: 'PROMOTION_APPROVAL',
    description: '',
    isActive: true,
    notifications: {
      onStart: true,
      onComplete: true,
      onError: true
    }
  });
  const [tabValue, setTabValue] = useState(0);

  // Node Templates
  const nodeTemplates = [
    {
      type: 'approval',
      label: 'Approval Step',
      icon: <Person />,
      defaultData: { label: 'Approval', approver: '', sla: '24h' }
    },
    {
      type: 'condition',
      label: 'Condition',
      icon: <Rule />,
      defaultData: { label: 'Condition', condition: '' }
    },
    {
      type: 'notification',
      label: 'Send Notification',
      icon: <Email />,
      defaultData: { label: 'Notification', recipients: [] }
    }
  ];

  // Handle node connection
  const onConnect = useCallback(
    (params: Connection) => {
      const newEdge = {
        ...params,
        type: 'custom',
        markerEnd: {
          type: MarkerType.ArrowClosed
        },
        data: {
          label: params.sourceHandle === 'yes' ? 'Yes' : params.sourceHandle === 'no' ? 'No' : ''
        }
      };
      setEdges((eds) => addEdge(newEdge, eds));
    },
    [setEdges]
  );

  // Handle node selection
  const onNodeClick = useCallback((event: React.MouseEvent, node: Node) => {
    setSelectedNode(node);
  }, []);

  // Add new node
  const addNode = (template: any) => {
    const newNode: Node = {
      id: `node-${Date.now()}`,
      type: template.type,
      position: { x: 250, y: nodes.length * 150 + 50 },
      data: { ...template.defaultData }
    };
    setNodes((nds) => [...nds, newNode]);
  };

  // Update node data
  const updateNodeData = (nodeId: string, data: any) => {
    setNodes((nds) =>
      nds.map((node) =>
        node.id === nodeId ? { ...node, data: { ...node.data, ...data } } : node
      )
    );
  };

  // Delete selected node
  const deleteSelectedNode = () => {
    if (selectedNode) {
      setNodes((nds) => nds.filter((node) => node.id !== selectedNode.id));
      setEdges((eds) => eds.filter((edge) => 
        edge.source !== selectedNode.id && edge.target !== selectedNode.id
      ));
      setSelectedNode(null);
    }
  };

  // Save workflow
  const handleSave = () => {
    const workflow = {
      ...workflowSettings,
      nodes,
      edges,
      updatedAt: new Date().toISOString()
    };
    
    if (onSave) {
      onSave(workflow);
    }
    
    // Show success message
    console.log('Workflow saved:', workflow);
  };

  // Validate workflow
  const validateWorkflow = () => {
    const errors = [];
    
    // Check if workflow has nodes
    if (nodes.length === 0) {
      errors.push('Workflow must have at least one node');
    }
    
    // Check if all approval nodes have approvers
    nodes.forEach((node) => {
      if (node.type === 'approval' && !node.data.approver) {
        errors.push(`Approval node "${node.data.label}" needs an approver`);
      }
    });
    
    // Check for disconnected nodes
    const connectedNodes = new Set();
    edges.forEach((edge) => {
      connectedNodes.add(edge.source);
      connectedNodes.add(edge.target);
    });
    
    nodes.forEach((node) => {
      if (!connectedNodes.has(node.id) && nodes.length > 1) {
        errors.push(`Node "${node.data.label}" is not connected`);
      }
    });
    
    return errors;
  };

  return (
    <Box sx={{ height: '100vh', display: 'flex' }}>
      {/* Left Drawer - Node Templates */}
      <Drawer
        variant="persistent"
        anchor="left"
        open={drawerOpen}
        sx={{
          width: drawerOpen ? 280 : 0,
          flexShrink: 0,
          '& .MuiDrawer-paper': {
            width: 280,
            boxSizing: 'border-box',
            position: 'relative',
            height: '100%'
          }
        }}
      >
        <Box sx={{ p: 2 }}>
          <Typography variant="h6" gutterBottom>
            Workflow Designer
          </Typography>
          <TextField
            fullWidth
            label="Workflow Name"
            value={workflowSettings.name}
            onChange={(e) => setWorkflowSettings({ ...workflowSettings, name: e.target.value })}
            sx={{ mb: 2 }}
          />
          <FormControl fullWidth sx={{ mb: 2 }}>
            <InputLabel>Workflow Type</InputLabel>
            <Select
              value={workflowSettings.type}
              onChange={(e) => setWorkflowSettings({ ...workflowSettings, type: e.target.value })}
              label="Workflow Type"
            >
              <MenuItem value="PROMOTION_APPROVAL">Promotion Approval</MenuItem>
              <MenuItem value="BUDGET_APPROVAL">Budget Approval</MenuItem>
              <MenuItem value="CAMPAIGN_APPROVAL">Campaign Approval</MenuItem>
              <MenuItem value="TRADING_TERM_APPROVAL">Trading Term Approval</MenuItem>
              <MenuItem value="SPEND_APPROVAL">Spend Approval</MenuItem>
            </Select>
          </FormControl>
        </Box>
        
        <Divider />
        
        <Box sx={{ p: 2 }}>
          <Typography variant="subtitle2" gutterBottom>
            Add Nodes
          </Typography>
          <List>
            {nodeTemplates.map((template) => (
              <ListItem
                key={template.type}
                button
                onClick={() => addNode(template)}
                sx={{
                  border: '1px solid #ddd',
                  borderRadius: 1,
                  mb: 1,
                  '&:hover': {
                    bgcolor: 'action.hover'
                  }
                }}
              >
                <ListItemIcon>{template.icon}</ListItemIcon>
                <ListItemText primary={template.label} />
              </ListItem>
            ))}
          </List>
        </Box>
        
        <Divider />
        
        {selectedNode && (
          <Box sx={{ p: 2 }}>
            <Typography variant="subtitle2" gutterBottom>
              Node Properties
            </Typography>
            <TextField
              fullWidth
              label="Label"
              value={selectedNode.data.label}
              onChange={(e) => updateNodeData(selectedNode.id, { label: e.target.value })}
              sx={{ mb: 2 }}
            />
            
            {selectedNode.type === 'approval' && (
              <>
                <Autocomplete
                  fullWidth
                  options={['Manager', 'Director', 'VP', 'CEO']}
                  value={selectedNode.data.approver}
                  onChange={(e, value) => updateNodeData(selectedNode.id, { approver: value })}
                  renderInput={(params) => <TextField {...params} label="Approver" />}
                  sx={{ mb: 2 }}
                />
                <TextField
                  fullWidth
                  label="SLA"
                  value={selectedNode.data.sla}
                  onChange={(e) => updateNodeData(selectedNode.id, { sla: e.target.value })}
                  sx={{ mb: 2 }}
                />
              </>
            )}
            
            {selectedNode.type === 'condition' && (
              <TextField
                fullWidth
                label="Condition"
                value={selectedNode.data.condition}
                onChange={(e) => updateNodeData(selectedNode.id, { condition: e.target.value })}
                multiline
                rows={3}
                sx={{ mb: 2 }}
              />
            )}
            
            {selectedNode.type === 'notification' && (
              <Autocomplete
                multiple
                fullWidth
                options={['Requester', 'Approver', 'Admin', 'Custom Email']}
                value={selectedNode.data.recipients || []}
                onChange={(e, value) => updateNodeData(selectedNode.id, { recipients: value })}
                renderInput={(params) => <TextField {...params} label="Recipients" />}
                sx={{ mb: 2 }}
              />
            )}
            
            <Button
              fullWidth
              variant="outlined"
              color="error"
              startIcon={<Delete />}
              onClick={deleteSelectedNode}
            >
              Delete Node
            </Button>
          </Box>
        )}
      </Drawer>

      {/* Main Canvas */}
      <Box sx={{ flex: 1, position: 'relative' }}>
        {/* Toolbar */}
        <Paper sx={{ position: 'absolute', top: 10, right: 10, zIndex: 10, p: 1 }}>
          <Box display="flex" gap={1}>
            <IconButton onClick={() => setDrawerOpen(!drawerOpen)}>
              <AccountTree />
            </IconButton>
            <IconButton onClick={handleSave} color="primary">
              <Save />
            </IconButton>
            <IconButton>
              <PlayArrow />
            </IconButton>
            <IconButton>
              <Settings />
            </IconButton>
          </Box>
        </Paper>

        {/* Validation Errors */}
        {validateWorkflow().length > 0 && (
          <Alert
            severity="warning"
            sx={{
              position: 'absolute',
              bottom: 10,
              left: 10,
              zIndex: 10,
              maxWidth: 400
            }}
          >
            <Typography variant="subtitle2">Validation Issues:</Typography>
            <ul style={{ margin: 0, paddingLeft: 20 }}>
              {validateWorkflow().map((error, index) => (
                <li key={index}><Typography variant="caption">{error}</Typography></li>
              ))}
            </ul>
          </Alert>
        )}

        {/* React Flow Canvas */}
        <div ref={reactFlowWrapper} style={{ width: '100%', height: '100%' }}>
          <ReactFlow
            nodes={nodes}
            edges={edges}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onConnect={onConnect}
            onNodeClick={onNodeClick}
            nodeTypes={nodeTypes}
            edgeTypes={edgeTypes}
            fitView
          >
            <Background variant="dots" gap={12} size={1} />
            <Controls />
            <MiniMap
              nodeColor={(node) => {
                switch (node.type) {
                  case 'approval':
                    return theme.palette.primary.main;
                  case 'condition':
                    return theme.palette.warning.main;
                  case 'notification':
                    return theme.palette.info.main;
                  default:
                    return '#ddd';
                }
              }}
            />
          </ReactFlow>
        </div>
      </Box>
    </Box>
  );
};

export default WorkflowDesigner;