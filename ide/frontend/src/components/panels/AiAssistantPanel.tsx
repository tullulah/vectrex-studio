import React, { useState, useRef, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useEditorStore } from '../../state/editorStore';
import { useProjectStore } from '../../state/projectStore';
import type { AiMessage } from '../../types/ai';
import type { AiProviderType, AiProviderConfig } from '../../types/aiProvider';
import { aiService } from '../../services/aiService';
import { logger } from '../../utils/logger';
import { mcpTools } from '../../services/mcpToolsService';
import { OllamaManagerDialog } from '../dialogs/OllamaManagerDialog';
import { SessionManager } from '../SessionManager';
import { usePyPilotSession } from '../../hooks/usePyPilotSession';

// Base de conocimiento de comandos Vectrex
const VECTREX_COMMANDS = [
  {
    name: 'MOVE',
    syntax: 'MOVE(x, y)',
    description: 'Mueve el haz electrónico a coordenadas absolutas',
    example: 'MOVE(0, 0)  # Mueve al centro de la pantalla',
    category: 'movement'
  },
  {
    name: 'DRAW_LINE',
    syntax: 'DRAW_LINE(dx, dy)',
    description: 'Dibuja una línea desde la posición actual',
    example: 'DRAW_LINE(50, 50)  # Línea diagonal',
    category: 'drawing'
  },
  {
    name: 'INTENSITY',
    syntax: 'INTENSITY(value)',
    description: 'Establece la intensidad del haz (0-255)',
    example: 'INTENSITY(255)  # Máxima intensidad',
    category: 'intensity'
  },
  {
    name: 'PRINT_TEXT',
    syntax: 'PRINT_TEXT(x, y, text)',
    description: 'Muestra texto en pantalla usando la fuente del Vectrex',
    example: 'PRINT_TEXT(-50, 60, "HELLO WORLD")',
    category: 'text'
  },
  {
    name: 'ORIGIN',
    syntax: 'ORIGIN()',
    description: 'Resetea la posición de referencia al centro (0,0)',
    example: 'ORIGIN()  # Reset al centro',
    category: 'control'
  }
];

export const AiAssistantPanel: React.FC = () => {
  const { t } = useTranslation();
  
  // Get current project path from Zustand store
  const vpyProject = useProjectStore(s => s.vpyProject);
  const selected = useProjectStore(s => s.selected);
  const projectPath = vpyProject?.projectFile || selected || '';
  
  // Use PyPilot session hook for message management
  const {
    currentSessionId,
    messages,
    isLoading: sessionLoading,
    addMessage: addSessionMessage,
    clearMessages: clearSessionMessages,
    switchSession,
    createNewSession
  } = usePyPilotSession(projectPath);
  const [inputValue, setInputValue] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [conciseMode, setConciseMode] = useState(() => {
    const saved = localStorage.getItem('pypilot_concise');
    return saved === 'true';
  });
  
  // Load persisted settings
  const [currentProviderType, setCurrentProviderType] = useState<AiProviderType>(() => {
    const saved = localStorage.getItem('pypilot_provider');
    return (saved as AiProviderType) || 'mock';
  });
  
  const [providerConfig, setProviderConfig] = useState<AiProviderConfig>(() => {
    const saved = localStorage.getItem(`pypilot_config_${currentProviderType}`);
    return saved ? JSON.parse(saved) : {};
  });
  
  const [showSettings, setShowSettings] = useState(false);
  const [manualContext, setManualContext] = useState<string>('');
  const [availableModels, setAvailableModels] = useState<string[]>([]);
  const [isLoadingModels, setIsLoadingModels] = useState(false);
  const [mcpEnabled, setMcpEnabled] = useState(false);
  const [showOllamaManager, setShowOllamaManager] = useState(false);
  
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const initializedRef = useRef(false); // Track if welcome message was shown
  const activeDocument = useEditorStore(s => s.active);
  const documents = useEditorStore(s => s.documents);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Persist settings
  useEffect(() => {
    localStorage.setItem('pypilot_provider', currentProviderType);
  }, [currentProviderType]);

  // Load provider-specific config when provider changes
  useEffect(() => {
    const saved = localStorage.getItem(`pypilot_config_${currentProviderType}`);
    const loadedConfig = saved ? JSON.parse(saved) : {};
    console.log('📂 Loading config for provider:', currentProviderType, loadedConfig);
    setProviderConfig(loadedConfig);
  }, [currentProviderType]);

  // Persist provider-specific config
  useEffect(() => {
    localStorage.setItem(`pypilot_config_${currentProviderType}`, JSON.stringify(providerConfig));
  }, [providerConfig, currentProviderType]);

  // Note: Conversation history is now persisted in database via usePyPilotSession hook
  // No need for localStorage persistence

  // Persist concise mode
  useEffect(() => {
    localStorage.setItem('pypilot_concise', conciseMode.toString());
  }, [conciseMode]);

  // Sync provider with AI service
  useEffect(() => {
    console.log('Syncing provider:', currentProviderType, 'with config:', providerConfig);
    aiService.switchProvider(currentProviderType, providerConfig);
  }, [currentProviderType, providerConfig]);

  // Load available models when provider or config changes
  useEffect(() => {
    const loadModels = async () => {
      console.log('🔄 Loading models for provider:', currentProviderType, 'with config:', {
        hasApiKey: !!providerConfig.apiKey,
        apiKeyLength: providerConfig.apiKey?.length
      });
      
      if (currentProviderType === 'mock') {
        setAvailableModels([]);
        return;
      }

      setIsLoadingModels(true);
      try {
        const models = await aiService.getProviderModels(currentProviderType, providerConfig);
        console.log('✅ Models loaded:', models);
        setAvailableModels(models);
        
        // Set default model if none selected
        if (!providerConfig.model && models.length > 0) {
          const defaultModel = getDefaultModelForProvider(currentProviderType, models);
          console.log('🎯 Setting default model:', defaultModel);
          setProviderConfig(prev => ({ ...prev, model: defaultModel }));
        }
      } catch (error) {
        console.error('❌ Failed to load models:', error);
        logger.error('AI', 'Failed to load models:', error);
        setAvailableModels([]);
      } finally {
        setIsLoadingModels(false);
      }
    };

    loadModels();
  }, [currentProviderType, providerConfig.apiKey, providerConfig.endpoint]);

  // Helper function to get default model for each provider
  // Uses heuristics to pick the best model based on naming patterns
  const getDefaultModelForProvider = (type: AiProviderType, models: string[]): string => {
    if (models.length === 0) return '';
    
    // For Ollama: prioritize by parameter count (72b > 32b > 14b > 7b)
    // and by family (qwen2.5 > llama3.1 > others)
    if (type === 'ollama') {
      // Priority patterns (in order of preference)
      const patterns = [
        /qwen.*72b/i,      // qwen2.5:72b
        /llama.*70b/i,     // llama3.1:70b
        /qwen.*32b/i,      // qwen2.5:32b
        /qwen.*14b/i,      // qwen2.5:14b
        /deepseek.*16b/i,  // deepseek-coder-v2:16b
        /qwen.*7b/i,       // qwen2.5:7b
      ];
      
      for (const pattern of patterns) {
        const match = models.find(m => pattern.test(m));
        if (match) return match;
      }
      
      // Fallback: pick first model
      return models[0];
    }
    
    // For other providers: use hardcoded preferences (these are stable API names)
    const defaults: Record<AiProviderType, string[]> = {
      'mock': [],
      'ollama': [], // Handled above with dynamic patterns
      'github': ['gpt-4o', 'claude-3-5-sonnet', 'gpt-4o-mini'],
      'openai': ['gpt-4o', 'gpt-4o-mini'],
      'anthropic': ['claude-sonnet-4-20250514', 'claude-3-5-sonnet-20241022'],
      'deepseek': ['deepseek-chat', 'deepseek-coder'],
      'groq': ['llama-3.1-70b-versatile', 'llama-3.1-8b-instant', 'mixtral-8x7b-32768'],
      'gemini': []
    };

    const preferred = defaults[type] || [];
    for (const pref of preferred) {
      if (models.includes(pref)) return pref;
    }
    
    return models[0] || '';
  };

  // Get current editor context
  const getCurrentContext = () => {
    const context: any = { language: 'vpy' };
    
    if (!activeDocument) return context;
    
    const doc = documents.find(d => d.uri === activeDocument);
    if (!doc) return context;

    // Extract filename from URI or diskPath
    const fileName = doc.diskPath ? 
      doc.diskPath.split(/[/\\]/).pop() || doc.uri :
      doc.uri;
    
    context.fileName = fileName;
    
    // Get selected text if any (mock for now)
    // TODO: Integrate with Monaco editor to get real selection
    const selectedCode = ''; // Will be empty until Monaco integration
    if (selectedCode) {
      context.selectedCode = selectedCode;
    }
    
    // Auto-attach document content as context (always enabled)
    if (doc.content) {
      context.documentContent = doc.content;
      context.documentLength = doc.content.length;
    }
    
    // Add manual context if provided
    if (manualContext.trim()) {
      context.manualContext = manualContext.trim();
    }
    
    return context;
  };

  // Get context preview for display
  const getContextPreview = () => {
    const context = getCurrentContext();
    const items = [];

    if (context.fileName) {
      items.push(`📄 ${context.fileName}`);
    }

    if (context.selectedCode) {
      items.push(`✂️ ${t('ai.context.selection', 'Selection')} (${context.selectedCode.length} chars)`);
    }

    if (context.manualContext) {
      items.push(`📎 ${t('ai.context.manual', 'Manual context')} (${context.manualContext.length} chars)`);
    }

    return items.length > 0 ? items.join(' • ') : t('ai.context.noContext', 'No context');
  };

  // Initialize MCP tools on mount
  useEffect(() => {
    console.log('[PyPilot] Initializing MCP tools...');
    mcpTools.initialize()
    
      .then(() => {
        console.log('[PyPilot] MCP initialize completed');
        const available = mcpTools.isAvailable();
        console.log('[PyPilot] MCP isAvailable:', available);
        if (available) {
          const tools = mcpTools.getAvailableTools();
          console.log('[PyPilot] Available tools:', tools.length, tools);
          setMcpEnabled(true);
          console.log('[PyPilot] ✅ MCP ENABLED - mcpEnabled state set to true');
        } else {
          console.warn('[PyPilot] ⚠️ MCP not available - mcpEnabled remains false');
        }
      })
      .catch(err => {
        console.error('[PyPilot] ❌ MCP initialization failed:', err);
      });
  }, []);

  // Add system message on first load ONLY (not on every remount)
  useEffect(() => {
    if (messages.length === 0 && !initializedRef.current) {
      initializedRef.current = true; // Mark as initialized
      const mcpStatus = mcpEnabled ?
        `\n\n${t('ai.welcome.mcpEnabled', '🔧 **MCP Tools Enabled** - I can control the IDE directly')}` : '';

      const welcomeMsg = `${t('ai.welcome.title', '🤖 **PyPilot** activated')}

${t('ai.welcome.intro', 'I\'m your specialized assistant for **Vectrex VPy development**. I can help you with:')}

• ${t('ai.welcome.generateCode', '🔧 **Generate VPy code** - Describe what you want to create')}
• ${t('ai.welcome.analyzeErrors', '🐛 **Analyze errors** - Explain problems in your code')}
• ${t('ai.welcome.explainSyntax', '📚 **Explain syntax** - Learn VPy/Vectrex commands')}
• ${t('ai.welcome.optimizeCode', '⚡ **Optimize code** - Improve performance and readability')}
• ${t('ai.welcome.gameIdeas', '🎮 **Game ideas** - Suggest mechanics for Vectrex')}${mcpEnabled ? '\n• ' + t('ai.welcome.controlIde', '🎛️ **Control IDE** - Open/close projects, create files, etc.') : ''}

${t('ai.welcome.commands', '**Quick commands:**')}
${t('ai.welcome.explain', '`/explain` - Explain selected code')}
${t('ai.welcome.fix', '`/fix` - Suggest fixes for errors')}
${t('ai.welcome.generate', '`/generate` - Generate code from description')}
${t('ai.welcome.optimize', '`/optimize` - Optimize selected code')}
${t('ai.welcome.help', '`/help` - See all commands')}${mcpStatus}

${t('ai.welcome.question', 'How can I help you today?')}`;

      addMessage('system', welcomeMsg);
    }
  }, [mcpEnabled, messages.length]); // Only run when mcpEnabled changes OR when messages length changes from 0

  const addMessage = async (role: AiMessage['role'], content: string, context?: AiMessage['context']) => {
    // Save message to database via session hook
    await addSessionMessage(role, content);
    logger.debug('AI', 'Message added to session:', { role, contentLength: content.length });
  };

  // Function to parse markdown and render code blocks properly
  const renderMarkdown = (content: string) => {
    const parts = content.split(/(```[\s\S]*?```)/);
    
    return parts.map((part, index) => {
      if (part.startsWith('```') && part.endsWith('```')) {
        // This is a code block
        const codeContent = part.slice(3, -3).trim();
        const lines = codeContent.split('\n');
        const language = lines[0].trim();
        const code = language && !language.includes(' ') && lines.length > 1 
          ? lines.slice(1).join('\n') 
          : codeContent;
        
        return (
          <div key={index} style={{
            margin: '8px 0',
            border: '1px solid #3c4043',
            borderRadius: '6px',
            overflow: 'hidden'
          }}>
            {language && !language.includes(' ') && (
              <div style={{
                backgroundColor: '#2d2d30',
                padding: '4px 8px',
                fontSize: '11px',
                color: '#969696',
                borderBottom: '1px solid #3c4043'
              }}>
                {language}
              </div>
            )}
            <pre style={{
              margin: 0,
              padding: '12px',
              backgroundColor: '#1e1e1e',
              color: '#d4d4d4',
              fontSize: '13px',
              lineHeight: '1.4',
              fontFamily: 'Consolas, Monaco, "Courier New", monospace',
              overflow: 'auto'
            }}>
              <code>{code}</code>
            </pre>
          </div>
        );
      } else {
        // Regular text - process inline code with single backticks
        const textParts = part.split(/(`[^`]+`)/);
        return (
          <span key={index}>
            {textParts.map((textPart, textIndex) => {
              if (textPart.startsWith('`') && textPart.endsWith('`')) {
                return (
                  <code key={textIndex} style={{
                    backgroundColor: '#2d2d30',
                    color: '#e6db74',
                    padding: '2px 4px',
                    borderRadius: '3px',
                    fontSize: '12px',
                    fontFamily: 'Consolas, Monaco, monospace'
                  }}>
                    {textPart.slice(1, -1)}
                  </code>
                );
              }
              return textPart;
            })}
          </span>
        );
      }
    });
  };

  const handleSendMessage = async () => {
    if (!inputValue.trim() || isLoading) return;
    
    const userMessage = inputValue.trim();
    const context = getCurrentContext();
    
    // Add user message
    addMessage('user', userMessage, context);
    setInputValue('');
    setIsLoading(true);

    try {
      // Check if it's a command
      if (userMessage.startsWith('/')) {
        await handleCommand(userMessage, context);
      } else {
        await sendToAI(userMessage, context);
      }
    } catch (error) {
      logger.error('AI', 'Failed to process message:', error);
      addMessage('assistant', `❌ Error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCommand = async (command: string, context: any) => {
    const [cmd, ...args] = command.split(' ');
    
    switch (cmd) {
      case '/help':
        const helpMsg = `${t('ai.help.title', '📋 **Available commands:**')}

• ${t('ai.help.explain', '`/explain` - Explain selected code')}
• ${t('ai.help.fix', '`/fix` - Suggest solution for errors')}
• ${t('ai.help.generate', '`/generate [description]` - Generate VPy code')}
• ${t('ai.help.optimize', '`/optimize` - Optimize selected code')}
• ${t('ai.help.vectrex', '`/vectrex [command]` - Info about Vectrex commands')}
• ${t('ai.help.assets', '`/assets` - Guide to using .vec and .vmus assets')}
• ${t('ai.help.examples', '`/examples` - See code examples')}
• ${t('ai.help.clear', '`/clear` - Clear conversation')}
• ${t('ai.help.settings', '`/settings` - Configure AI')}

${t('ai.help.examples_header', '**Usage examples:**')}
${t('ai.help.example1', '`/generate a bouncing ball at screen edges`')}
${t('ai.help.example2', '`/explain` (with code selected)')}
${t('ai.help.example3', '`/fix` (when there are errors in the panel)')}
${t('ai.help.example4', '`/assets` (to learn about vectors and music)')}`;
        addMessage('assistant', helpMsg);
        break;
        
      case '/clear':
        await clearSessionMessages();
        setTimeout(() => {
          addMessage('system', t('ai.clear.message', '🗑️ Conversation cleared. How can I help you?'));
        }, 100);
        break;
        
      case '/settings':
        setShowSettings(true);
        addMessage('assistant', t('ai.settings.opening', '⚙️ Opening AI settings...'));
        break;
        
      case '/generate':
        const description = args.join(' ');
        if (!description) {
          addMessage('assistant', t('ai.command.generate.usage', '❌ Usage: `/generate [description]`\n\nExample: `/generate a bouncing ball`'));
          return;
        }
        await generateCode(description, context);
        break;
        
      case '/explain':
        if (!context.selectedCode) {
          addMessage('assistant', t('ai.command.explain.noCode', '⚠️ Select code in the editor first, then use `/explain`'));
          return;
        }
        await explainCode(context.selectedCode, context);
        break;
        
      case '/fix':
        await suggestFix(context);
        break;
        
      case '/optimize':
        if (!context.selectedCode) {
          addMessage('assistant', t('ai.command.optimize.noCode', '⚠️ Select code in the editor first, then use `/optimize`'));
          return;
        }
        await optimizeCode(context.selectedCode, context);
        break;
        
      case '/vectrex':
        const vectrexCmd = args.join(' ');
        await getVectrexHelp(vectrexCmd);
        break;
        
      case '/examples':
        showCodeExamples();
        break;
        
      case '/assets':
        showAssetsHelp();
        break;
        
      default:
        addMessage('assistant', t('ai.error.unknownCommand', `❌ Unknown command: \`${cmd}\`\n\nUse \`/help\` to see available commands.`, { cmd }));
    }
  };

  const sendToAI = async (message: string, context: any) => {
    try {
      console.log('[PyPilot] sendToAI called - mcpEnabled:', mcpEnabled);
      
      // Add MCP tools to context if available
      const enhancedContext = mcpEnabled ? {
        ...context,
        errors: [], // TODO: Get real errors from editor
        mcpTools: mcpTools.getToolsContext()
      } : {
        ...context,
        errors: []
      };
      
      console.log('[PyPilot] Enhanced context has mcpTools:', !!enhancedContext.mcpTools);

      const response = await aiService.sendRequest({
        message,
        concise: conciseMode,
        context: enhancedContext
      });

      addMessage('assistant', response.content);
      
      // Check if response contains MCP tool calls
      if (mcpEnabled) {
        console.log('[PyPilot] Parsing response for MCP tool calls...');
        const toolCalls = mcpTools.parseToolCalls(response.content);
        console.log('[PyPilot] Found', toolCalls.length, 'tool calls:', toolCalls);
        
        if (toolCalls.length > 0) {
          // addMessage('system', `⚙️ Ejecutando ${toolCalls.length} herramienta(s) MCP...`);
          
          try {
            const results = await mcpTools.executeToolCalls(toolCalls);
            addMessage('system', results);
          } catch (error) {
            logger.error('AI', 'MCP tool execution error:', error);
            addMessage('system', `❌ Error ejecutando herramientas: ${error instanceof Error ? error.message : 'Unknown error'}`);
          }
        } else {
          console.log('[PyPilot] No tool calls detected in response');
        }
      }
      
      // Handle suggestions if any
      if (response.suggestions?.length) {
        logger.info('AI', 'Received suggestions:', response.suggestions.length);
      }
    } catch (error) {
      logger.error('AI', 'AI service error:', error);
      addMessage('assistant', `❌ Error al comunicar con IA: ${error instanceof Error ? error.message : 'Error desconocido'}`);
    }
  };

  const generateCode = async (description: string, context: any) => {
    try {
      const response = await aiService.sendRequest({
        message: `/generate ${description}`,
        concise: conciseMode,
        context: {
          ...context,
          errors: []
        },
        command: '/generate'
      });

      addMessage('assistant', response.content);
    } catch (error) {
      logger.error('AI', 'Generate code error:', error);
      addMessage('assistant', t('ai.error.generating', '❌ Error generating code: {{message}}', { message: error instanceof Error ? error.message : t('ai.error.unknown', 'Unknown error') }));
    }
  };

  const explainCode = async (code: string, context: any) => {
    try {
      const response = await aiService.sendRequest({
        message: '/explain',
        concise: conciseMode,
        context: {
          ...context,
          selectedCode: code,
          errors: []
        },
        command: '/explain'
      });

      addMessage('assistant', response.content);
    } catch (error) {
      logger.error('AI', 'Explain code error:', error);
      addMessage('assistant', t('ai.error.explaining', '❌ Error explaining code: {{message}}', { message: error instanceof Error ? error.message : t('ai.error.unknown', 'Unknown error') }));
    }
  };

  const suggestFix = async (context: any) => {
    try {
      const response = await aiService.sendRequest({
        message: '/fix',
        context: {
          ...context,
          errors: [] // TODO: Get real errors from editor
        },
        command: '/fix'
      });

      addMessage('assistant', response.content);
    } catch (error) {
      logger.error('AI', 'Suggest fix error:', error);
      addMessage('assistant', `❌ Error sugiriendo correcciones: ${error instanceof Error ? error.message : 'Error desconocido'}`);
    }
  };

  const optimizeCode = async (code: string, context: any) => {
    try {
      const response = await aiService.sendRequest({
        message: '/optimize',
        context: {
          ...context,
          selectedCode: code,
          errors: []
        },
        command: '/optimize'
      });

      addMessage('assistant', response.content);
    } catch (error) {
      logger.error('AI', 'Optimize code error:', error);
      addMessage('assistant', t('ai.error.optimizing', '❌ Error optimizing code: {{message}}', { message: error instanceof Error ? error.message : t('ai.error.unknown', 'Unknown error') }));
    }
  };

  const getVectrexHelp = async (command: string) => {
    if (!command) {
      // Show all available commands
      const commands = VECTREX_COMMANDS;
      const commandsList = commands.map((cmd: any) => `• **${cmd.name}** - ${cmd.description}`).join('\n');
      
      addMessage('assistant', `📚 **Comandos Vectrex disponibles:**

${commandsList}

**Uso:** \`/vectrex [comando]\`
**Ejemplo:** \`/vectrex MOVE\`

💡 Los comandos Vectrex usan coordenadas de -127 a +127 con (0,0) en el centro.`);
      return;
    }

    const cmdInfo = VECTREX_COMMANDS.find(cmd => cmd.name.toUpperCase() === command.toUpperCase());
    
    if (cmdInfo) {
      addMessage('assistant', `📚 **Comando Vectrex: ${cmdInfo.name}**

**Sintaxis:** \`${cmdInfo.syntax}\`

**Descripción:** ${cmdInfo.description}

**Ejemplo:**
\`\`\`vpy
${cmdInfo.example}
\`\`\`

**Categoría:** ${cmdInfo.category}

💡 **Tip:** Los comandos de dibujo del Vectrex usan coordenadas relativas al centro de la pantalla (0,0).`);
    } else {
      const commands = VECTREX_COMMANDS;
      const commandNames = commands.map((cmd: any) => cmd.name).join(', ');
      
      addMessage('assistant', `❓ Comando "${command.toUpperCase()}" no encontrado.

**Comandos disponibles:**
${commandNames}

**Uso:** \`/vectrex [comando]\`
**Ejemplo:** \`/vectrex MOVE\``);
    }
  };

  const showCodeExamples = () => {
    addMessage('assistant', `${t('ai.examples.title', '📝 **VPy Code Examples:**')}

**1. Hola Mundo básico:**
\`\`\`vpy
def main():
    INTENSITY(255)
    PRINT_TEXT(-50, 0, "Hello Vectrex!")
\`\`\`

**2. Formas básicas:**
\`\`\`vpy
def main():
    INTENSITY(200)
    MOVE(-50, -50)
    RECT(0, 0, 100, 100)
    DRAW_CIRCLE(30)
\`\`\`

**3. Animación simple:**
\`\`\`vpy
var x = 0

def main():
    x = x + 1
    if x > 100:
        x = -100

    INTENSITY(255)
    MOVE(x, 0)
    DRAW_CIRCLE(10)
\`\`\`

${t('ai.examples.wantMore', 'Want to see examples of something specific?')}`);
  };

  const showAssetsHelp = () => {
    addMessage('assistant', `${t('ai.assets.title', '🎨 **Using Assets in VPy**')}

## 📁 Estructura de Proyecto

\`\`\`
proyecto/
├── src/
│   └── main.vpy          # Tu código
├── assets/
│   ├── vectors/          # Gráficos 3D (.vec)
│   ├── music/            # Música (.vmus)
│   ├── sfx/              # Efectos de sonido (.vmus)
│   ├── voices/           # Samples de voz
│   └── animations/       # Animaciones
└── build/                # ROMs compiladas
\`\`\`

## 🎨 Editor de Vectores 3D (.vec)

**Crear gráficos:**
1. Abre/crea archivo .vec en el IDE
2. Usa el ViewCube para navegar en 3D (estilo Fusion 360)
3. Dibuja vectores en el espacio 3D (-127 a +127)
4. Guarda y referencia en VPy

**Usar en código:**
\`\`\`vpy
def setup():
    # Cargar un gráfico vectorial
    nave = load_vec("assets/vectors/spaceship.vec")

def loop():
    INTENSITY(255)
    # Dibujar el gráfico en posición x=0, y=0
    draw_vec(nave, 0, 0, scale=1.0)
\`\`\`

## 🎵 Editor de Música (.vmus)

**Componer música:**
1. Crea archivo .vmus en el IDE
2. Piano roll: 3 canales cuadrados + 1 ruido
3. Coloca notas con el ratón
4. Preview en tiempo real con el PSG emulador
5. Exporta para tu juego

**Usar en código:**
\`\`\`vpy
def setup():
    # Cargar y reproducir música de fondo
    tema = load_music("assets/music/theme.vmus")
    play_music(tema, loop=True)
    
    # Cargar efectos de sonido
    explosion = load_sfx("assets/sfx/boom.vmus")

def on_collision():
    # Reproducir efecto
    play_sfx(explosion)
\`\`\`

## 🎮 Ejemplo Completo

\`\`\`vpy
# Cargar assets en setup
def setup():
    nave = load_vec("assets/vectors/player.vec")
    enemigo = load_vec("assets/vectors/enemy.vec")
    musica = load_music("assets/music/game.vmus")
    disparo = load_sfx("assets/sfx/shoot.vmus")
    
    play_music(musica, loop=True)

def loop():
    INTENSITY(255)
    
    # Dibujar nave del jugador
    draw_vec(nave, player_x, player_y, scale=1.0)
    
    # Dibujar enemigos
    draw_vec(enemigo, enemy_x, enemy_y, scale=0.8)
    
    if button_pressed(1):
        play_sfx(disparo)
\`\`\`

**Comandos relacionados:**
• \`/examples\` - Ver más ejemplos de código
• \`/vectrex\` - Info sobre hardware Vectrex
• \`/generate\` - Generar código con assets

💡 **Tip:** El editor 3D tiene ViewCube para rotar la cámara - click en caras/bordes para vistas preestablecidas!`);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  return (
    <div style={{ 
      height: '100%', 
      display: 'flex', 
      flexDirection: 'column',
      background: '#1e1e1e',
      color: '#cccccc'
    }}>
      {/* Header */}
      <div style={{ 
        padding: '12px 16px', 
        borderBottom: '1px solid #3c3c3c',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ fontSize: '16px' }}>🤖</span>
            <span style={{ fontWeight: '600' }}>PyPilot</span>
            <span style={{ 
              fontSize: '11px', 
              background: aiService.isConfigured() ? '#10b981' : '#6b7280',
              color: 'white',
              padding: '2px 6px',
              borderRadius: '10px'
            }}>
              {aiService.isConfigured() ? aiService.getCurrentProvider()?.name : 'Mock'}
            </span>
          </div>
          
          {/* Session Manager - only show if project is open */}
          {projectPath && (
            <SessionManager
              projectPath={projectPath}
              currentSessionId={currentSessionId}
              onSessionChange={switchSession}
              onNewSession={createNewSession}
            />
          )}
        </div>
        
        <div style={{ display: 'flex', gap: '8px' }}>
          {/* Concise Mode Toggle */}
          <button
            onClick={() => setConciseMode(!conciseMode)}
            title={conciseMode ? t('ai.tooltip.conciseOn', 'Concise mode enabled') : t('ai.tooltip.conciseOff', 'Concise mode disabled')}
            style={{
              background: conciseMode ? '#10b981' : 'transparent',
              border: '1px solid #3c3c3c',
              color: conciseMode ? 'white' : '#cccccc',
              padding: '4px 8px',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '12px'
            }}
          >
            {t('ai.ui.conciseButton', '⚡ Concise')}
          </button>

          {/* Clear History */}
          <button
            onClick={() => {
              if (confirm(t('ai.clearHistoryConfirm', 'Clear all conversation history for this session?'))) {
                clearSessionMessages();
              }
            }}
            title={t('ai.clearHistoryTooltip', 'Clear current session history')}
            style={{
              background: 'transparent',
              border: '1px solid #3c3c3c',
              color: '#cccccc',
              padding: '4px 8px',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '12px'
            }}
          >
            🗑️
          </button>

          {/* Settings */}
          <button
            onClick={() => setShowSettings(!showSettings)}
            style={{
              background: 'transparent',
              border: '1px solid #3c3c3c',
              color: '#cccccc',
              padding: '4px 8px',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '12px'
            }}
          >
            {t('ai.ui.settingsButton', '⚙️ Config')}
          </button>
        </div>
      </div>

      {/* Settings Panel */}
      {showSettings && (
        <div style={{ 
          padding: '12px', 
          borderBottom: '1px solid #3c3c3c',
          background: '#252526',
          maxWidth: '100%',
          boxSizing: 'border-box',
          overflow: 'hidden'
        }}>
          <div style={{ marginBottom: '12px', fontWeight: '600' }}>{t('ai.settings.title', '⚙️ AI Settings')}</div>
          
          <div style={{ 
            display: 'flex', 
            flexDirection: 'column', 
            gap: '8px',
            maxWidth: '100%',
            overflow: 'hidden'
          }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', marginBottom: '4px' }}>
              {t('ai.settings.provider', 'Provider:')}
            </label>
            <select 
              value={currentProviderType}
              onChange={(e) => {
                const newProvider = e.target.value as AiProviderType;
                console.log('Provider changed from', currentProviderType, 'to', newProvider);
                console.log('Current config before change:', providerConfig);
                setCurrentProviderType(newProvider);
              }}
              style={{
                background: '#1e1e1e',
                border: '1px solid #3c3c3c',
                color: '#cccccc',
                padding: '4px 8px',
                borderRadius: '4px',
                width: '100%',
                maxWidth: '100%',
                boxSizing: 'border-box',
                fontSize: '12px'
              }}
            >
              <option value="gemini">Google Gemini</option>
              <option value="anthropic">Anthropic Claude</option>
              <option value="openai">OpenAI GPT</option>
              <option value="groq">Groq (Free & Fast)</option>
              <option value="deepseek">DeepSeek (Free)</option>
              <option value="github">GitHub Models (Copilot)</option>
              <option value="ollama">{t('ai.ui.ollama', '🏠 Ollama (Local - Private)')}</option>
              <option value="mock">Mock (Testing)</option>
            </select>
          </div>

          {/* Info box removed - now handled in OllamaManagerDialog */}
          
          {currentProviderType !== 'mock' && currentProviderType !== 'ollama' && (
            <div style={{ marginBottom: '8px' }}>
              <label style={{ display: 'block', fontSize: '12px', marginBottom: '4px' }}>
                {t('ai.settings.apiKey', 'API Key:')}
              </label>
              <input
                type="password"
                value={providerConfig.apiKey || ''}
                onChange={(e) => {
                  const newApiKey = e.target.value;
                  console.log('🔑 API Key input changed:', {
                    newValue: newApiKey.substring(0, 10) + '...',
                    length: newApiKey.length,
                    currentProvider: currentProviderType
                  });
                  
                  setProviderConfig(prev => {
                    const newConfig = { ...prev, apiKey: newApiKey };
                    console.log('🔄 Setting new config:', {
                      ...newConfig,
                      apiKey: newConfig.apiKey?.substring(0, 10) + '...'
                    });
                    return newConfig;
                  });
                }}
                placeholder={currentProviderType === 'groq' ? 'gsk_...' : currentProviderType === 'github' ? 'github_pat_...' : 'sk-...'}
                style={{
                  background: '#1e1e1e',
                  border: '1px solid #3c3c3c',
                  color: '#cccccc',
                  padding: '6px 8px',
                  borderRadius: '4px',
                  width: '100%',
                  maxWidth: '100%',
                  fontSize: '12px',
                  fontFamily: 'monospace',
                  boxSizing: 'border-box',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis'
                }}
                onFocus={(e) => {
                  console.log('🔑 API Key field focused');
                  e.stopPropagation();
                }}
                onClick={(e) => {
                  console.log('🔑 API Key field clicked');
                  e.stopPropagation();
                  e.currentTarget.focus();
                }}
              />
            </div>
          )}
          
          {/* Model selector - shown for all providers except mock */}
          {currentProviderType !== 'mock' && availableModels.length > 0 && (
                <div style={{ marginBottom: '8px' }}>
                  <label style={{ display: 'block', fontSize: '12px', marginBottom: '4px' }}>
                    {t('ai.settings.model', 'Model:')}
                    {isLoadingModels && <span style={{ color: '#6b7280', marginLeft: '8px' }}>{t('ai.ui.loading', 'Loading...')}</span>}
                  </label>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'stretch' }}>
                    <select
                      value={providerConfig.model || ''}
                      onChange={(e) => setProviderConfig(prev => ({ ...prev, model: e.target.value }))}
                      disabled={isLoadingModels}
                      style={{
                        background: '#1e1e1e',
                        border: '1px solid #3c3c3c',
                        color: '#cccccc',
                        padding: '4px 8px',
                        borderRadius: '4px',
                        flex: 1,
                        opacity: isLoadingModels ? 0.6 : 1
                      }}
                    >
                      <option value="">{t('ai.ui.selectModel', 'Select model...')}</option>
                      {availableModels.map(model => (
                        <option key={model} value={model}>
                          {model}
                          {model.includes('gpt-5') && ` ${t('ai.badge.new', '⭐ (New)')}`}
                          {model.includes('claude-4') && ` ${t('ai.badge.new', '⭐ (New)')}`}
                          {model.includes('gpt-4o') && !model.includes('mini') && ` ${t('ai.badge.recommended', '🚀 (Recommended)')}`}
                          {model.includes('mini') && ` ${t('ai.badge.fast', '⚡ (Fast)')}`}
                          {model.includes('free') && ` ${t('ai.badge.free', '🆓 (Free)')}`}
                        </option>
                      ))}
                    </select>
                    
                    {currentProviderType === 'ollama' && (
                      <button
                        onClick={() => setShowOllamaManager(true)}
                        style={{
                          background: '#374151',
                          border: '1px solid #4b5563',
                          color: '#e5e7eb',
                          padding: '4px 12px',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '12px',
                          whiteSpace: 'nowrap'
                        }}
                        title="Manage Ollama models"
                      >
                        🏠 Manage
                      </button>
                    )}
                  </div>
                  
                  {providerConfig.model && (
                    <div style={{ 
                      fontSize: '10px', 
                      color: '#6b7280', 
                      marginTop: '4px',
                      fontStyle: 'italic'
                    }}>
                      {t('ai.settings.modelSelected', 'Model selected: {{model}}', { model: providerConfig.model })}
                    </div>
                  )}
                  
                  <button
                    onClick={async () => {
                      setIsLoadingModels(true);
                      try {
                        const models = await aiService.getProviderModels(currentProviderType, providerConfig);
                        setAvailableModels(models);
                      } catch (error) {
                        logger.error('AI', 'Failed to reload models:', error);
                      } finally {
                        setIsLoadingModels(false);
                      }
                    }}
                    disabled={isLoadingModels || (currentProviderType !== 'ollama' && !providerConfig.apiKey)}
                    style={{
                      background: 'transparent',
                      border: '1px solid #3c3c3c',
                      color: '#cccccc',
                      padding: '2px 8px',
                      borderRadius: '3px',
                      cursor: 'pointer',
                      fontSize: '10px',
                      marginTop: '4px',
                      opacity: isLoadingModels || (currentProviderType !== 'ollama' && !providerConfig.apiKey) ? 0.5 : 1
                    }}
                  >
                    {isLoadingModels ? t('ai.ui.loading', 'Loading...') : t('ai.ui.reloadModels', '🔄 Reload models')}
                  </button>
                </div>
              )}
          
          <div style={{ display: 'flex', gap: '8px', marginTop: '12px' }}>
            <button
              onClick={async () => {
                // Test connection for non-mock providers
                if (currentProviderType !== 'mock') {
                  console.log('Testing connection for provider:', currentProviderType);
                  console.log('Provider config:', {
                    hasApiKey: !!providerConfig.apiKey,
                    apiKeyStart: providerConfig.apiKey?.substring(0, 10) + '...',
                    model: providerConfig.model,
                    endpoint: providerConfig.endpoint
                  });
                  
                  try {
                    const isConnected = await aiService.testProviderConnection(currentProviderType, providerConfig);
                    console.log('Connection test result:', isConnected);
                    
                    if (!isConnected) {
                      const shouldSave = confirm(t('ai.settings.connectionFailed', '⚠️ Connection test failed for {{provider}}.\n\nPossible issues:\n• Check your API key is correct\n• Rate limit exceeded (wait a moment)\n• Service temporarily unavailable\n\nDo you want to save the configuration anyway?\nYou can try sending a message to test if it works.', { provider: currentProviderType }));

                      if (!shouldSave) {
                        return;
                      }
                    } else {
                      alert(t('ai.settings.connectionSuccess', '✅ Successfully connected to {{provider}}!', { provider: currentProviderType }));
                    }
                  } catch (error) {
                    console.error('Connection test error:', error);
                    const shouldSave = confirm(t('ai.settings.connectionError', '⚠️ Error testing connection: {{error}}\n\nDo you want to save the configuration anyway?', { error: error instanceof Error ? error.message : String(error) }));
                    
                    if (!shouldSave) {
                      return;
                    }
                  }
                }
                setShowSettings(false);
                logger.info('AI', 'AI provider configured:', currentProviderType);
              }}
              style={{
                background: '#0e639c',
                border: 'none',
                color: 'white',
                padding: '6px 12px',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '12px'
              }}
            >
              {t('ai.button.save', 'Save')}
            </button>
            <button
              onClick={() => setShowSettings(false)}
              style={{
                background: 'transparent',
                border: '1px solid #3c3c3c',
                color: '#cccccc',
                padding: '6px 12px',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '12px'
              }}
            >
              {t('ai.button.cancel', 'Cancel')}
            </button>
          </div>
          </div>
        </div>
      )}

      {/* Messages */}
      <div style={{ 
        flex: 1, 
        overflowY: 'auto', 
        padding: '16px',
        display: 'flex',
        flexDirection: 'column',
        gap: '12px'
      }}>
        {messages.map((message) => (
          <div
            key={message.id}
            style={{
              display: 'flex',
              flexDirection: message.role === 'user' ? 'row-reverse' : 'row',
              gap: '8px',
              alignItems: 'flex-start'
            }}
          >
            <div style={{
              width: '32px',
              height: '32px',
              borderRadius: '16px',
              background: message.role === 'user' ? '#0e639c' : 
                         message.role === 'system' ? '#10b981' : '#6b7280',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '14px',
              flexShrink: 0
            }}>
              {message.role === 'user' ? '👤' : message.role === 'system' ? '🤖' : '🤖'}
            </div>
            
            <div style={{
              background: message.role === 'user' ? '#0e639c20' : 
                         message.role === 'system' ? '#10b98120' : '#3c3c3c',
              padding: '8px 12px',
              borderRadius: '8px',
              maxWidth: '80%',
              fontSize: '13px',
              lineHeight: '1.4'
            }}>
              <div style={{ 
                whiteSpace: 'pre-wrap'
              }}>
                {renderMarkdown(message.content)}
              </div>
              
              {message.context && (
                <div style={{
                  fontSize: '11px',
                  color: '#969696',
                  marginTop: '6px',
                  fontStyle: 'italic'
                }}>
                  📁 {message.context.fileName}
                </div>
              )}
              
              <div style={{
                fontSize: '10px',
                color: '#6b7280',
                marginTop: '4px'
              }}>
                {message.timestamp.toLocaleTimeString()}
              </div>
            </div>
          </div>
        ))}
        
        {isLoading && (
          <div style={{
            display: 'flex',
            gap: '8px',
            alignItems: 'center',
            color: '#6b7280'
          }}>
            <div style={{
              width: '32px',
              height: '32px',
              borderRadius: '16px',
              background: '#6b7280',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              🤖
            </div>
            <div style={{
              background: '#3c3c3c',
              padding: '8px 12px',
              borderRadius: '8px',
              fontSize: '13px'
            }}>
              <span>{t('ai.ui.thinking', '🤔 Thinking...')}</span>
            </div>
          </div>
        )}
        
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div style={{ 
        padding: '16px', 
        borderTop: '1px solid #3c3c3c',
        background: '#252526'
      }}>
        {/* Context indicator */}
        <div style={{
          fontSize: '11px',
          color: '#6b7280',
          marginBottom: '8px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between'
        }}>
          <span>{t('ai.context.label', '📎 Context:')} {getContextPreview()}</span>
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <button
              onClick={() => {
                const context = prompt(t('ai.dialog.addContext', 'Add manual context:'), manualContext);
                if (context !== null) setManualContext(context);
              }}
              style={{
                background: 'transparent',
                border: '1px solid #3c3c3c',
                color: '#cccccc',
                padding: '2px 6px',
                borderRadius: '3px',
                fontSize: '10px',
                cursor: 'pointer'
              }}
            >
              {t('ai.ui.attach', '📎 Attach')}
            </button>
          </div>
        </div>
        
        <div style={{ display: 'flex', gap: '8px', alignItems: 'flex-end' }}>
          <textarea
            ref={inputRef}
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={t('ai.ui.inputPlaceholder', 'Ask something or use /help to see commands...')}
            style={{
              flex: 1,
              background: '#1e1e1e',
              border: '1px solid #3c3c3c',
              color: '#cccccc',
              padding: '12px 16px',
              borderRadius: '8px',
              resize: 'vertical',
              minHeight: '60px',
              maxHeight: '200px',
              fontSize: '14px',
              lineHeight: '1.5',
              fontFamily: 'ui-monospace, SFMono-Regular, "SF Mono", Monaco, Inconsolata, "Roboto Mono", monospace'
            }}
            rows={3}
          />
          
          <button
            onClick={handleSendMessage}
            disabled={!inputValue.trim() || isLoading}
            style={{
              background: inputValue.trim() && !isLoading ? '#0e639c' : '#3c3c3c',
              border: 'none',
              color: 'white',
              padding: '12px 16px',
              borderRadius: '8px',
              cursor: inputValue.trim() && !isLoading ? 'pointer' : 'not-allowed',
              fontSize: '14px',
              height: '60px',
              minWidth: '60px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            {isLoading ? '⏳' : '📤'}
          </button>
        </div>
        
        <div style={{
          fontSize: '11px',
          color: '#6b7280',
          marginTop: '8px'
        }}>
        </div>
      </div>
      
      {/* Ollama Manager Dialog */}
      <OllamaManagerDialog
        isOpen={showOllamaManager}
        onClose={() => setShowOllamaManager(false)}
        onModelSelected={(modelName) => {
          setProviderConfig(prev => ({ ...prev, model: modelName }));
        }}
        currentModel={providerConfig.model}
      />
    </div>
  );
};