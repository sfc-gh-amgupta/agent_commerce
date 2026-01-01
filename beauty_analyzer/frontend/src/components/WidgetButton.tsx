// =============================================================================
// Agent Commerce - Widget Button Component (Collapsed State)
// =============================================================================

import { WidgetConfig, DEFAULT_CONFIG } from '../types';

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
      {config.widget.button_icon}
    </button>
  );
}

