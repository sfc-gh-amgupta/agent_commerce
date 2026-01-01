// =============================================================================
// Agent Commerce - Product Card Component
// =============================================================================

import type { ProductMatch } from '../types';

interface ProductCardProps {
  product: ProductMatch;
  onAddToCart?: (product: ProductMatch) => void;
}

export function ProductCard({ product, onAddToCart }: ProductCardProps) {
  const getMatchQuality = (distance: number): { label: string; color: string } => {
    if (distance < 2) return { label: 'Perfect Match', color: '#28a745' };
    if (distance < 5) return { label: 'Great Match', color: '#5cb85c' };
    if (distance < 10) return { label: 'Good Match', color: '#f0ad4e' };
    return { label: 'Fair Match', color: '#999' };
  };

  const match = getMatchQuality(product.color_distance);
  const formattedPrice = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(product.price);

  return (
    <div className="product-card">
      {/* Color Swatch */}
      <div 
        className="product-swatch"
        style={{ backgroundColor: product.swatch_hex }}
      />

      {/* Product Info */}
      <div className="product-info">
        <div className="product-name">{product.name}</div>
        <div className="product-brand">{product.brand}</div>
        <div className="product-price">{formattedPrice}</div>
        <div className="product-match" style={{ color: match.color }}>
          ● {match.label}
        </div>
      </div>

      {/* Add to Cart Button */}
      <button 
        className="add-to-cart-btn"
        onClick={() => onAddToCart?.(product)}
      >
        Add
      </button>
    </div>
  );
}

