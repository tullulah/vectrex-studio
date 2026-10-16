import { BaseAiProvider } from './BaseAiProvider.js';
import type { AiRequest, AiResponse } from '../../types/aiProvider.js';

export class GitHubModelsProvider extends BaseAiProvider {
  public readonly name = 'GitHub Models';
  private readonly defaultBaseUrl = 'https://api.github.com';

  public isConfigured(): boolean {
    return !!this.config.apiKey;
  }

  private get baseUrl(): string {
    return this.config.endpoint || this.defaultBaseUrl;
  }

  public async sendRequest(request: AiRequest): Promise<AiResponse> {
    if (!this.isConfigured()) {
      throw new Error('GitHub Models API key not configured');
    }

    try {
      const systemPrompt = this.buildSystemPrompt(request.concise ?? false);
      const userPrompt = this.buildUserPrompt(request);

      // Correct GitHub Models API endpoint
      const apiUrl = `${this.baseUrl}/models/chat/completions`;
      
      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': `Bearer ${this.config.apiKey}`,
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
          'User-Agent': 'PyPilot-VPy-IDE/1.0'
        },
        body: JSON.stringify({
          model: this.config.model || 'gpt-4o', // Available models: gpt-4o, gpt-4o-mini, etc.
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt }
          ],
          temperature: this.config.temperature || 0.7,
          max_tokens: this.config.maxTokens || 8000,
          stream: false
        })
      });

      if (!response.ok) {
        const errorText = await response.text();
        let errorMessage = `GitHub Models API error: ${response.status} ${response.statusText}`;
        
        if (response.status === 401) {
          errorMessage = `🔑 Authentication error (401): 
• Check that your API key is correct (it must start with 'ghp_' or 'ghs_')
• Make sure your account has access to GitHub Models
• The token needs 'repo' permissions and access to Models
• GitHub Models may be in a limited beta in your region

Technical details: ${errorText}`;
        } else if (response.status === 403) {
          errorMessage = `🚫 Access denied (403):
• GitHub Models may not be available for your account
• You need a GitHub Copilot subscription or enterprise access
• Check the access token's permissions

Details: ${errorText}`;
        } else if (response.status === 404) {
          errorMessage = `❓ Endpoint not found (404):
• GitHub Models may not be available yet
• Check that you have access to the Models beta
• Try another provider in the meantime

Details: ${errorText}`;
        } else {
          errorMessage += ` - ${errorText}`;
        }
        
        throw new Error(errorMessage);
      }

      const data = await response.json();
      const content = data.choices?.[0]?.message?.content || 'No response from GitHub Models';

      return {
        content,
        suggestions: this.extractSuggestions(content),
        usage: {
          promptTokens: data.usage?.prompt_tokens || 0,
          completionTokens: data.usage?.completion_tokens || 0,
          totalTokens: data.usage?.total_tokens || 0
        }
      };
    } catch (error) {
      throw error;
    }
  }

  public async getModels(): Promise<string[]> {
    if (!this.isConfigured()) {
      // Fallback models when no API key is configured
      return [
        'gpt-4o',
        'gpt-4o-mini', 
        'claude-3-5-sonnet',
        'llama-3.1-405b-instruct'
      ];
    }

    try {
      // Try to query the available models through the API
      const response = await fetch(`${this.baseUrl}/models`, {
        method: 'GET',
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': `Bearer ${this.config.apiKey}`,
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'PyPilot-VPy-IDE/1.0'
        }
      });

      if (response.ok) {
        const data = await response.json();
        // The GitHub Models API returns this format: { "data": [{ "id": "model-name", ... }] }
        if (data.data && Array.isArray(data.data)) {
          return data.data.map((model: any) => model.id).sort();
        }
      } else {
        console.warn(`GitHub Models API returned ${response.status} when fetching models`);
      }
    } catch (error) {
      console.warn('Failed to fetch models from GitHub API, using fallback list:', error);
    }

    // Expanded list of known models as a fallback (updated Oct 2024)
    return [
      'gpt-4o',
      'gpt-4o-mini',
      'gpt-4-turbo',
      'gpt-3.5-turbo',
      'gpt-5', // If available on your account
      'claude-3-5-sonnet',
      'claude-3-5-haiku', 
      'claude-3-opus',
      'claude-4-sonnet', // Claude Sonnet 4
      'llama-3.1-405b-instruct',
      'llama-3.1-70b-instruct',
      'llama-3.1-8b-instruct',
      'llama-3.2-90b-vision-instruct',
      'phi-3.5-mini-instruct',
      'cohere-command-r-plus'
    ].sort();
  }

  public async testConnection(): Promise<boolean> {
    if (!this.isConfigured()) {
      console.log('GitHubModelsProvider: No API key configured');
      return false;
    }

    console.log('GitHubModelsProvider: Testing connection...');
    console.log('GitHubModelsProvider: API Key starts with:', this.config.apiKey?.substring(0, 10) + '...');
    console.log('GitHubModelsProvider: Base URL:', this.baseUrl);

    try {
      const testUrl = `${this.baseUrl}/models/chat/completions`;
      console.log('GitHubModelsProvider: Testing URL:', testUrl);
      
      const response = await fetch(testUrl, {
        method: 'POST',
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': `Bearer ${this.config.apiKey}`,
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
          'User-Agent': 'PyPilot-VPy-IDE/1.0'
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini', // Use the cheapest model for the test
          messages: [
            { role: 'user', content: 'Hello' }
          ],
          max_tokens: 5
        })
      });

      console.log('GitHubModelsProvider: Response status:', response.status);
      console.log('GitHubModelsProvider: Response ok:', response.ok);
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error('GitHubModelsProvider: Error response:', errorText);
      }

      return response.ok;
    } catch (error) {
      console.error('GitHubModelsProvider: Connection test failed with exception:', error);
      return false;
    }
  }
}