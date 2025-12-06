import { definePreset } from '@primeuix/themes';
import Aura from '@primeuix/themes/aura';

const Preset = definePreset(Aura, {
  semantic: {
    primary: {
      50: '{zinc.50}',
      100: '{zinc.100}',
      200: '{zinc.200}',
      300: '{zinc.300}',
      400: '{zinc.400}',
      500: '{zinc.500}',
      600: '{zinc.600}',
      700: '{zinc.700}',
      800: '{zinc.800}',
      900: '{zinc.900}',
      950: '{zinc.950}'
    },
    secondary: {
      100: '{blue.100}',
      500: '{blue.500}',
      700: '{blue.700}',
      900: '{blue.900}'
    },
    success: {
      100: '{green.100}',
      500: '{green.500}',
      700: '{green.700}',
      900: '{green.900}'
    },
    danger: {
      100: '{red.100}',
      500: '{red.500}',
      700: '{red.700}',
      900: '{red.900}'
    },
    warning: {
      100: '{yellow.100}',
      500: '{yellow.500}',
      700: '{yellow.700}',
      900: '{yellow.900}'
    },
    colorScheme: {
      light: {
        primary: {
          color: '{zinc.900}',
          inverseColor: '#ffffff',
          hoverColor: '{zinc.800}',
          activeColor: '{zinc.700}'
        },
        secondary: {
          color: '{blue.700}',
          inverseColor: '#ffffff',
          hoverColor: '{blue.600}',
          activeColor: '{blue.500}'
        },
        success: {
          color: '{green.700}',
          inverseColor: '#ffffff',
          hoverColor: '{green.600}',
          activeColor: '{green.500}'
        },
        danger: {
          color: '{red.700}',
          inverseColor: '#ffffff',
          hoverColor: '{red.600}',
          activeColor: '{red.500}'
        },
        warning: {
          color: '{yellow.700}',
          inverseColor: '#ffffff',
          hoverColor: '{yellow.600}',
          activeColor: '{yellow.500}'
        }
      },
      dark: {
        primary: {
          color: '#ffffff',
          inverseColor: '#22272e',
          hoverColor: '#f3f4f6',
          activeColor: '#e5e7eb',
          borderColor: '#ffffff',
          shadow: '0 2px 8px rgba(0,0,0,0.15)'
        },
        secondary: {
          color: '#2563eb',
          inverseColor: '#ffffff',
          hoverColor: '#1d4ed8',
          activeColor: '#1e40af',
          borderColor: '#2563eb',
          shadow: '0 2px 8px rgba(37,99,235,0.15)'
        },
        success: {
          color: '#22c55e',
          inverseColor: '#ffffff',
          hoverColor: '#16a34a',
          activeColor: '#15803d',
          borderColor: '#22c55e',
          shadow: '0 2px 8px rgba(34,197,94,0.15)'
        },
        danger: {
          color: '#ef4444',
          inverseColor: '#ffffff',
          hoverColor: '#dc2626',
          activeColor: '#b91c1c',
          borderColor: '#ef4444',
          shadow: '0 2px 8px rgba(239,68,68,0.15)'
        },
        warning: {
          color: '#eab308',
          inverseColor: '#ffffff',
          hoverColor: '#ca8a04',
          activeColor: '#a16207',
          borderColor: '#eab308',
          shadow: '0 2px 8px rgba(234,179,8,0.15)'
        }
      }
    }
  },
  theme: {
    borderRadius: '10px',
    fontFamily: 'Space Grotesk, Inter, system-ui, sans-serif',
    fontSize: '16px',
    boxShadow: '0 2px 8px rgba(0,0,0,0.07)',
    borderWidth: '2px',
    background: {
      light: '#f9fafc',
      dark: '#181a20'
    }
  }
});

export default Preset;