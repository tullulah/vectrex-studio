import { BaseAiProvider } from './BaseAiProvider.js';
import type { AiRequest, AiResponse } from '../../types/aiProvider.js';

export class GeminiProvider extends BaseAiProvider {
  public readonly name = 'Google Gemini';
  private readonly defaultBaseUrl = 'https://generativelanguage.googleapis.com/v1';

  public isConfigured(): boolean {
    return !!this.config.apiKey;
  }

  private get baseUrl(): string {
    return this.config.endpoint || this.defaultBaseUrl;
  }

  public async sendRequest(request: AiRequest): Promise<AiResponse> {
    if (!this.isConfigured()) {
      throw new Error('Gemini API key not configured');
    }

    try {
      const systemPrompt = this.buildSystemPrompt(request.concise ?? false);
      const userPrompt = this.buildUserPrompt(request);

      // Get first available model if none configured
      const model = this.config.model || (await this.getModels())[0];
      if (!model) {
        throw new Error('No Gemini models available');
      }
      
      const response = await fetch(`${this.baseUrl}/models/${model}:generateContent?key=${this.config.apiKey}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: `${systemPrompt}\n\n${userPrompt}`
            }]
          }],
          generationConfig: {
            temperature: this.config.temperature || 0.7,
            maxOutputTokens: this.config.maxTokens || 2000,
            topP: 0.95,
            topK: 40
          }
        })
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(`Gemini API error: ${response.status} ${response.statusText} - ${errorData.error?.message || 'Unknown error'}`);
      }

      const data = await response.json();
      const content = data.candidates?.[0]?.content?.parts?.[0]?.text || 'No response from Gemini';
      const usage = data.usageMetadata;

      return {
        content,
        suggestions: this.extractSuggestions(content),
        usage: usage ? {
          promptTokens: usage.promptTokenCount || 0,
          completionTokens: usage.candidatesTokenCount || 0,
          totalTokens: usage.totalTokenCount || 0
        } : undefined
      };
    } catch (error) {
      return this.handleError(error, 'Gemini');
    }
  }

  public async getModels(): Promise<string[]> {
    if (!this.isConfigured()) {
      return [];
    }

    const response = await fetch(`${this.baseUrl}/models?key=${this.config.apiKey}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch Gemini models: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    
    // Filter models that support generateContent
    const models = data.models
      ?.filter((model: any) => 
        model.supportedGenerationMethods?.includes('generateContent') &&
        model.name.startsWith('models/gemini')
      )
      .map((model: any) => model.name.replace('models/', ''))
      .sort((a: string, b: string) => {
        // Prioritize -latest versions and newer models
        if (a.includes('-latest') && !b.includes('-latest')) return -1;
        if (!a.includes('-latest') && b.includes('-latest')) return 1;
        if (a.includes('1.5') && !b.includes('1.5')) return -1;
        if (!a.includes('1.5') && b.includes('1.5')) return 1;
        return a.localeCompare(b);
      }) || [];

    return models;
  }

  public async testConnection(): Promise<boolean> {
    if (!this.isConfigured()) {
      return false;
    }

    try {
      const model = this.config.model || (await this.getModels())[0];
      if (!model) {
        console.error('No Gemini models available');
        return false;
      }

      const response = await fetch(`${this.baseUrl}/models/${model}:generateContent?key=${this.config.apiKey}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: 'Hello'
            }]
          }],
          generationConfig: {
            maxOutputTokens: 10
          }
        })
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        console.error('Gemini test connection failed:', {
          status: response.status,
          statusText: response.statusText,
          errorMessage: errorData.error?.message,
          errorDetails: errorData.error?.details,
          fullError: errorData
        });
      }

      return response.ok;
    } catch (error) {
      console.error('Gemini test connection error:', error);
      return false;
    }
  }
}
