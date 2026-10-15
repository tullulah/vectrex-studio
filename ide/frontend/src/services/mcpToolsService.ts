/**
 * MCP Tools Service for PyPilot
 * 
 * Provides PyPilot with access to MCP server tools to control the IDE
 */

import type { MCPRequest, MCPResponse } from '../../../electron/src/mcp/types';
import { ProjectContextPersistence } from './projectContextPersistence';

export interface MCPTool {
  name: string;
  description: string;
  inputSchema: {
    type: string;
    properties: Record<string, any>;
    required?: string[];
  };
}

export class MCPToolsService {
  private static instance: MCPToolsService;
  private tools: MCPTool[] = [];
  private isInitialized = false;

  private constructor() {}

  static getInstance(): MCPToolsService {
    if (!MCPToolsService.instance) {
      MCPToolsService.instance = new MCPToolsService();
    }
    return MCPToolsService.instance;
  }

  /**
   * Initialize MCP connection and fetch available tools
   */
  async initialize(): Promise<void> {
    console.log('[MCP Tools] initialize() called - isInitialized:', this.isInitialized);
    
    if (this.isInitialized) {
      console.log('[MCP Tools] Already initialized - skipping');
      return;
    }

    try {
      // Check if MCP is available
      console.log('[MCP Tools] Checking window.mcp availability...');
      console.log('[MCP Tools] window.mcp exists:', !!(window as any).mcp);
      
      if (!(window as any).mcp) {
        console.error('[MCP Tools] ❌ window.mcp NOT AVAILABLE - MCP server may not be running');
        return;
      }
      
      console.log('[MCP Tools] ✅ window.mcp is available');

      // Fetch available tools from MCP server
      const response: MCPResponse = await (window as any).mcp.request({
        jsonrpc: '2.0',
        id: 1,
        method: 'tools/list',
        params: {}
      });

      if (response.result && response.result.tools) {
        this.tools = response.result.tools;
        this.isInitialized = true;
        console.log(`[MCP Tools] Initialized with ${this.tools.length} tools`);
      }
    } catch (error) {
      console.error('[MCP Tools] Failed to initialize:', error);
    }
  }

  /**
   * Get list of available MCP tools
   */
  getAvailableTools(): MCPTool[] {
    return this.tools;
  }

  /**
   * Check if MCP is available and initialized
   */
  isAvailable(): boolean {
    return this.isInitialized && this.tools.length > 0;
  }

  /**
   * Call an MCP tool
   */
  async callTool(name: string, args: Record<string, any> = {}): Promise<any> {
    if (!(window as any).mcp) {
      throw new Error('MCP not available');
    }

    try {
      // Normalize tool name: convert all slashes to underscores
      // editor/read/document → editor_read_document
      // project/create/vector → project_create_vector
      const normalizedName = name.replace(/\//g, '_');
      console.log('[MCP Tools] Calling tool:', name, '→', normalizedName, 'with args:', args);
      
      // Call the tool by its normalized name
      const response: MCPResponse = await (window as any).mcp.request({
        jsonrpc: '2.0',
        id: Date.now(),
        method: normalizedName,  // Normalized tool name
        params: args    // Arguments directly as params
      });

      console.log('[MCP Tools] Tool response:', response);

      if (response.error) {
        console.error('[MCP Tools] Tool error:', response.error);
        throw new Error(response.error.message);
      }

      return response.result;
    } catch (error) {
      console.error(`[MCP Tools] Failed to call ${name}:`, error);
      throw error;
    }
  }

  /**
   * Get formatted tool descriptions for LLM context
   */
  getToolsContext(): string {
    if (!this.isAvailable()) {
      return '';
    }

    return `
## Available IDE Tools (via MCP):

You have access to the following tools to control the VPy IDE:

${this.tools.map(tool => `
### ${tool.name}
${tool.description}

**Parameters:**
${JSON.stringify(tool.inputSchema.properties, null, 2)}
${tool.inputSchema.required ? `**Required:** ${tool.inputSchema.required.join(', ')}` : ''}
`).join('\n')}

## How to Use Tools:

To use a tool, respond with a JSON function call in a code block:

\`\`\`json
{
  "tool": "editor/list_documents",
  "arguments": {}
}
\`\`\`

### Common Tools Examples:

**List documents:**
\`\`\`json
{"tool": "editor/list_documents", "arguments": {}}
\`\`\`

**Close project:**
\`\`\`json
{"tool": "project/close", "arguments": {}}
\`\`\`

**Open project:**
\`\`\`json
{"tool": "project/open", "arguments": {"projectPath": "/path/to/project.vpyproj"}}
\`\`\`

### File Editing Tools:

**To replace text in a file:**
\`\`\`json
{
  "tool": "editor/replace_range",
  "arguments": {
    "uri": "file:///path/to/file.vpy",
    "startLine": 10,
    "startColumn": 1,
    "endLine": 15,
    "endColumn": 20,
    "newText": "def new_function():\\n    pass"
  }
}
\`\`\`

**To insert text:**
\`\`\`json
{
  "tool": "editor/insert_at",
  "arguments": {
    "uri": "file:///path/to/file.vpy",
    "line": 5,
    "column": 1,
    "text": "# New comment\\n"
  }
}
\`\`\`

**To delete text:**
\`\`\`json
{
  "tool": "editor/delete_range",
  "arguments": {
    "uri": "file:///path/to/file.vpy",
    "startLine": 10,
    "startColumn": 1,
    "endLine": 10,
    "endColumn": 50
  }
}
\`\`\`

**IMPORTANT:** Line and column numbers are 1-indexed (first line is 1, not 0).
`;
  }

  /**
   * Parse tool calls from LLM response
   * Supports multiple formats:
   * 1. {"tool": "...", "arguments": {}}
   * 2. {"tool_calls": [{"name": "...", "params": {}}]}
   * 3. {"tool_calls": [{"name": "...", "arguments": {}}]}
   */
  parseToolCalls(response: string): Array<{ tool: string; arguments: Record<string, any> }> {
    const calls: Array<{ tool: string; arguments: Record<string, any> }> = [];
    
    // Method 1: Look for JSON code blocks with backticks
    const jsonBlockRegex = /```json\s*\n([\s\S]*?)\n```/g;
    let match;

    while ((match = jsonBlockRegex.exec(response)) !== null) {
      try {
        const parsed = JSON.parse(match[1]);
        
        // Format 1: Direct tool call {"tool": "...", "arguments": {}}
        if (parsed.tool) {
          const toolName = parsed.tool.replace(/_/g, '/');
          calls.push({
            tool: toolName,
            arguments: parsed.arguments || {}
          });
        }
        // Format 2: Array format {"tool_calls": [{"name": "..."}]}
        else if (parsed.tool_calls && Array.isArray(parsed.tool_calls)) {
          for (const toolCall of parsed.tool_calls) {
            const toolName = (toolCall.name || toolCall.tool || '').replace(/_/g, '/');
            const args = toolCall.params || toolCall.arguments || {};
            if (toolName) {
              calls.push({ tool: toolName, arguments: args });
            }
          }
        }
      } catch (e) {
        console.warn('[MCP Tools] Failed to parse tool call from code block:', e);
      }
    }

    // Method 2: Look for JSON objects without code blocks (plain text)
    // Try to parse any JSON object in the response
    const jsonObjectRegex = /\{(?:[^{}]|\{[^{}]*\})*\}/g;
    
    while ((match = jsonObjectRegex.exec(response)) !== null) {
      try {
        const jsonStr = match[0].trim();
        const parsed = JSON.parse(jsonStr);
        
        // Format 1: Direct tool call
        if (parsed.tool) {
          const exists = calls.some(c => c.tool === parsed.tool && 
            JSON.stringify(c.arguments) === JSON.stringify(parsed.arguments));
          if (!exists) {
            const toolName = parsed.tool.replace(/_/g, '/');
            calls.push({
              tool: toolName,
              arguments: parsed.arguments || {}
            });
          }
        }
        // Format 2: Array format
        else if (parsed.tool_calls && Array.isArray(parsed.tool_calls)) {
          for (const toolCall of parsed.tool_calls) {
            const toolName = (toolCall.name || toolCall.tool || '').replace(/_/g, '/');
            const args = toolCall.params || toolCall.arguments || {};
            if (toolName) {
              const exists = calls.some(c => c.tool === toolName && 
                JSON.stringify(c.arguments) === JSON.stringify(args));
              if (!exists) {
                calls.push({ tool: toolName, arguments: args });
              }
            }
          }
        }
      } catch (e) {
        // Not valid JSON, skip
      }
    }

    console.log('[MCP Tools] Parsed', calls.length, 'tool calls from response');
    if (calls.length > 0) {
      console.log('[MCP Tools] Tool calls:', JSON.stringify(calls, null, 2));
    }
    return calls;
  }

  /**
   * Execute tool calls and format results
   */
  async executeToolCalls(calls: Array<{ tool: string; arguments: Record<string, any> }>): Promise<string> {
    const results: string[] = [];

    for (const call of calls) {
      try {
        console.log(`[MCP Tools] Executing ${call.tool}`, call.arguments);
        
        // Check if this is an editing operation
        const isEdit = call.tool.includes('replace') || call.tool.includes('insert') || call.tool.includes('delete');
        
        if (isEdit) {
          // Show what will be changed
          results.push(`🔧 **${call.tool}**\nApplying changes...`);
        }
        
        const result = await this.callTool(call.tool, call.arguments);
        
        // Extract text content from MCP response
        let resultText = '';
        if (result.content && Array.isArray(result.content)) {
          resultText = result.content
            .filter((item: any) => item.type === 'text')
            .map((item: any) => item.text)
            .join('\n');
        } else if (typeof result === 'object') {
          // For structured results, provide summary instead of full JSON
          if (result.uri) {
            resultText = `File: ${result.uri}`;
          } else if (result.documents) {
            resultText = `${result.documents.length} document(s)`;
          } else if (result.content) {
            const contentLength = result.content.length;
            resultText = `Content read (${contentLength} characters)`;
          } else {
            resultText = 'Completed';
          }
        }

        // Update project context for file/asset creation
        this.updateProjectContextForTool(call.tool, call.arguments);

        if (isEdit) {
          results.push(`✅ Changes applied successfully`);
        } else {
          // Only show tool name, not verbose results
          results.push(`✅ ${call.tool}: ${resultText}`);
        }
      } catch (error) {
        results.push(`❌ **${call.tool}**: ${error instanceof Error ? error.message : 'Failed'}`);
      }
    }

    return results.join('\n\n');
  }

  /**
   * Update project context based on tool execution
   */
  private updateProjectContextForTool(toolName: string, args: Record<string, any>): void {
    // Track file creation
    if (toolName === 'editor_write_document' && args.uri) {
      const fileName = args.uri.split('/').pop();
      if (fileName) {
        console.log('[MCP Tools] Tracking created file:', fileName);
        ProjectContextPersistence.addCreatedFile(fileName);
      }
    }

    // Track vector asset creation
    if (toolName === 'project_create_vector' && args.name) {
      console.log('[MCP Tools] Tracking created vector asset:', args.name);
      ProjectContextPersistence.addVectorAsset(args.name);
    }

    // Track music asset creation
    if (toolName === 'project_create_music' && args.name) {
      console.log('[MCP Tools] Tracking created music asset:', args.name);
      ProjectContextPersistence.addMusicAsset(args.name);
    }

    // Track project creation
    if (toolName === 'project_create' && args.name && args.path) {
      console.log('[MCP Tools] Tracking new project:', args.name);
      const context = ProjectContextPersistence.createProjectContext(args.name, args.path);
      ProjectContextPersistence.saveProjectContext(context);
    }
  }

  /**
   * Preview what an edit operation will do
   */
  async previewEdit(tool: string, args: Record<string, any>): Promise<string> {
    const { uri, startLine, endLine, startColumn, endColumn, newText, text } = args;
    
    let preview = `📝 **Change preview:**\n\n`;
    preview += `**File:** ${uri.split('/').pop()}\n`;
    
    if (tool.includes('replace')) {
      preview += `**Lines:** ${startLine}:${startColumn} → ${endLine}:${endColumn}\n`;
      preview += `**New text:**\n\`\`\`\n${newText}\n\`\`\``;
    } else if (tool.includes('insert')) {
      preview += `**Insert at:** Line ${args.line}, Column ${args.column}\n`;
      preview += `**Text:**\n\`\`\`\n${text}\n\`\`\``;
    } else if (tool.includes('delete')) {
      preview += `**Delete:** Lines ${startLine}:${startColumn} → ${endLine}:${endColumn}`;
    }
    
    return preview;
  }
}

export const mcpTools = MCPToolsService.getInstance();
