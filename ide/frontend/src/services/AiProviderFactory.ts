import type { IAiProvider, AiProviderConfig, AiProviderType } from '../types/aiProvider.js';
import { MockProvider } from './providers/MockProvider.js';
import { DeepSeekProvider } from './providers/DeepSeekProvider.js';
import { OpenAiProvider } from './providers/OpenAiProvider.js';
import { AnthropicProvider } from './providers/AnthropicProvider.js';
import { GitHubModelsProvider } from './providers/GitHubModelsProvider.js';
import { GroqProvider } from './providers/GroqProvider.js';
import { OllamaProvider } from './providers/OllamaProvider.js';
import { GeminiProvider } from './providers/GeminiProvider.js';

export class AiProviderFactory {
  private static instances: Map<AiProviderType, IAiProvider> = new Map();

  /**
   * Creates or reuses an instance of the given provider
   */
  public static getProvider(type: AiProviderType, config?: AiProviderConfig): IAiProvider {
    // The Mock provider needs no configuration
    if (type === 'mock') {
      if (!this.instances.has('mock')) {
        this.instances.set('mock', new MockProvider());
      }
      return this.instances.get('mock')!;
    }

    // Other providers need a configuration
    if (!config) {
      throw new Error(`Configuration required for provider: ${type}`);
    }

    // Create a new instance whenever the config changes (in case the API key changed)
    const provider = this.createProvider(type, config);
    this.instances.set(type, provider);
    return provider;
  }

  /**
   * Creates a new provider instance
   */
  private static createProvider(type: AiProviderType, config: AiProviderConfig): IAiProvider {
    switch (type) {
      case 'mock':
        return new MockProvider();
      
      case 'deepseek':
        if (!config.apiKey) {
          throw new Error('DeepSeek API key is required');
        }
        return new DeepSeekProvider(config);
      
      case 'openai':
        if (!config.apiKey) {
          throw new Error('OpenAI API key is required');
        }
        return new OpenAiProvider(config);
      
      case 'anthropic':
        if (!config.apiKey) {
          throw new Error('Anthropic API key is required');
        }
        return new AnthropicProvider(config);
      
      case 'github':
        if (!config.apiKey) {
          throw new Error('GitHub Models API key is required');
        }
        return new GitHubModelsProvider(config);
      
      case 'groq':
        if (!config.apiKey) {
          throw new Error('Groq API key is required');
        }
        return new GroqProvider(config);
      
      case 'ollama':
        // Ollama doesn't require API key, just needs to be running locally
        return new OllamaProvider(config || {});
      
      case 'gemini':
        if (!config.apiKey) {
          throw new Error('Gemini API key is required');
        }
        return new GeminiProvider(config);
      
      default:
        throw new Error(`Unknown provider type: ${type}`);
    }
  }

  /**
   * Gets all the available provider types
   */
  public static getAvailableProviders(): Array<{
    type: AiProviderType;
    name: string;
    description: string;
    requiresApiKey: boolean;
    isConfigured: boolean;
  }> {
    const mockProvider = this.getProvider('mock');
    
    return [
      {
        type: 'mock',
        name: 'Mock Provider',
        description: 'Local simulator for testing - no API key required',
        requiresApiKey: false,
        isConfigured: mockProvider.isConfigured()
      },
      {
        type: 'deepseek',
        name: 'DeepSeek',
        description: 'Free DeepSeek API - fast and efficient',
        requiresApiKey: true,
        isConfigured: false // Will be checked when config is provided
      },
      {
        type: 'openai',
        name: 'OpenAI',
        description: 'GPT-4o and GPT-4o-mini - top quality',
        requiresApiKey: true,
        isConfigured: false
      },
      {
        type: 'anthropic',
        name: 'Anthropic Claude',
        description: 'Claude 3.5 Sonnet/Haiku - advanced reasoning',
        requiresApiKey: true,
        isConfigured: false
      },
      {
        type: 'github',
        name: 'GitHub Models',
        description: 'Models via GitHub Copilot/Models - GPT-4o, Claude, Llama',
        requiresApiKey: true,
        isConfigured: false
      },
      {
        type: 'groq',
        name: 'Groq',
        description: 'Free API with Llama 3 - ultra-fast inference',
        requiresApiKey: true,
        isConfigured: false
      },
      {
        type: 'ollama',
        name: 'Ollama (Local)',
        description: 'Local models on your Mac - 100% private, no API key',
        requiresApiKey: false,
        isConfigured: true // Always configured, just needs Ollama running
      },
      {
        type: 'gemini',
        name: 'Google Gemini',
        description: 'Gemini 1.5 Pro/Flash - advanced multimodal',
        requiresApiKey: true,
        isConfigured: false
      }
    ];
  }

  /**
   * Checks whether a provider is correctly configured
   */
  public static async isProviderConfigured(type: AiProviderType, config?: AiProviderConfig): Promise<boolean> {
    try {
      const provider = this.getProvider(type, config);
      return provider.isConfigured();
    } catch {
      return false;
    }
  }

  /**
   * Tests the connection to a provider
   */
  public static async testProviderConnection(type: AiProviderType, config?: AiProviderConfig): Promise<boolean> {
    try {
      const provider = this.getProvider(type, config);
      if (!provider.isConfigured() || !provider.testConnection) {
        return false;
      }
      return await provider.testConnection();
    } catch {
      return false;
    }
  }

  /**
   * Clears the instance cache (useful when configs change)
   */
  public static clearCache(): void {
    this.instances.clear();
  }

  /**
   * Gets information about the models available for a provider
   */
  public static async getProviderModels(type: AiProviderType, config?: AiProviderConfig): Promise<string[]> {
    try {
      console.log('🔄 AiProviderFactory.getProviderModels called for:', type, 'with config:', {
        hasApiKey: !!config?.apiKey,
        apiKeyLength: config?.apiKey?.length
      });
      
      const provider = this.getProvider(type, config);
      console.log('✅ Provider instance created:', provider.name);
      
      if (!provider.getModels) {
        console.warn('⚠️ Provider does not have getModels method');
        return [];
      }
      
      console.log('🚀 Calling provider.getModels()...');
      const models = await provider.getModels();
      console.log('✅ Models returned from provider:', models);
      
      return models;
    } catch (error) {
      console.error('❌ Error in getProviderModels:', error);
      return [];
    }
  }
}