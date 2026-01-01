// =============================================================================
// Agent Commerce - Main Application
// =============================================================================

import { useState, useEffect } from 'react';
import { ChatWidget } from './components/ChatWidget';
import { WidgetButton } from './components/WidgetButton';
import { AdminPanel } from './admin/AdminPanel';
import type { WidgetConfig } from './types';
import { DEFAULT_CONFIG } from './types';
import './styles/widget.css';

function App() {
  const [isOpen, setIsOpen] = useState(false);
  const [config, setConfig] = useState<WidgetConfig>(DEFAULT_CONFIG);
  const [mode, setMode] = useState<'demo' | 'admin' | 'widget'>('demo');

  // Check URL path on load
  useEffect(() => {
    const path = window.location.pathname;
    if (path === '/admin') {
      setMode('admin');
    } else if (path === '/widget') {
      setMode('widget');
    } else {
      setMode('demo');  // Default to demo at /
    }
  }, []);

  // Save config to localStorage for persistence during demo
  useEffect(() => {
    const saved = localStorage.getItem('widget-config');
    if (saved) {
      try {
        setConfig(JSON.parse(saved));
      } catch (e) {
        console.error('Failed to parse saved config');
      }
    }
  }, []);

  const handleConfigChange = (newConfig: WidgetConfig) => {
    setConfig(newConfig);
    localStorage.setItem('widget-config', JSON.stringify(newConfig));
  };

  // Admin mode - show configuration panel
  if (mode === 'admin') {
    return (
      <div style={{ display: 'flex', height: '100vh' }}>
        <div style={{ flex: 1, overflow: 'auto' }}>
          <AdminPanel config={config} onConfigChange={handleConfigChange} />
        </div>
        <div 
          style={{ 
            width: '420px', 
            background: '#f0f0f0', 
            borderLeft: '1px solid #ddd',
            position: 'relative',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <div style={{ 
            textAlign: 'center', 
            color: '#666', 
            fontSize: '14px',
            padding: '20px'
          }}>
            <h3>Live Preview</h3>
            <p>Widget preview with current settings</p>
          </div>
          {isOpen ? (
            <ChatWidget config={config} onClose={() => setIsOpen(false)} />
          ) : (
            <WidgetButton config={config} onClick={() => setIsOpen(true)} />
          )}
        </div>
      </div>
    );
  }

  // Widget-only mode (standalone)
  if (mode === 'widget') {
    return (
      <>
        {isOpen ? (
          <ChatWidget config={config} onClose={() => setIsOpen(false)} />
        ) : (
          <WidgetButton config={config} onClick={() => setIsOpen(true)} />
        )}
      </>
    );
  }

  // Demo mode - mock retailer website with embedded widget
  return (
    <div style={{
      ...demoStyles.page,
      background: `linear-gradient(180deg, ${config.theme.background_color} 0%, ${config.theme.accent_color}15 100%)`,
    }}>
      {/* Demo Header */}
      <header style={demoStyles.header}>
        <div style={demoStyles.headerContent}>
          <div style={demoStyles.logo}>
            {config.logo_url ? (
              <img src={config.logo_url} alt="Logo" style={{ height: '32px' }} />
            ) : (
              <span style={{ 
                fontSize: '20px', 
                width: '36px', 
                height: '36px', 
                background: `linear-gradient(135deg, ${config.theme.primary_color} 0%, ${config.theme.secondary_color} 100%)`,
                borderRadius: '8px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff',
              }}>🛍️</span>
            )}
            <span style={demoStyles.logoText}>{config.retailer_name}</span>
          </div>
          <nav style={demoStyles.nav}>
            <a href="#" style={demoStyles.navLink}>Shop</a>
            <a href="#" style={demoStyles.navLink}>New</a>
            <a href="#" style={demoStyles.navLink}>Brands</a>
            <a href="/admin" style={{...demoStyles.navLink, color: config.theme.secondary_color, fontWeight: 600}}>⚙️ Admin</a>
          </nav>
        </div>
      </header>

      {/* Hero Section */}
      <section style={demoStyles.hero}>
        <div style={demoStyles.heroContent}>
          <h1 style={demoStyles.heroTitle}>
            {config.demo?.hero_title || 'Find Your Perfect Match'}
          </h1>
          <p style={demoStyles.heroSubtitle}>
            {config.demo?.hero_subtitle || 'Our AI-powered assistant helps you discover exactly what you need.'}
          </p>
          <button 
            style={{
              ...demoStyles.heroCta,
              background: `linear-gradient(135deg, ${config.theme.primary_color} 0%, ${config.theme.secondary_color} 100%)`,
            }}
            onClick={() => setIsOpen(true)}
          >
            {config.demo?.hero_cta || '✨ Get Started'}
          </button>
        </div>
        <div style={demoStyles.heroImage}>
          <div style={{
            ...demoStyles.heroImagePlaceholder,
            background: `linear-gradient(135deg, ${config.theme.background_color} 0%, ${config.theme.accent_color}22 100%)`,
            border: `2px solid ${config.theme.accent_color}44`,
          }}>
            ✨
          </div>
        </div>
      </section>

      {/* Features */}
      <section style={demoStyles.features}>
        {(config.demo?.features || [
          { icon: '🔍', title: 'Smart Search', text: 'Find exactly what you need with AI-powered discovery.' },
          { icon: '💬', title: 'Chat Assistant', text: 'Get personalized recommendations through natural conversation.' },
          { icon: '🛒', title: 'Easy Checkout', text: 'Add to cart and checkout seamlessly through the chat.' },
        ]).map((feature, idx) => (
          <div key={idx} style={demoStyles.feature}>
            <div style={demoStyles.featureIcon}>{feature.icon}</div>
            <h3 style={demoStyles.featureTitle}>{feature.title}</h3>
            <p style={demoStyles.featureText}>{feature.text}</p>
          </div>
        ))}
      </section>

      {/* Widget */}
      {isOpen ? (
        <ChatWidget config={config} onClose={() => setIsOpen(false)} />
      ) : (
        <WidgetButton config={config} onClick={() => setIsOpen(true)} />
      )}
    </div>
  );
}

// Demo page styles
const demoStyles: Record<string, React.CSSProperties> = {
  page: {
    minHeight: '100vh',
    background: 'linear-gradient(180deg, #fdf2f8 0%, #fce7f3 100%)',
    fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
  },
  header: {
    background: '#fff',
    padding: '16px 0',
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
  },
  headerContent: {
    maxWidth: '1200px',
    margin: '0 auto',
    padding: '0 24px',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  logo: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
  },
  logoText: {
    fontSize: '20px',
    fontWeight: 700,
  },
  nav: {
    display: 'flex',
    gap: '32px',
  },
  navLink: {
    color: '#333',
    textDecoration: 'none',
    fontSize: '14px',
    fontWeight: 500,
  },
  hero: {
    maxWidth: '1200px',
    margin: '0 auto',
    padding: '80px 24px',
    display: 'flex',
    alignItems: 'center',
    gap: '60px',
  },
  heroContent: {
    flex: 1,
  },
  heroTitle: {
    fontSize: '48px',
    fontWeight: 700,
    color: '#1a1a2e',
    margin: '0 0 16px',
    lineHeight: 1.2,
  },
  heroSubtitle: {
    fontSize: '18px',
    color: '#666',
    margin: '0 0 32px',
    lineHeight: 1.6,
  },
  heroCta: {
    padding: '16px 32px',
    background: 'linear-gradient(135deg, #ec4899 0%, #8b5cf6 100%)',
    border: 'none',
    borderRadius: '12px',
    color: '#fff',
    fontSize: '16px',
    fontWeight: 600,
    cursor: 'pointer',
    boxShadow: '0 4px 20px rgba(236, 72, 153, 0.4)',
  },
  heroImage: {
    flex: 1,
    display: 'flex',
    justifyContent: 'center',
  },
  heroImagePlaceholder: {
    width: '300px',
    height: '300px',
    background: 'linear-gradient(135deg, #fff 0%, #fce7f3 100%)',
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '80px',
    boxShadow: '0 20px 60px rgba(0,0,0,0.1)',
  },
  features: {
    maxWidth: '1200px',
    margin: '0 auto',
    padding: '40px 24px 80px',
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '32px',
  },
  feature: {
    background: '#fff',
    padding: '32px',
    borderRadius: '16px',
    textAlign: 'center' as const,
    boxShadow: '0 4px 20px rgba(0,0,0,0.05)',
  },
  featureIcon: {
    fontSize: '40px',
    marginBottom: '16px',
  },
  featureTitle: {
    fontSize: '18px',
    fontWeight: 600,
    margin: '0 0 8px',
    color: '#1a1a2e',
  },
  featureText: {
    fontSize: '14px',
    color: '#666',
    margin: 0,
    lineHeight: 1.6,
  },
};

export default App;
