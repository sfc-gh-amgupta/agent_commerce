// =============================================================================
// Agent Commerce - Admin Panel (No-Code Customization)
// =============================================================================

import { useState, useEffect } from 'react';
import { WidgetConfig, ThemeConfig, THEME_PRESETS, DEFAULT_CONFIG } from '../types';
import './admin.css';

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

  return (
    <div className="admin-panel">
      <div className="admin-header">
        <h1>🎨 Widget Customization</h1>
        <p>Configure the widget appearance - changes apply instantly!</p>
      </div>

      <div className="admin-content">
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

