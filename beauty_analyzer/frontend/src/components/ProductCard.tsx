// =============================================================================
// Agent Commerce - Product Card Component
// =============================================================================

import type { ProductMatch } from '../types';

interface ProductCardProps {
  product: ProductMatch;
  onAddToCart?: (product: ProductMatch) => void;
}

export function ProductCard({ product, onAddToCart }: ProductCardProps) {
  // Guard against null/undefined product
  if (!product) return null;

  const getMatchQuality = (distance: number): { label: string; color: string } => {
    if (distance < 2) return { label: 'Perfect Match', color: '#10b981' };
    if (distance < 5) return { label: 'Great Match', color: '#22c55e' };
    if (distance < 10) return { label: 'Good Match', color: '#eab308' };
    return { label: 'Match', color: '#9ca3af' };
  };

  const match = getMatchQuality(product.color_distance || 0);
  const formattedPrice = product.price 
    ? new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(product.price)
    : '';
  
  // Null-safe product name
  const productName = product.name || 'Unknown Product';
  const productBrand = product.brand || '';
  const productCategory = product.category || '';

  return (
    <div className="product-card">
      {/* Product Image or Color Swatch */}
      <div className="product-image-container">
        {product.image_url ? (
          <img 
            src={product.image_url} 
            alt={productName}
            className="product-image"
            onError={(e) => {
              // Fallback to swatch color on image error
              (e.target as HTMLImageElement).style.display = 'none';
              (e.target as HTMLImageElement).nextElementSibling?.classList.remove('hidden');
            }}
          />
        ) : null}
        <div 
          className={`product-swatch ${product.image_url ? 'hidden' : ''}`}
          style={{ backgroundColor: product.swatch_hex || '#f0f0f0' }}
        />
        {/* Match Badge */}
        <div 
          className="match-badge"
          style={{ backgroundColor: match.color }}
        >
          {match.label}
        </div>
      </div>

      {/* Product Info */}
      <div className="product-info">
        {productBrand && <div className="product-brand">{productBrand}</div>}
        <div className="product-name" title={productName}>
          {productName.length > 40 ? productName.substring(0, 40) + '...' : productName}
        </div>
        {productCategory && <div className="product-category">{productCategory}</div>}
        {formattedPrice && <div className="product-price">{formattedPrice}</div>}
      </div>

      {/* Add to Cart Button */}
      <button 
        className="add-to-cart-btn"
        onClick={() => onAddToCart?.(product)}
      >
        + Add to Cart
      </button>
    </div>
  );
}

