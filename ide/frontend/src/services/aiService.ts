import { AiProviderFactory } from './AiProviderFactory.js';
import type { 
  IAiProvider, 
  AiProviderType, 
  AiProviderConfig, 
  AiRequest, 
  AiResponse 
} from '../types/aiProvider.js';
import { logger } from '../utils/logger.js';

export class AiService {
  private currentProvider: IAiProvider | null = null;
  private currentProviderType: AiProviderType = 'mock';
  private currentConfig: AiProviderConfig = {};

  constructor() {
    // Initialize with the Mock provider by default
    this.switchProvider('mock');
  }

  /**
   * Switches the active AI provider
   */
  public switchProvider(type: AiProviderType, config?: AiProviderConfig): void {
    try {
      this.currentProviderType = type;
      this.currentConfig = config || {};
      this.currentProvider = AiProviderFactory.getProvider(type, config);
      
      logger.info('AI', `Provider switched to: ${this.currentProvider.name}`);
    } catch (error) {
      logger.error('AI', 'Failed to switch AI provider:', error);
      // Fallback a Mock provider
      this.currentProviderType = 'mock';
      this.currentConfig = {};
      this.currentProvider = AiProviderFactory.getProvider('mock');
    }
  }

  /**
   * Gets the current provider
   */
  public getCurrentProvider(): IAiProvider | null {
    return this.currentProvider;
  }

  /**
   * Gets the current provider type
   */
  public getCurrentProviderType(): AiProviderType {
    return this.currentProviderType;
  }

  /**
   * Checks whether the current provider is configured
   */
  public isConfigured(): boolean {
    return this.currentProvider?.isConfigured() ?? false;
  }

  /**
   * Sends a request to the current AI provider
   */
  public async sendRequest(request: AiRequest): Promise<AiResponse> {
    if (!this.currentProvider) {
      throw new Error('No AI provider configured');
    }

    try {
      logger.debug('AI', 'Sending request:', {
        command: request.command,
        messageLength: request.message.length,
        hasContext: !!request.context.selectedCode || !!request.context.documentContent
      });

      const response = await this.currentProvider.sendRequest(request);
      
      logger.debug('AI', 'Response received:', {
        contentLength: response.content.length,
        hasSuggestions: !!response.suggestions?.length,
        hasUsage: !!response.usage
      });

      return response;
    } catch (error) {
      logger.error('AI', `AI request failed (${this.currentProvider.name}):`, error);
      
      // Return an error response
      return {
        content: `❌ Error processing the request with ${this.currentProvider.name}:\n\n${error instanceof Error ? error.message : String(error)}`,
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }

  /**
   * Gets the available providers
   */
  public getAvailableProviders() {
    return AiProviderFactory.getAvailableProviders();
  }

  /**
   * Tests the connection to a specific provider
   */
  public async testProviderConnection(type: AiProviderType, config?: AiProviderConfig): Promise<boolean> {
    try {
      return await AiProviderFactory.testProviderConnection(type, config);
    } catch (error) {
      logger.error('AI', `Connection test failed for ${type}:`, error);
      return false;
    }
  }

  /**
   * Gets the models available for a provider
   */
  public async getProviderModels(type: AiProviderType, config?: AiProviderConfig): Promise<string[]> {
    try {
      console.log('🎯 aiService.getProviderModels called for:', type, 'with config:', {
        hasApiKey: !!config?.apiKey,
        apiKeyLength: config?.apiKey?.length
      });
      
      const models = await AiProviderFactory.getProviderModels(type, config);
      console.log('📦 aiService received models:', models);
      
      return models;
    } catch (error) {
      console.error('❌ aiService.getProviderModels error:', error);
      logger.error('AI', `Failed to get models for ${type}:`, error);
      return [];
    }
  }

  /**
   * Configures the current provider
   */
  public configureCurrentProvider(config: AiProviderConfig): void {
    if (this.currentProvider) {
      this.currentProvider.configure(config);
      this.currentConfig = { ...this.currentConfig, ...config };
    }
  }

  /**
   * Gets the current provider's configuration
   */
  public getCurrentConfig(): AiProviderConfig {
    return this.currentConfig;
  }

  /**
   * Clears the provider cache (useful when configs change)
   */
  public clearProvidersCache(): void {
    AiProviderFactory.clearCache();
    // Recreate the current provider
    this.switchProvider(this.currentProviderType, this.currentConfig);
  }
}

// Singleton service instance
export const aiService = new AiService();