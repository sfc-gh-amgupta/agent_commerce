// =============================================================================
// Agent Commerce - Admin Panel (No-Code Customization)
// =============================================================================

import { useState, useEffect } from 'react';
import type { WidgetConfig, ThemeConfig } from '../types';
import { THEME_PRESETS, DEFAULT_CONFIG } from '../types';
import './admin.css';

// Industry presets for quick switching
const INDUSTRY_PRESETS = {
  beauty: {
    retailer_name: 'Beauty Store',
    tagline: 'Beauty Advisor',
    theme: THEME_PRESETS.sephora,
    hero_title: 'Find Your Perfect Shade',
    hero_subtitle: 'Our AI-powered beauty advisor analyzes your skin tone to recommend products that complement you perfectly.',
    hero_cta: '✨ Try the Beauty Advisor',
    features: [
      { icon: '📸', title: 'Skin Analysis', text: 'Upload a selfie and get instant analysis of your skin tone, undertone, and Monk shade.' },
      { icon: '🎨', title: 'Color Matching', text: 'Scientific color matching finds products that perfectly complement your unique beauty.' },
      { icon: '🛒', title: 'Easy Checkout', text: 'Add products to cart and checkout directly through the chat interface.' },
    ],
  },
  electronics: {
    retailer_name: 'Tech Store',
    tagline: 'Tech Expert',
    theme: THEME_PRESETS.bestbuy,
    hero_title: 'Find Your Perfect Device',
    hero_subtitle: 'Our AI-powered assistant helps you discover the right technology based on your needs and preferences.',
    hero_cta: '💡 Chat with Tech Expert',
    features: [
      { icon: '💻', title: 'Smart Recommendations', text: 'Tell us what you need and get personalized device recommendations instantly.' },
      { icon: '📊', title: 'Compare Products', text: 'Side-by-side comparisons of specs, features, and prices across brands.' },
      { icon: '🛒', title: 'Easy Checkout', text: 'Add to cart and checkout seamlessly through the chat interface.' },
    ],
  },
  fashion: {
    retailer_name: 'Fashion Boutique',
    tagline: 'Style Advisor',
    theme: THEME_PRESETS.nordstrom,
    hero_title: 'Discover Your Style',
    hero_subtitle: 'Our AI stylist helps you find clothing that matches your taste, body type, and occasion.',
    hero_cta: '✨ Get Style Advice',
    features: [
      { icon: '👔', title: 'Style Analysis', text: 'Share your preferences and get curated outfit recommendations.' },
      { icon: '🎨', title: 'Color Coordination', text: 'Find pieces that complement your skin tone and existing wardrobe.' },
      { icon: '🛒', title: 'Easy Checkout', text: 'Add items to cart and checkout directly through the chat.' },
    ],
  },
  grocery: {
    retailer_name: 'Fresh Market',
    tagline: 'Shopping Assistant',
    theme: THEME_PRESETS.wholefoods,
    hero_title: 'Smart Grocery Shopping',
    hero_subtitle: 'Our AI assistant helps you find products, compare prices, and plan your shopping list.',
    hero_cta: '🥬 Start Shopping',
    features: [
      { icon: '🍎', title: 'Product Finder', text: 'Describe what you need and find products instantly across categories.' },
      { icon: '📋', title: 'List Builder', text: 'Build your shopping list through natural conversation.' },
      { icon: '🛒', title: 'Easy Checkout', text: 'Add to cart and schedule delivery through the chat.' },
    ],
  },
  airlines: {
    retailer_name: 'Sky Airlines',
    tagline: 'Travel Assistant',
    theme: THEME_PRESETS.delta,
    hero_title: 'Book Your Next Adventure',
    hero_subtitle: 'Our AI travel assistant helps you find the best flights, manage bookings, and get real-time updates.',
    hero_cta: '✈️ Find Flights',
    features: [
      { icon: '🔍', title: 'Flight Search', text: 'Find the best routes and prices with natural language search.' },
      { icon: '💺', title: 'Seat Selection', text: 'Choose your preferred seat and upgrade options easily.' },
      { icon: '📱', title: 'Trip Management', text: 'Check-in, boarding passes, and real-time flight status.' },
    ],
  },
  hotels: {
    retailer_name: 'Grand Hotels',
    tagline: 'Concierge Assistant',
    theme: THEME_PRESETS.marriott,
    hero_title: 'Find Your Perfect Stay',
    hero_subtitle: 'Our AI concierge helps you discover hotels, compare amenities, and book the perfect room.',
    hero_cta: '🏨 Book Now',
    features: [
      { icon: '🛏️', title: 'Room Finder', text: 'Describe your ideal stay and get personalized recommendations.' },
      { icon: '⭐', title: 'Reviews & Ratings', text: 'See what guests are saying with AI-summarized reviews.' },
      { icon: '🎁', title: 'Loyalty Rewards', text: 'Track points and unlock exclusive member benefits.' },
    ],
  },
};

interface AdminPanelProps {
  config: WidgetConfig;
  onConfigChange: (config: WidgetConfig) => void;
}

export function AdminPanel({ config, onConfigChange }: AdminPanelProps) {
  const [localConfig, setLocalConfig] = useState<WidgetConfig>(config);
  const [logoPreview, setLogoPreview] = useState<string | null>(config.logo_url);

  useEffect(() => {
    setLocalConfig(config);
  }, [config]);

  const handleChange = <K extends keyof WidgetConfig>(key: K, value: WidgetConfig[K]) => {
    const newConfig = { ...localConfig, [key]: value };
    setLocalConfig(newConfig);
    onConfigChange(newConfig);
  };

  const handleThemeChange = <K extends keyof ThemeConfig>(key: K, value: ThemeConfig[K]) => {
    const newTheme = { ...localConfig.theme, [key]: value };
    handleChange('theme', newTheme);
  };

  const handlePresetChange = (presetName: string) => {
    const preset = THEME_PRESETS[presetName];
    if (preset) {
      handleChange('theme', preset);
    }
  };

  const handleLogoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        const url = reader.result as string;
        setLogoPreview(url);
        handleChange('logo_url', url);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleReset = () => {
    setLocalConfig(DEFAULT_CONFIG);
    setLogoPreview(null);
    onConfigChange(DEFAULT_CONFIG);
  };

  const handleIndustryChange = (industry: string) => {
    const preset = INDUSTRY_PRESETS[industry as keyof typeof INDUSTRY_PRESETS];
    if (preset) {
      const newConfig = {
        ...localConfig,
        retailer_name: preset.retailer_name,
        tagline: preset.tagline,
        theme: preset.theme,
        demo: {
          hero_title: preset.hero_title,
          hero_subtitle: preset.hero_subtitle,
          hero_cta: preset.hero_cta,
          features: preset.features,
        },
      };
      setLocalConfig(newConfig as WidgetConfig);
      onConfigChange(newConfig as WidgetConfig);
    }
  };

  return (
    <div className="admin-panel">
      <div className="admin-header">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h1>🎨 Widget Customization</h1>
            <p>Configure the widget appearance - changes apply instantly!</p>
          </div>
          <a href="/" className="back-to-demo-btn">
            ← Back to Demo
          </a>
        </div>
      </div>

      <div className="admin-content">
        {/* Industry Presets - Quick Switch */}
        <section className="admin-section">
          <h2>🏪 Industry Preset</h2>
          <p style={{ fontSize: '13px', color: 'rgba(255,255,255,0.6)', marginBottom: '16px' }}>
            Quickly switch the entire demo to a different retail vertical
          </p>
          <div className="preset-grid">
            {Object.entries(INDUSTRY_PRESETS).map(([key, preset]) => {
              const icons: Record<string, string> = {
                beauty: '💄',
                electronics: '📱',
                fashion: '👗',
                grocery: '🛒',
                airlines: '✈️',
                hotels: '🏨',
              };
              return (
                <button
                  key={key}
                  className={`industry-btn ${localConfig.retailer_name === preset.retailer_name ? 'active' : ''}`}
                  onClick={() => handleIndustryChange(key)}
                >
                  <span className="industry-icon">{icons[key] || '🏪'}</span>
                  <span>{key.charAt(0).toUpperCase() + key.slice(1)}</span>
                </button>
              );
            })}
          </div>
        </section>

        {/* Branding Section */}
        <section className="admin-section">
          <h2>Branding</h2>
          
          <div className="form-group">
            <label>Retailer Name</label>
            <input
              type="text"
              value={localConfig.retailer_name}
              onChange={(e) => handleChange('retailer_name', e.target.value)}
              placeholder="e.g., Sephora"
            />
          </div>

          <div className="form-group">
            <label>Tagline</label>
            <input
              type="text"
              value={localConfig.tagline}
              onChange={(e) => handleChange('tagline', e.target.value)}
              placeholder="e.g., Commerce Assistant"
            />
          </div>

          <div className="form-group">
            <label>Logo</label>
            <div className="logo-upload">
              {logoPreview ? (
                <img src={logoPreview} alt="Logo preview" className="logo-preview" />
              ) : (
                <div className="logo-placeholder">No logo</div>
              )}
              <input
                type="file"
                accept="image/*"
                onChange={handleLogoUpload}
                id="logo-input"
              />
              <label htmlFor="logo-input" className="upload-btn">
                Upload Logo
              </label>
            </div>
          </div>
        </section>

        {/* Theme Presets */}
        <section className="admin-section">
          <h2>Theme Presets</h2>
          <div className="preset-grid">
            {Object.entries(THEME_PRESETS).map(([name, preset]) => (
              <button
                key={name}
                className={`preset-btn ${
                  JSON.stringify(localConfig.theme) === JSON.stringify(preset) ? 'active' : ''
                }`}
                onClick={() => handlePresetChange(name)}
                style={{
                  background: `linear-gradient(135deg, ${preset.primary_color} 0%, ${preset.secondary_color} 100%)`,
                }}
              >
                {name.charAt(0).toUpperCase() + name.slice(1)}
              </button>
            ))}
          </div>
        </section>

        {/* Colors Section */}
        <section className="admin-section">
          <h2>Custom Colors</h2>
          <div className="color-grid">
            <div className="form-group">
              <label>Primary</label>
              <div className="color-input">
                <input
                  type="color"
                  value={localConfig.theme.primary_color}
                  onChange={(e) => handleThemeChange('primary_color', e.target.value)}
                />
                <input
                  type="text"
                  value={localConfig.theme.primary_color}
                  onChange={(e) => handleThemeChange('primary_color', e.target.value)}
                />
              </div>
            </div>

            <div className="form-group">
              <label>Secondary</label>
              <div className="color-input">
                <input
                  type="color"
                  value={localConfig.theme.secondary_color}
                  onChange={(e) => handleThemeChange('secondary_color', e.target.value)}
                />
                <input
                  type="text"
                  value={localConfig.theme.secondary_color}
                  onChange={(e) => handleThemeChange('secondary_color', e.target.value)}
                />
              </div>
            </div>

            <div className="form-group">
              <label>Background</label>
              <div className="color-input">
                <input
                  type="color"
                  value={localConfig.theme.background_color}
                  onChange={(e) => handleThemeChange('background_color', e.target.value)}
                />
                <input
                  type="text"
                  value={localConfig.theme.background_color}
                  onChange={(e) => handleThemeChange('background_color', e.target.value)}
                />
              </div>
            </div>

            <div className="form-group">
              <label>Accent</label>
              <div className="color-input">
                <input
                  type="color"
                  value={localConfig.theme.accent_color}
                  onChange={(e) => handleThemeChange('accent_color', e.target.value)}
                />
                <input
                  type="text"
                  value={localConfig.theme.accent_color}
                  onChange={(e) => handleThemeChange('accent_color', e.target.value)}
                />
              </div>
            </div>
          </div>
        </section>

        {/* Widget Settings */}
        <section className="admin-section">
          <h2>Widget Settings</h2>
          
          <div className="form-group">
            <label>Position</label>
            <div className="radio-group">
              <label>
                <input
                  type="radio"
                  name="position"
                  checked={localConfig.widget.position === 'bottom-right'}
                  onChange={() => handleChange('widget', { ...localConfig.widget, position: 'bottom-right' })}
                />
                Bottom Right
              </label>
              <label>
                <input
                  type="radio"
                  name="position"
                  checked={localConfig.widget.position === 'bottom-left'}
                  onChange={() => handleChange('widget', { ...localConfig.widget, position: 'bottom-left' })}
                />
                Bottom Left
              </label>
            </div>
          </div>

          <div className="form-group">
            <label>Button Icon</label>
            <input
              type="text"
              value={localConfig.widget.button_icon}
              onChange={(e) => handleChange('widget', { ...localConfig.widget, button_icon: e.target.value })}
              placeholder="💄"
              style={{ fontSize: '24px', textAlign: 'center', width: '60px' }}
            />
          </div>

          <div className="form-group">
            <label>Border Radius</label>
            <input
              type="range"
              min="0"
              max="24"
              value={parseInt(localConfig.theme.border_radius)}
              onChange={(e) => handleThemeChange('border_radius', `${e.target.value}px`)}
            />
            <span>{localConfig.theme.border_radius}</span>
          </div>
        </section>

        {/* Messages */}
        <section className="admin-section">
          <h2>Messages</h2>
          
          <div className="form-group">
            <label>Welcome Message</label>
            <textarea
              value={localConfig.messages.welcome}
              onChange={(e) => handleChange('messages', { ...localConfig.messages, welcome: e.target.value })}
              rows={3}
            />
          </div>
        </section>

        {/* Actions */}
        <div className="admin-actions">
          <button className="reset-btn" onClick={handleReset}>
            Reset to Default
          </button>
        </div>
      </div>
    </div>
  );
}

