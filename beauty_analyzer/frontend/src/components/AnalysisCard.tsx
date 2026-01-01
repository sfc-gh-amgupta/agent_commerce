// =============================================================================
// Agent Commerce - Analysis Result Card Component
// =============================================================================

import { AnalysisResult } from '../types';

interface AnalysisCardProps {
  result: AnalysisResult;
}

export function AnalysisCard({ result }: AnalysisCardProps) {
  if (!result.success || !result.face_detected) {
    return null;
  }

  const getUndertoneIcon = (undertone?: string) => {
    switch (undertone) {
      case 'warm': return '☀️';
      case 'cool': return '❄️';
      case 'neutral': return '⚖️';
      default: return '🔄';
    }
  };

  const getFitzpatrickLabel = (type?: number) => {
    const labels: Record<number, string> = {
      1: 'Very Light',
      2: 'Light',
      3: 'Medium Light',
      4: 'Medium',
      5: 'Medium Dark',
      6: 'Dark',
    };
    return type ? labels[type] || `Type ${type}` : 'Unknown';
  };

  return (
    <div className="analysis-card">
      <h4 className="analysis-card-title">
        ✨ Your Beauty Profile
      </h4>

      <div className="analysis-grid">
        {/* Skin Tone */}
        <div className="analysis-item">
          <div className="analysis-item-label">Skin Tone</div>
          <div 
            className="color-swatch" 
            style={{ backgroundColor: result.skin_hex || '#D4A574' }}
          />
          <div className="analysis-item-value">{result.skin_hex}</div>
          <div className="analysis-item-detail">
            Monk: {result.monk_shade}
          </div>
          <div className="analysis-item-detail">
            Fitz: {getFitzpatrickLabel(result.fitzpatrick)}
          </div>
        </div>

        {/* Lip Color */}
        <div className="analysis-item">
          <div className="analysis-item-label">Lip Color</div>
          <div 
            className="color-swatch" 
            style={{ backgroundColor: result.lip_hex || '#B56B72' }}
          />
          <div className="analysis-item-value">{result.lip_hex}</div>
          <div className="analysis-item-detail">
            {result.makeup_detected ? 'With Makeup' : 'Natural'}
          </div>
        </div>

        {/* Undertone */}
        <div className="analysis-item">
          <div className="analysis-item-label">Undertone</div>
          <div style={{ fontSize: '32px', margin: '8px 0' }}>
            {getUndertoneIcon(result.undertone)}
          </div>
          <div className="analysis-item-value" style={{ textTransform: 'capitalize' }}>
            {result.undertone || 'Unknown'}
          </div>
        </div>
      </div>

      {/* Makeup Detection Warning */}
      {result.makeup_detected && (
        <div className="analysis-warning">
          ⚠️ Makeup detected - showing estimated natural colors
        </div>
      )}

      {/* Customer Match */}
      {result.customer_match && (
        <div style={{ 
          marginTop: '16px', 
          padding: '12px', 
          background: '#e8f5e9', 
          borderRadius: '8px' 
        }}>
          <div style={{ fontWeight: 600, marginBottom: '4px' }}>
            👋 Welcome back, {result.customer_match.first_name}!
          </div>
          <div style={{ fontSize: '13px', color: '#666' }}>
            {result.customer_match.loyalty_tier} member • {result.customer_match.points_balance.toLocaleString()} points
          </div>
        </div>
      )}
    </div>
  );
}

