// =============================================================================
// Agent Commerce - Chat Widget Component
// =============================================================================
// Features:
// - Maximize/minimize button for fullscreen mode
// - Visual rendering of face analysis results
// - Product cards with add-to-cart
// - Cart badge updates
// - Markdown rendering for agent responses
// =============================================================================

import { useState, useRef, useEffect } from 'react';
import type { Message, WidgetConfig, AnalysisResult } from '../types';
import { DEFAULT_CONFIG } from '../types';
import { sendMessage, fileToBase64, uploadImageToStage, submitFeedback } from '../services/api';
// AnalysisCard is replaced by inline face-analysis-card rendering
import { ProductCard } from './ProductCard';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import '../styles/widget.css';

interface ChatWidgetProps {
  config?: WidgetConfig;
  onClose?: () => void;
  onCartUpdate?: (count: number) => void;
}

export function ChatWidget({ config = DEFAULT_CONFIG, onClose, onCartUpdate }: ChatWidgetProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [isMaximized, setIsMaximized] = useState(false);
  const [cartCount, setCartCount] = useState(0);
  const [showThinking, setShowThinking] = useState<Record<string, boolean>>({});
  const [feedbackText, setFeedbackText] = useState<Record<string, string>>({});
  const [showFeedbackInput, setShowFeedbackInput] = useState<Record<string, boolean>>({});
  const chatRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Apply theme CSS variables
  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty('--widget-primary', config.theme.primary_color);
    root.style.setProperty('--widget-secondary', config.theme.secondary_color);
    root.style.setProperty('--widget-background', config.theme.background_color);
    root.style.setProperty('--widget-text', config.theme.text_color);
    root.style.setProperty('--widget-accent', config.theme.accent_color);
    root.style.setProperty('--widget-radius', config.theme.border_radius);
    root.style.setProperty('--widget-font', config.theme.font_family);
    root.style.setProperty('--widget-width', isMaximized ? '100vw' : config.widget.width);
    root.style.setProperty('--widget-height', isMaximized ? '100vh' : config.widget.height);
  }, [config, isMaximized]);

  // Initial welcome message
  useEffect(() => {
    if (messages.length === 0) {
      setMessages([
        {
          id: '1',
          role: 'assistant',
          content: config.messages.welcome,
          timestamp: new Date(),
        },
      ]);
    }
  }, []);

  // Auto-scroll to bottom
  useEffect(() => {
    if (chatRef.current) {
      chatRef.current.scrollTop = chatRef.current.scrollHeight;
    }
  }, [messages]);

  // Update cart count in parent
  useEffect(() => {
    if (onCartUpdate) {
      onCartUpdate(cartCount);
    }
  }, [cartCount, onCartUpdate]);

  // Parse cart update from response
  const handleCartUpdate = (response: any) => {
    if (response.cart_update) {
      const update = response.cart_update;
      if (update.action === 'add') {
        setCartCount(prev => prev + (update.quantity || 1));
      } else if (update.action === 'remove') {
        setCartCount(prev => Math.max(0, prev - 1));
      } else if (update.item_count !== undefined) {
        setCartCount(update.item_count);
      }
    }
    // Also check tool results for cart operations
    if (response.tool_results) {
      response.tool_results.forEach((result: any) => {
        if (result.name?.includes('ACP_') && result.content) {
          try {
            const content = typeof result.content === 'string' 
              ? JSON.parse(result.content) 
              : result.content;
            if (content.item_count !== undefined) {
              setCartCount(content.item_count);
            }
          } catch {}
        }
      });
    }
  };

  // Send message handler
  const handleSend = async () => {
    if (!input.trim() && !isLoading) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: input.trim(),
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    try {
      const response = await sendMessage({
        message: userMessage.content,
        session_id: sessionId || undefined,
      });

      if (response.session_id) {
        setSessionId(response.session_id);
      }

      handleCartUpdate(response);

      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response.response,
        timestamp: new Date(),
        metadata: {
          toolsUsed: response.tools_used,
          toolResults: response.tool_results,
          tables: response.tables,
          analysisResult: response.analysis_result,
          products: response.products,
          cartUpdate: response.cart_update,
          error: response.error,
          timing: response.timing,
          thinking: response.thinking,
          messageId: response.message_id,
        },
      };

      setMessages((prev) => [...prev, assistantMessage]);
    } catch (error) {
      console.error('Chat error:', error);
      setMessages((prev) => [
        ...prev,
        {
          id: (Date.now() + 1).toString(),
          role: 'assistant',
          content: "I'm sorry, I encountered an error. Please try again.",
          timestamp: new Date(),
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  // Handle image upload
  const handleImageUpload = async (file: File) => {
    try {
      const base64 = await fileToBase64(file);
      
      const userMessage: Message = {
        id: Date.now().toString(),
        role: 'user',
        content: '📷 Uploaded a photo for analysis',
        timestamp: new Date(),
        attachments: [{ type: 'image', url: URL.createObjectURL(file), base64 }],
      };

      setMessages((prev) => [...prev, userMessage]);
      setIsLoading(true);

      // Try to upload to Snowflake Stage first
      let imagePath: string | undefined;
      try {
        const uploadResult = await uploadImageToStage(file);
        if (uploadResult.success && uploadResult.stage_path) {
          imagePath = uploadResult.stage_path;
          console.log('✅ Image uploaded to stage:', imagePath);
        }
      } catch (uploadError) {
        console.log('Stage upload not available, using base64 fallback');
      }

      // Send to agent with stage path (preferred) or base64 (fallback)
      const response = await sendMessage({
        message: imagePath 
          ? `Analyze the face image at ${imagePath} and recommend products for me`
          : 'Analyze this photo and recommend products for me',
        image_base64: imagePath ? undefined : base64,
        session_id: sessionId || undefined,
      });

      if (response.session_id) {
        setSessionId(response.session_id);
      }

      handleCartUpdate(response);

      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response.response,
        timestamp: new Date(),
        metadata: {
          toolsUsed: response.tools_used,
          analysisResult: response.analysis_result,
          products: response.products,
          timing: response.timing,
          thinking: response.thinking,
          messageId: response.message_id,
        },
      };

      setMessages((prev) => [...prev, assistantMessage]);
    } catch (error) {
      console.error('Upload error:', error);
      setMessages((prev) => [
        ...prev,
        {
          id: (Date.now() + 1).toString(),
          role: 'assistant',
          content: "I couldn't analyze that image. Please try again with a clear photo of your face.",
          timestamp: new Date(),
        },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  // Handle key press
  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  // Render face analysis results
  const renderAnalysisResult = (result: AnalysisResult) => {
    if (!result || !result.success) return null;
    
    return (
      <div className="face-analysis-card">
        <div className="face-analysis-header">
          <span className="face-analysis-icon">✨</span>
          <span className="face-analysis-title">Your Skin Analysis</span>
        </div>
        <div className="face-analysis-content">
          {/* Color Swatches */}
          <div className="color-swatches">
            {result.skin_hex && (
              <div className="color-swatch">
                <div 
                  className="swatch-circle" 
                  style={{ backgroundColor: result.skin_hex }}
                />
                <div className="swatch-info">
                  <span className="swatch-label">Skin Tone</span>
                  <span className="swatch-value">{result.skin_hex}</span>
                </div>
              </div>
            )}
            {result.lip_hex && (
              <div className="color-swatch">
                <div 
                  className="swatch-circle" 
                  style={{ backgroundColor: result.lip_hex }}
                />
                <div className="swatch-info">
                  <span className="swatch-label">Lip Color</span>
                  <span className="swatch-value">{result.lip_hex}</span>
                </div>
              </div>
            )}
          </div>
          
          {/* Analysis Details */}
          <div className="analysis-details">
            {result.undertone && (
              <div className="analysis-item">
                <span className="analysis-label">Undertone</span>
                <span className={`analysis-badge undertone-${result.undertone}`}>
                  {result.undertone}
                </span>
              </div>
            )}
            {result.fitzpatrick && (
              <div className="analysis-item">
                <span className="analysis-label">Fitzpatrick</span>
                <span className="analysis-badge">Type {result.fitzpatrick}</span>
              </div>
            )}
            {result.monk_shade && (
              <div className="analysis-item">
                <span className="analysis-label">Monk Shade</span>
                <span className="analysis-badge">{result.monk_shade}/10</span>
              </div>
            )}
          </div>
          
          {/* Customer Identity Match */}
          {result.customer_match && (
            <div className="customer-match-card">
              <div className="customer-match-header">
                <span className="customer-match-icon">👋</span>
                <span className="customer-match-title">
                  Welcome back, {result.customer_match.first_name}!
                </span>
              </div>
              <div className="customer-match-details">
                <div className="customer-match-row">
                  <span className="customer-match-label">Loyalty Tier</span>
                  <span className={`loyalty-badge tier-${result.customer_match.loyalty_tier?.toLowerCase()}`}>
                    {result.customer_match.loyalty_tier || 'Member'}
                  </span>
                </div>
                {result.customer_match.points_balance !== undefined && result.customer_match.points_balance > 0 && (
                  <div className="customer-match-row">
                    <span className="customer-match-label">Points Balance</span>
                    <span className="points-badge">
                      🌟 {result.customer_match.points_balance.toLocaleString()} pts
                    </span>
                  </div>
                )}
                <div className="customer-match-row">
                  <span className="customer-match-label">Match Confidence</span>
                  <span className="confidence-badge">
                    {(result.customer_match.confidence * 100).toFixed(0)}%
                  </span>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    );
  };

  // Handle feedback submission
  const handleFeedback = async (messageId: string, rating: 'like' | 'dislike') => {
    if (!sessionId || !messageId) return;
    
    try {
      const text = feedbackText[messageId] || '';
      await submitFeedback({
        message_id: messageId,
        session_id: sessionId,
        rating,
        feedback_text: text || undefined,
      });
      
      // Update message with feedback
      setMessages(prev => prev.map(m => {
        if (m.metadata?.messageId === messageId) {
          return { ...m, metadata: { ...m.metadata, feedback: rating } };
        }
        return m;
      }));
      
      // Close feedback input
      setShowFeedbackInput(prev => ({ ...prev, [messageId]: false }));
      setFeedbackText(prev => ({ ...prev, [messageId]: '' }));
    } catch (error) {
      console.error('Feedback error:', error);
    }
  };

  // Render tools used badges
  const renderToolBadges = (tools: string[]) => {
    if (!tools || tools.length === 0) return null;
    
    const toolIcons: Record<string, string> = {
      'AnalyzeFace': '👤',
      'MatchProducts': '🎨',
      'ProductSearch': '🔍',
      'IdentifyCustomer': '👋',
      'ACP_CreateCart': '🛒',
      'ACP_AddItem': '➕',
      'ACP_GetCart': '📋',
      'ACP_Checkout': '💳',
    };
    
    return (
      <div className="tool-badges">
        {tools.map((tool, idx) => (
          <span key={idx} className="tool-badge">
            {toolIcons[tool] || '🔧'} {tool.replace('ACP_', '')}
          </span>
        ))}
      </div>
    );
  };

  return (
    <div className={`widget-container ${config.widget.position === 'bottom-left' ? 'left' : ''} ${isMaximized ? 'maximized' : ''}`}>
      {/* Header */}
      <div className="widget-header">
        {config.logo_url && (
          <img src={config.logo_url} alt="Logo" className="widget-header-logo" />
        )}
        <div className="widget-header-info">
          <h3 className="widget-header-title">{config.tagline}</h3>
          <p className="widget-header-subtitle">by {config.retailer_name}</p>
        </div>
        <div className="widget-header-actions">
          {/* Maximize/Minimize Button */}
          <button 
            className="widget-action-btn" 
            onClick={() => setIsMaximized(!isMaximized)}
            title={isMaximized ? 'Minimize' : 'Maximize'}
          >
            {isMaximized ? '⊖' : '⊕'}
          </button>
          <button className="widget-close-btn" onClick={onClose}>
            ✕
          </button>
        </div>
      </div>

      {/* Chat Area */}
      <div className="widget-chat" ref={chatRef}>
        {messages.map((message) => (
          <div key={message.id} className="message-wrapper">
            {/* User attached image */}
            {message.attachments?.map((attachment, idx) => (
              attachment.type === 'image' && (
                <div key={idx} className="message user image-message">
                  <img 
                    src={attachment.url} 
                    alt="Uploaded" 
                    className="uploaded-image"
                  />
                </div>
              )
            ))}
            
            {/* Message bubble */}
            <div className={`message ${message.role}`}>
              {message.role === 'assistant' ? (
                <ReactMarkdown 
                  remarkPlugins={[remarkGfm]}
                  components={{
                    table: ({ children }) => (
                      <table className="markdown-table">{children}</table>
                    ),
                    code: ({ children, className }) => {
                      const isInline = !className;
                      return isInline ? (
                        <code className="inline-code">{children}</code>
                      ) : (
                        <pre className="code-block"><code>{children}</code></pre>
                      );
                    },
                    a: ({ href, children }) => (
                      <a href={href} target="_blank" rel="noopener noreferrer" className="markdown-link">
                        {children}
                      </a>
                    ),
                  }}
                >
                  {message.content}
                </ReactMarkdown>
              ) : (
                message.content
              )}
            </div>
            
            {/* Tool badges */}
            {message.metadata?.toolsUsed && renderToolBadges(message.metadata.toolsUsed)}
            
            {/* Face Analysis Results */}
            {message.metadata?.analysisResult && renderAnalysisResult(message.metadata.analysisResult)}
            
            {/* Product Cards */}
            {message.metadata?.products && Array.isArray(message.metadata.products) && message.metadata.products.length > 0 && (
              <div className="product-grid">
                {message.metadata.products.slice(0, 4).filter(p => p && p.name).map((product, idx) => (
                  <ProductCard key={idx} product={product} />
                ))}
              </div>
            )}
            
            {/* Thinking Toggle (for assistant messages) */}
            {message.role === 'assistant' && message.metadata?.thinking && (
              <div className="thinking-section">
                <button 
                  className="thinking-toggle"
                  onClick={() => setShowThinking(prev => ({ ...prev, [message.id]: !prev[message.id] }))}
                >
                  🧠 {showThinking[message.id] ? 'Hide reasoning' : 'Show reasoning'}
                </button>
                {showThinking[message.id] && (
                  <div className="thinking-content">
                    {message.metadata.thinking}
                  </div>
                )}
              </div>
            )}
            
            {/* Timing & Feedback (for assistant messages) */}
            {message.role === 'assistant' && (
              <div className="message-footer">
                {/* Timing */}
                {message.metadata?.timing && (
                  <div className="timing-info">
                    <span title={`Preprocessing: ${message.metadata.timing.preprocessing_ms}ms, Agent: ${message.metadata.timing.agent_ms}ms`}>
                      ⏱️ {(message.metadata.timing.total_ms / 1000).toFixed(1)}s
                    </span>
                  </div>
                )}
                
                {/* Feedback Buttons */}
                {message.metadata?.messageId && !message.metadata?.feedback && (
                  <div className="feedback-buttons">
                    <button 
                      className="feedback-btn like"
                      onClick={() => handleFeedback(message.metadata!.messageId!, 'like')}
                      title="Helpful"
                    >
                      👍
                    </button>
                    <button 
                      className="feedback-btn dislike"
                      onClick={() => {
                        setShowFeedbackInput(prev => ({ ...prev, [message.metadata!.messageId!]: true }));
                      }}
                      title="Not helpful"
                    >
                      👎
                    </button>
                  </div>
                )}
                
                {/* Feedback Submitted */}
                {message.metadata?.feedback && (
                  <div className="feedback-submitted">
                    {message.metadata.feedback === 'like' ? '👍 Thanks!' : '👎 Thanks for feedback'}
                  </div>
                )}
              </div>
            )}
            
            {/* Feedback Text Input */}
            {message.metadata?.messageId && showFeedbackInput[message.metadata.messageId] && (
              <div className="feedback-input-container">
                <input
                  type="text"
                  className="feedback-input"
                  placeholder="What could be better?"
                  value={feedbackText[message.metadata.messageId] || ''}
                  onChange={(e) => setFeedbackText(prev => ({ ...prev, [message.metadata!.messageId!]: e.target.value }))}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      handleFeedback(message.metadata!.messageId!, 'dislike');
                    }
                  }}
                />
                <button 
                  className="feedback-submit-btn"
                  onClick={() => handleFeedback(message.metadata!.messageId!, 'dislike')}
                >
                  Submit
                </button>
              </div>
            )}
          </div>
        ))}
        
        {/* Loading indicator */}
        {isLoading && (
          <div className="message assistant">
            <div className="typing-indicator">
              <span></span>
              <span></span>
              <span></span>
            </div>
          </div>
        )}
      </div>

      {/* Input Area */}
      <div className="widget-input-area">
        <input
          type="file"
          ref={fileInputRef}
          accept="image/*"
          style={{ display: 'none' }}
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) handleImageUpload(file);
            e.target.value = '';
          }}
        />
        <button
          className="widget-upload-btn"
          onClick={() => fileInputRef.current?.click()}
          title="Upload photo"
        >
          📷
        </button>
        <textarea
          ref={inputRef}
          className="widget-input"
          placeholder={config.messages.placeholder}
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyPress}
          rows={1}
        />
        <button
          className="widget-send-btn"
          onClick={handleSend}
          disabled={isLoading || !input.trim()}
        >
          {isLoading ? '...' : '→'}
        </button>
      </div>
    </div>
  );
}
