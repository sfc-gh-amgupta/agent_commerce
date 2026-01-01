// =============================================================================
// Agent Commerce - Chat Widget Component
// =============================================================================

import { useState, useRef, useEffect } from 'react';
import { Message, WidgetConfig, AnalysisResult, DEFAULT_CONFIG } from '../types';
import { sendMessage, fileToBase64 } from '../services/api';
import { AnalysisCard } from './AnalysisCard';
import { ProductCard } from './ProductCard';
import '../styles/widget.css';

interface ChatWidgetProps {
  config?: WidgetConfig;
  onClose?: () => void;
}

export function ChatWidget({ config = DEFAULT_CONFIG, onClose }: ChatWidgetProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [sessionId, setSessionId] = useState<string | null>(null);
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
    root.style.setProperty('--widget-width', config.widget.width);
    root.style.setProperty('--widget-height', config.widget.height);
  }, [config]);

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

      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response.response,
        timestamp: new Date(),
        metadata: {
          toolsUsed: response.tools_used,
          analysisResult: response.analysis_result,
          products: response.products,
          cartUpdate: response.cart_update,
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

      const response = await sendMessage({
        message: 'Analyze this photo and tell me about my skin tone',
        image_base64: base64,
        session_id: sessionId || undefined,
      });

      if (response.session_id) {
        setSessionId(response.session_id);
      }

      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response.response,
        timestamp: new Date(),
        metadata: {
          toolsUsed: response.tools_used,
          analysisResult: response.analysis_result,
          products: response.products,
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

  return (
    <div className={`widget-container ${config.widget.position === 'bottom-left' ? 'left' : ''}`}>
      {/* Header */}
      <div className="widget-header">
        {config.logo_url && (
          <img src={config.logo_url} alt="Logo" className="widget-header-logo" />
        )}
        <div className="widget-header-info">
          <h3 className="widget-header-title">{config.tagline}</h3>
          <p className="widget-header-subtitle">by {config.retailer_name}</p>
        </div>
        <button className="widget-close-btn" onClick={onClose}>
          ✕
        </button>
      </div>

      {/* Chat Area */}
      <div className="widget-chat" ref={chatRef}>
        {messages.map((message) => (
          <div key={message.id}>
            {/* User attached image */}
            {message.attachments?.map((attachment, idx) => (
              attachment.type === 'image' && (
                <div key={idx} className="message user" style={{ padding: '4px' }}>
                  <img 
                    src={attachment.url} 
                    alt="Uploaded" 
                    style={{ maxWidth: '150px', borderRadius: '12px' }}
                  />
                </div>
              )
            ))}
            
            {/* Message bubble */}
            <div className={`message ${message.role}`}>
              {message.content}
            </div>

            {/* Analysis Result Card */}
            {message.metadata?.analysisResult && (
              <AnalysisCard result={message.metadata.analysisResult} />
            )}

            {/* Product Cards */}
            {message.metadata?.products?.map((product, idx) => (
              <ProductCard key={idx} product={product} />
            ))}
          </div>
        ))}

        {/* Typing indicator */}
        {isLoading && (
          <div className="typing-indicator">
            <span></span>
            <span></span>
            <span></span>
          </div>
        )}
      </div>

      {/* Quick Actions */}
      <div className="widget-actions">
        <button 
          className="action-btn" 
          onClick={() => fileInputRef.current?.click()}
          disabled={isLoading}
        >
          📁 Upload Photo
        </button>
        <input
          type="file"
          ref={fileInputRef}
          accept="image/*"
          style={{ display: 'none' }}
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) handleImageUpload(file);
          }}
        />
      </div>

      {/* Input Area - ALWAYS VISIBLE */}
      <div className="widget-input">
        <textarea
          ref={inputRef}
          className="widget-input-field"
          placeholder="Type a message..."
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyPress={handleKeyPress}
          rows={1}
          disabled={isLoading}
        />
        <button 
          className="send-btn" 
          onClick={handleSend}
          disabled={!input.trim() || isLoading}
        >
          ➤
        </button>
      </div>
    </div>
  );
}

