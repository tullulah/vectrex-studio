import { BaseAiProvider } from './BaseAiProvider.js';
import type { AiRequest, AiResponse } from '../../types/aiProvider.js';

export class AnthropicProvider extends BaseAiProvider {
  public readonly name = 'Anthropic';
  private readonly defaultBaseUrl = 'https://api.anthropic.com/v1';

  public isConfigured(): boolean {
    return !!this.config.apiKey;
  }

  private get baseUrl(): string {
    return this.config.endpoint || this.defaultBaseUrl;
  }

  public async sendRequest(request: AiRequest): Promise<AiResponse> {
    if (!this.isConfigured()) {
      throw new Error('Anthropic API key not configured');
    }

    try {
      const systemPrompt = this.buildSystemPrompt(request.concise ?? false);
      const userPrompt = this.buildUserPrompt(request);

      // Get MCP tools if available
      const mcpTools = (window as any).mcpTools?.getTools?.() || [];
      const anthropicTools = mcpTools.map((tool: any) => ({
        name: tool.name.replace(/\//g, '_'), // editor/write_document → editor_write_document
        description: tool.description || 'No description',
        input_schema: tool.inputSchema || { type: 'object', properties: {} }
      }));

      // Use Electron proxy to bypass CORS
      const proxyResponse = await (window as any).aiProxy.request({
        provider: 'anthropic',
        apiKey: this.config.apiKey!,
        endpoint: '/v1/messages',
        method: 'POST',
        body: {
          model: this.config.model || 'claude-3-haiku-20240307',
          max_tokens: this.config.maxTokens || 8000,
          system: systemPrompt,
          messages: [
            { role: 'user', content: userPrompt }
          ],
          tools: anthropicTools.length > 0 ? anthropicTools : undefined
        }
      });

      if (!proxyResponse.success) {
        throw new Error(`Anthropic API error: ${proxyResponse.status} - ${proxyResponse.error || 'Unknown error'}`);
      }

      const response = {
        ok: true,
        json: async () => proxyResponse.data
      } as Response;

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(`Anthropic API error: ${response.status} ${response.statusText} - ${errorData.error?.message || 'Unknown error'}`);
      }

      const data = await response.json();
      const content = data.content?.[0]?.text || 'No response from Anthropic';
      const usage = data.usage;

      return {
        content,
        suggestions: this.extractSuggestions(content),
        usage: usage ? {
          promptTokens: usage.input_tokens || 0,
          completionTokens: usage.output_tokens || 0,
          totalTokens: (usage.input_tokens || 0) + (usage.output_tokens || 0)
        } : undefined
      };
    } catch (error) {
      return this.handleError(error, 'Anthropic');
    }
  }

  public async getModels(): Promise<string[]> {
    if (!this.isConfigured()) {
      return [];
    }

    try {
      // Use beta models API endpoint
      const proxyResponse = await (window as any).aiProxy.request({
        provider: 'anthropic',
        apiKey: this.config.apiKey!,
        endpoint: '/v1/models',
        method: 'GET',
        body: {},
        headers: {
          'anthropic-beta': 'models-2024-08-01'
        }
      });

      if (!proxyResponse.success) {
        throw new Error(`Failed to fetch models: ${proxyResponse.status}`);
      }

      const models = proxyResponse.data?.data
        ?.filter((model: any) => model.type === 'model')
        .map((model: any) => model.id)
        .sort((a: string, b: string) => {
          // Prioritize newer models
          if (a.includes('sonnet-4')) return -1;
          if (b.includes('sonnet-4')) return 1;
          if (a.includes('3-5')) return -1;
          if (b.includes('3-5')) return 1;
          return b.localeCompare(a); // Newer dates first
        }) || [];

      return models;
    } catch (error) {
      console.error('Failed to fetch Anthropic models:', error);
      throw error;
    }
  }

  public async testConnection(): Promise<boolean> {
    if (!this.isConfigured()) {
      return false;
    }

    try {
      // Use Electron proxy for test connection
      const proxyResponse = await (window as any).aiProxy.request({
        provider: 'anthropic',
        apiKey: this.config.apiKey!,
        endpoint: '/v1/messages',
        method: 'POST',
        body: {
          model: 'claude-3-haiku-20240307',
          max_tokens: 10,
          messages: [
            { role: 'user', content: 'test' }
          ]
        }
      });
      
      return proxyResponse.success;
    } catch {
      return false;
    }
  }
}