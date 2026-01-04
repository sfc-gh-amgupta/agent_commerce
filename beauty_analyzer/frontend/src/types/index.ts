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
  toolResults?: any[];
  tables?: any[];
  analysisResult?: AnalysisResult;
  products?: ProductMatch[];
  cartUpdate?: CartUpdate;
  error?: string;
  // New fields
  timing?: {
    preprocessing_ms: number;
    agent_ms: number;
    total_ms: number;
  };
  thinking?: string;
  messageId?: string;
  feedback?: 'like' | 'dislike';
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
  demo?: DemoPageConfig;
}

export interface DemoPageConfig {
  hero_title: string;
  hero_subtitle: string;
  hero_cta: string;
  features: DemoFeature[];
}

export interface DemoFeature {
  icon: string;
  title: string;
  text: string;
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
  placeholder: string;
}

export interface ConversationState {
  messages: Message[];
  isLoading: boolean;
  sessionId: string | null;
  customerId: string | null;
  cartSessionId: string | null;
}

// Theme presets by industry
export const THEME_PRESETS: Record<string, ThemeConfig> = {
  // Beauty themes
  sephora: {
    primary_color: '#000000',
    secondary_color: '#E60023',
    background_color: '#FFFFFF',
    text_color: '#333333',
    accent_color: '#C9A050',
    border_radius: '12px',
    font_family: "'Helvetica Neue', Arial, sans-serif",
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
  // Electronics themes
  bestbuy: {
    primary_color: '#0046BE',
    secondary_color: '#FFE000',
    background_color: '#F0F4F8',
    text_color: '#1D252C',
    accent_color: '#FFE000',
    border_radius: '8px',
    font_family: "'Roboto', sans-serif",
  },
  apple: {
    primary_color: '#000000',
    secondary_color: '#0071E3',
    background_color: '#FBFBFD',
    text_color: '#1D1D1F',
    accent_color: '#0071E3',
    border_radius: '12px',
    font_family: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif",
  },
  // Fashion themes
  nordstrom: {
    primary_color: '#1B1B1B',
    secondary_color: '#8B6914',
    background_color: '#FAF9F7',
    text_color: '#1B1B1B',
    accent_color: '#8B6914',
    border_radius: '4px',
    font_family: "'Didot', 'Times New Roman', serif",
  },
  zara: {
    primary_color: '#000000',
    secondary_color: '#000000',
    background_color: '#FFFFFF',
    text_color: '#000000',
    accent_color: '#666666',
    border_radius: '0px',
    font_family: "'Helvetica Neue', Arial, sans-serif",
  },
  // Grocery themes
  wholefoods: {
    primary_color: '#00674B',
    secondary_color: '#F7941D',
    background_color: '#F5F5F0',
    text_color: '#333333',
    accent_color: '#F7941D',
    border_radius: '8px',
    font_family: "'Proxima Nova', Arial, sans-serif",
  },
  instacart: {
    primary_color: '#43B02A',
    secondary_color: '#FF6600',
    background_color: '#FFFFFF',
    text_color: '#343538',
    accent_color: '#FF6600',
    border_radius: '12px',
    font_family: "'Noto Sans', sans-serif",
  },
  // Airline themes
  delta: {
    primary_color: '#003366',
    secondary_color: '#C8102E',
    background_color: '#F5F7FA',
    text_color: '#1A1A1A',
    accent_color: '#C8102E',
    border_radius: '8px',
    font_family: "'Whitney', 'Helvetica Neue', sans-serif",
  },
  united: {
    primary_color: '#002244',
    secondary_color: '#0066B2',
    background_color: '#FFFFFF',
    text_color: '#333333',
    accent_color: '#0066B2',
    border_radius: '4px',
    font_family: "'Open Sans', Arial, sans-serif",
  },
  // Hotel themes
  marriott: {
    primary_color: '#1C1C1C',
    secondary_color: '#B4975A',
    background_color: '#FAF9F7',
    text_color: '#1C1C1C',
    accent_color: '#B4975A',
    border_radius: '4px',
    font_family: "'Swiss 721', 'Helvetica Neue', sans-serif",
  },
  hilton: {
    primary_color: '#104C97',
    secondary_color: '#00A1DE',
    background_color: '#FFFFFF',
    text_color: '#1A1A1A',
    accent_color: '#00A1DE',
    border_radius: '8px',
    font_family: "'Hilton Sans', Arial, sans-serif",
  },
};

export const DEFAULT_CONFIG: WidgetConfig = {
  retailer_name: 'Beauty Store',
  tagline: 'Beauty Advisor',
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
    placeholder: 'Type a message...',
  },
  demo: {
    hero_title: 'Find Your Perfect Shade',
    hero_subtitle: 'Our AI-powered beauty advisor analyzes your skin tone to recommend products that complement you perfectly.',
    hero_cta: '✨ Try the Beauty Advisor',
    features: [
      { icon: '📸', title: 'Skin Analysis', text: 'Upload a selfie and get instant analysis of your skin tone, undertone, and Monk shade.' },
      { icon: '🎨', title: 'Color Matching', text: 'Scientific color matching finds products that perfectly complement your unique beauty.' },
      { icon: '🛒', title: 'Easy Checkout', text: 'Add products to cart and checkout directly through the chat interface.' },
    ],
  },
};

