import { createTheme, ThemeOptions } from '@mui/material/styles';

// Vanta X Brand Colors
const brandColors = {
  primary: {
    main: '#3B82F6',
    light: '#60A5FA',
    dark: '#1E3A8A',
    contrastText: '#FFFFFF',
  },
  secondary: {
    main: '#8B5CF6',
    light: '#A78BFA',
    dark: '#6D28D9',
    contrastText: '#FFFFFF',
  },
  accent: {
    teal: '#14B8A6',
    orange: '#F97316',
    pink: '#EC4899',
    green: '#10B981',
  },
  neutral: {
    50: '#F8FAFC',
    100: '#F1F5F9',
    200: '#E2E8F0',
    300: '#CBD5E1',
    400: '#94A3B8',
    500: '#64748B',
    600: '#475569',
    700: '#334155',
    800: '#1E293B',
    900: '#0F172A',
  },
  status: {
    success: '#10B981',
    warning: '#F59E0B',
    error: '#EF4444',
    info: '#3B82F6',
  },
};

// Responsive breakpoints
const breakpoints = {
  values: {
    xs: 0,
    sm: 640,
    md: 768,
    lg: 1024,
    xl: 1280,
    '2xl': 1536,
  },
};

// Typography configuration
const typography = {
  fontFamily: '"Inter", "Segoe UI", "Roboto", "Arial", sans-serif',
  h1: {
    fontSize: '2.5rem',
    fontWeight: 700,
    lineHeight: 1.2,
    '@media (min-width:768px)': {
      fontSize: '3rem',
    },
    '@media (min-width:1024px)': {
      fontSize: '3.5rem',
    },
  },
  h2: {
    fontSize: '2rem',
    fontWeight: 600,
    lineHeight: 1.3,
    '@media (min-width:768px)': {
      fontSize: '2.5rem',
    },
  },
  h3: {
    fontSize: '1.75rem',
    fontWeight: 600,
    lineHeight: 1.4,
    '@media (min-width:768px)': {
      fontSize: '2rem',
    },
  },
  h4: {
    fontSize: '1.5rem',
    fontWeight: 500,
    lineHeight: 1.4,
  },
  h5: {
    fontSize: '1.25rem',
    fontWeight: 500,
    lineHeight: 1.5,
  },
  h6: {
    fontSize: '1.125rem',
    fontWeight: 500,
    lineHeight: 1.5,
  },
  body1: {
    fontSize: '1rem',
    lineHeight: 1.6,
  },
  body2: {
    fontSize: '0.875rem',
    lineHeight: 1.6,
  },
  button: {
    textTransform: 'none',
    fontWeight: 500,
  },
};

// Component overrides for responsive design
const components = {
  MuiButton: {
    styleOverrides: {
      root: {
        borderRadius: '0.5rem',
        padding: '0.5rem 1rem',
        transition: 'all 0.2s ease-in-out',
        '&:hover': {
          transform: 'translateY(-1px)',
          boxShadow: '0 4px 12px rgba(0, 0, 0, 0.15)',
        },
      },
      sizeLarge: {
        padding: '0.75rem 1.5rem',
        fontSize: '1.125rem',
      },
      sizeSmall: {
        padding: '0.375rem 0.75rem',
        fontSize: '0.875rem',
      },
    },
  },
  MuiCard: {
    styleOverrides: {
      root: {
        borderRadius: '0.75rem',
        boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)',
        transition: 'all 0.2s ease-in-out',
        '&:hover': {
          boxShadow: '0 4px 12px rgba(0, 0, 0, 0.15)',
        },
      },
    },
  },
  MuiTextField: {
    styleOverrides: {
      root: {
        '& .MuiOutlinedInput-root': {
          borderRadius: '0.5rem',
        },
      },
    },
  },
  MuiAppBar: {
    styleOverrides: {
      root: {
        boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)',
        backdropFilter: 'blur(8px)',
        backgroundColor: 'rgba(255, 255, 255, 0.9)',
      },
    },
  },
  MuiDrawer: {
    styleOverrides: {
      paper: {
        borderRadius: '0 0.75rem 0.75rem 0',
      },
    },
  },
  MuiDataGrid: {
    styleOverrides: {
      root: {
        border: 'none',
        borderRadius: '0.75rem',
        '& .MuiDataGrid-cell': {
          borderBottom: `1px solid ${brandColors.neutral[200]}`,
        },
        '& .MuiDataGrid-columnHeaders': {
          backgroundColor: brandColors.neutral[50],
          borderBottom: `2px solid ${brandColors.neutral[200]}`,
        },
      },
    },
  },
};

// Create light theme
export const lightTheme = createTheme({
  palette: {
    mode: 'light',
    primary: brandColors.primary,
    secondary: brandColors.secondary,
    error: {
      main: brandColors.status.error,
    },
    warning: {
      main: brandColors.status.warning,
    },
    info: {
      main: brandColors.status.info,
    },
    success: {
      main: brandColors.status.success,
    },
    background: {
      default: brandColors.neutral[50],
      paper: '#FFFFFF',
    },
    text: {
      primary: brandColors.neutral[900],
      secondary: brandColors.neutral[600],
    },
  },
  breakpoints,
  typography,
  components,
  shape: {
    borderRadius: 8,
  },
  spacing: 8,
} as ThemeOptions);

// Create dark theme
export const darkTheme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: brandColors.primary.light,
      light: brandColors.primary.main,
      dark: brandColors.primary.dark,
    },
    secondary: {
      main: brandColors.secondary.light,
      light: brandColors.secondary.main,
      dark: brandColors.secondary.dark,
    },
    error: {
      main: brandColors.status.error,
    },
    warning: {
      main: brandColors.status.warning,
    },
    info: {
      main: brandColors.status.info,
    },
    success: {
      main: brandColors.status.success,
    },
    background: {
      default: brandColors.neutral[900],
      paper: brandColors.neutral[800],
    },
    text: {
      primary: brandColors.neutral[50],
      secondary: brandColors.neutral[300],
    },
  },
  breakpoints,
  typography,
  components: {
    ...components,
    MuiAppBar: {
      styleOverrides: {
        root: {
          boxShadow: '0 1px 3px rgba(0, 0, 0, 0.3)',
          backdropFilter: 'blur(8px)',
          backgroundColor: 'rgba(15, 23, 42, 0.9)',
        },
      },
    },
    MuiDataGrid: {
      styleOverrides: {
        root: {
          border: 'none',
          borderRadius: '0.75rem',
          '& .MuiDataGrid-cell': {
            borderBottom: `1px solid ${brandColors.neutral[700]}`,
          },
          '& .MuiDataGrid-columnHeaders': {
            backgroundColor: brandColors.neutral[800],
            borderBottom: `2px solid ${brandColors.neutral[700]}`,
          },
        },
      },
    },
  },
  shape: {
    borderRadius: 8,
  },
  spacing: 8,
} as ThemeOptions);

// Export brand assets
export { brandColors };

// Responsive utilities
export const responsive = {
  isMobile: '@media (max-width: 767px)',
  isTablet: '@media (min-width: 768px) and (max-width: 1023px)',
  isDesktop: '@media (min-width: 1024px)',
  isLargeDesktop: '@media (min-width: 1280px)',
};

// Export default theme
export default lightTheme;