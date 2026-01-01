// =============================================================================
// Agent Commerce - Type Definitions
// =============================================================================

export interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  attachments?: Attachment[];
  metadata?: MessageMetadata;
}

export interface Attachment {
  type: 'image' | 'file';
  url: string;
  name?: string;
  base64?: string;
}

export interface MessageMetadata {
  toolsUsed?: string[];
  analysisResult?: AnalysisResult;
  products?: ProductMatch[];
  cartUpdate?: CartUpdate;
}

export interface AnalysisResult {
  success: boolean;
  face_detected: boolean;
  skin_hex?: string;
  skin_lab?: number[];
  lip_hex?: string;
  lip_lab?: string;
  fitzpatrick?: number;
  monk_shade?: number;
  undertone?: 'warm' | 'cool' | 'neutral';
  embedding?: number[];
  quality_score?: number;
  makeup_detected?: boolean;
  customer_match?: CustomerMatch;
}

export interface CustomerMatch {
  customer_id: string;
  first_name: string;
  last_name: string;
  email: string;
  loyalty_tier: string;
  points_balance: number;
  confidence: number;
}

export interface ProductMatch {
  product_id: string;
  name: string;
  brand: string;
  category: string;
  swatch_hex: string;
  color_distance: number;
  price: number;
  image_url?: string;
}

export interface CartUpdate {
  action: 'created' | 'added' | 'updated' | 'removed' | 'checkout';
  session_id?: string;
  item_id?: string;
  order_id?: string;
  order_number?: string;
  total_cents?: number;
}

export interface WidgetConfig {
  retailer_name: string;
  tagline: string;
  logo_url: string | null;
  theme: ThemeConfig;
  widget: WidgetSettings;
  messages: MessageTemplates;
}

export interface ThemeConfig {
  primary_color: string;
  secondary_color: string;
  background_color: string;
  text_color: string;
  accent_color: string;
  border_radius: string;
  font_family: string;
}

export interface WidgetSettings {
  position: 'bottom-right' | 'bottom-left';
  button_text: string;
  button_icon: string;
  width: string;
  height: string;
}

export interface MessageTemplates {
  welcome: string;
  identity_prompt: string;
  analysis_complete: string;
}

export interface ConversationState {
  messages: Message[];
  isLoading: boolean;
  sessionId: string | null;
  customerId: string | null;
  cartSessionId: string | null;
}

// Theme presets
export const THEME_PRESETS: Record<string, ThemeConfig> = {
  sephora: {
    primary_color: '#000000',
    secondary_color: '#E60023',
    background_color: '#FFFFFF',
    text_color: '#333333',
    accent_color: '#C9A050',
    border_radius: '12px',
    font_family: "'Helvetica Neue', Arial, sans-serif",
  },
  ulta: {
    primary_color: '#FF6900',
    secondary_color: '#FF1493',
    background_color: '#FFF5EE',
    text_color: '#333333',
    accent_color: '#FFD700',
    border_radius: '8px',
    font_family: "'Arial', sans-serif",
  },
  mac: {
    primary_color: '#000000',
    secondary_color: '#000000',
    background_color: '#FFFFFF',
    text_color: '#333333',
    accent_color: '#808080',
    border_radius: '0px',
    font_family: "'Futura', sans-serif",
  },
  glossier: {
    primary_color: '#FFB6C1',
    secondary_color: '#FF69B4',
    background_color: '#FFF0F5',
    text_color: '#333333',
    accent_color: '#FF1493',
    border_radius: '20px',
    font_family: "'Inter', sans-serif",
  },
};

export const DEFAULT_CONFIG: WidgetConfig = {
  retailer_name: 'Beauty Store',
  tagline: 'Commerce Assistant',
  logo_url: null,
  theme: THEME_PRESETS.sephora,
  widget: {
    position: 'bottom-right',
    button_text: 'Chat with Us',
    button_icon: '💄',
    width: '380px',
    height: '600px',
  },
  messages: {
    welcome: "Hi! I'm your Commerce Assistant. How can I help you today?",
    identity_prompt: 'Is this you, {name}?',
    analysis_complete: '✨ Your Beauty Profile',
  },
};

