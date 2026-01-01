// =============================================================================
// Agent Commerce - Widget Button Component (Collapsed State)
// =============================================================================

import type { WidgetConfig } from '../types';
import { DEFAULT_CONFIG } from '../types';

// Clean, modern chat icon SVG - always white for visibility on gradient backgrounds
const ChatIcon = () => (
  <svg 
    width="28" 
    height="28" 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="#FFFFFF" 
    strokeWidth="2" 
    strokeLinecap="round" 
    strokeLinejoin="round"
  >
    <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z" />
    <circle cx="12" cy="12" r="1" fill="#FFFFFF" stroke="none" />
    <circle cx="8" cy="12" r="1" fill="#FFFFFF" stroke="none" />
    <circle cx="16" cy="12" r="1" fill="#FFFFFF" stroke="none" />
  </svg>
);

interface WidgetButtonProps {
  config?: WidgetConfig;
  onClick: () => void;
}

export function WidgetButton({ config = DEFAULT_CONFIG, onClick }: WidgetButtonProps) {
  return (
    <button
      className={`widget-button ${config.widget.position === 'bottom-left' ? 'left' : ''}`}
      onClick={onClick}
      style={{
        background: `linear-gradient(135deg, ${config.theme.primary_color} 0%, ${config.theme.secondary_color} 100%)`,
      }}
      title={config.widget.button_text}
    >
      <ChatIcon />
    </button>
  );
}

