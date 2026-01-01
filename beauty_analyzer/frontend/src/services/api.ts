// =============================================================================
// Agent Commerce - API Service
// =============================================================================

import { Message, AnalysisResult, WidgetConfig } from '../types';

const API_BASE = '/api';

// =============================================================================
// Chat API - Cortex Agent
// =============================================================================

export interface ChatRequest {
  message: string;
  image_base64?: string;
  session_id?: string;
  customer_id?: string;
}

export interface ChatResponse {
  response: string;
  session_id: string;
  tools_used?: string[];
  analysis_result?: AnalysisResult;
  products?: any[];
  cart_update?: any;
}

export async function sendMessage(request: ChatRequest): Promise<ChatResponse> {
  const response = await fetch(`${API_BASE}/chat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request),
  });

  if (!response.ok) {
    throw new Error(`Chat API error: ${response.status}`);
  }

  return response.json();
}

// =============================================================================
// Face Analysis API - Direct SPCS calls
// =============================================================================

export async function analyzeface(image_base64: string): Promise<AnalysisResult> {
  const response = await fetch(`${API_BASE}/analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ image_base64 }),
  });

  if (!response.ok) {
    throw new Error(`Analysis API error: ${response.status}`);
  }

  return response.json();
}

// =============================================================================
// Config API - Admin Panel
// =============================================================================

export async function getConfig(): Promise<WidgetConfig> {
  const response = await fetch(`${API_BASE}/config`);
  
  if (!response.ok) {
    throw new Error(`Config API error: ${response.status}`);
  }

  return response.json();
}

export async function updateConfig(config: Partial<WidgetConfig>): Promise<WidgetConfig> {
  const response = await fetch(`${API_BASE}/config`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(config),
  });

  if (!response.ok) {
    throw new Error(`Config update error: ${response.status}`);
  }

  return response.json();
}

export async function uploadLogo(file: File): Promise<{ url: string }> {
  const formData = new FormData();
  formData.append('logo', file);

  const response = await fetch(`${API_BASE}/config/logo`, {
    method: 'POST',
    body: formData,
  });

  if (!response.ok) {
    throw new Error(`Logo upload error: ${response.status}`);
  }

  return response.json();
}

// =============================================================================
// Health Check
// =============================================================================

export async function checkHealth(): Promise<{ status: string; version: string }> {
  const response = await fetch(`${API_BASE}/health`);
  
  if (!response.ok) {
    throw new Error(`Health check failed: ${response.status}`);
  }

  return response.json();
}

// =============================================================================
// Image Utilities
// =============================================================================

export function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      // Remove data URL prefix (e.g., "data:image/jpeg;base64,")
      const base64 = result.split(',')[1];
      resolve(base64);
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

export function dataURLToBase64(dataURL: string): string {
  return dataURL.split(',')[1];
}

