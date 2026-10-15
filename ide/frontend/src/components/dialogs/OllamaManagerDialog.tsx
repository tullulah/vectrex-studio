import React, { useState, useEffect } from 'react';
import { OllamaProvider, OllamaModelInfo } from '../../services/providers/OllamaProvider';

interface OllamaManagerDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onModelSelected: (modelName: string) => void;
  currentModel?: string;
}

interface InstalledModel {
  name: string;
  size: number;
  modified_at: string;
}

export const OllamaManagerDialog: React.FC<OllamaManagerDialogProps> = ({
  isOpen,
  onClose,
  onModelSelected,
  currentModel
}) => {
  const [isOllamaInstalled, setIsOllamaInstalled] = useState(false);
  const [installedModels, setInstalledModels] = useState<InstalledModel[]>([]);
  const [recommendedModels, setRecommendedModels] = useState<OllamaModelInfo[]>([]);
  const [downloadProgress, setDownloadProgress] = useState<{ [key: string]: number }>({});
  const [downloadingModel, setDownloadingModel] = useState<string | null>(null);
  const [isInstallingOllama, setIsInstallingOllama] = useState(false);
  const [ollamaInstallProgress, setOllamaInstallProgress] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (isOpen) {
      checkOllamaStatus();
    }
  }, [isOpen]);

  const checkOllamaStatus = async () => {
    setLoading(true);
    const provider = new OllamaProvider({ model: 'qwen2.5:7b' });
    
    // Check if Ollama is installed and running
    const isRunning = await provider.checkOllamaRunning();
    setIsOllamaInstalled(isRunning);

    if (isRunning) {
      // Get installed models
      const models = await fetchInstalledModels();
      setInstalledModels(models);
      
      // Get recommended models
      const recommended = await provider.getRecommendedModels();
      setRecommendedModels(recommended);
    }
    
    setLoading(false);
  };

  const fetchInstalledModels = async (): Promise<InstalledModel[]> => {
    try {
      const response = await fetch('http://localhost:11434/api/tags');
      if (!response.ok) return [];
      const data = await response.json();
      return data.models || [];
    } catch {
      return [];
    }
  };

  const installOllama = async () => {
    setIsInstallingOllama(true);
    setOllamaInstallProgress('Checking Homebrew...');

    try {
      // Check if Homebrew is installed
      const hasBrewResponse = await (window as any).electron.runCommand('which brew');
      
      if (!hasBrewResponse.success || !hasBrewResponse.output.trim()) {
        setOllamaInstallProgress('Installing Homebrew first...');
        const brewInstall = await (window as any).electron.runCommand(
          '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        );
        if (!brewInstall.success) {
          throw new Error('Failed to install Homebrew');
        }
      }

      setOllamaInstallProgress('Installing Ollama via Homebrew...');
      const installResponse = await (window as any).electron.runCommand('brew install ollama');
      
      if (!installResponse.success) {
        throw new Error('Failed to install Ollama');
      }

      setOllamaInstallProgress('Starting Ollama service...');
      await (window as any).electron.runCommand('brew services start ollama');

      // Wait a bit for service to start
      setOllamaInstallProgress('Waiting for service to start...');
      await new Promise(resolve => setTimeout(resolve, 3000));

      setOllamaInstallProgress('Ollama installed successfully! ✅');
      await checkOllamaStatus();
      
      setTimeout(() => {
        setIsInstallingOllama(false);
        setOllamaInstallProgress('');
      }, 2000);
    } catch (error) {
      console.error('Ollama installation failed:', error);
      setOllamaInstallProgress(`Installation failed: ${error}`);
      setTimeout(() => {
        setIsInstallingOllama(false);
        setOllamaInstallProgress('');
      }, 5000);
    }
  };

  const downloadModel = async (modelName: string) => {
    setDownloadingModel(modelName);
    setDownloadProgress({ ...downloadProgress, [modelName]: 0 });

    try {
      const provider = new OllamaProvider({ model: modelName });
      
      await provider.pullModel(modelName, (progress) => {
        setDownloadProgress(prev => ({ ...prev, [modelName]: progress }));
      });

      // Refresh installed models list
      const models = await fetchInstalledModels();
      setInstalledModels(models);
      
      setDownloadingModel(null);
      delete downloadProgress[modelName];
      
      // Auto-select the newly downloaded model
      onModelSelected(modelName);
    } catch (error) {
      console.error('Model download failed:', error);
      setDownloadingModel(null);
      alert(`Failed to download ${modelName}: ${error}`);
    }
  };

  const deleteModel = async (modelName: string) => {
    if (!confirm(`Delete model ${modelName}? This cannot be undone.`)) {
      return;
    }

    try {
      const response = await fetch('http://localhost:11434/api/delete', {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name: modelName })
      });

      if (!response.ok) {
        throw new Error(`Failed to delete model: ${response.statusText}`);
      }

      // Refresh installed models list
      const models = await fetchInstalledModels();
      setInstalledModels(models);
      
      // If deleted model was selected, clear selection
      if (currentModel === modelName) {
        onModelSelected('');
      }
    } catch (error) {
      console.error('Model deletion failed:', error);
      alert(`Failed to delete ${modelName}: ${error}`);
    }
  };

  const selectModel = (modelName: string) => {
    onModelSelected(modelName);
    onClose();
  };

  const formatSize = (bytes: number): string => {
    const gb = bytes / (1024 * 1024 * 1024);
    return `${gb.toFixed(1)} GB`;
  };

  const isModelInstalled = (modelName: string): boolean => {
    return installedModels.some(m => m.name === modelName);
  };

  if (!isOpen) return null;

  const dialogStyle: React.CSSProperties = {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    background: 'rgba(0,0,0,0.8)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 9999,
  };

  return (
    <div style={dialogStyle} onClick={onClose}>
      <div className="bg-gray-800 rounded-lg shadow-xl border border-gray-600 max-w-3xl w-full max-h-[80vh] overflow-hidden flex flex-col" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-700 flex items-center justify-between">
          <h2 className="text-xl font-bold text-white">
            🏠 Ollama Model Manager
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors text-2xl leading-none"
            title="Close"
          >
            ✕
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {loading ? (
            <div className="text-center text-gray-400 py-8">
              Loading Ollama status...
            </div>
          ) : !isOllamaInstalled ? (
            // Ollama not installed
            <div className="text-center py-8">
              <div className="text-6xl mb-4">🏠</div>
              <h3 className="text-xl font-bold text-white mb-2">Ollama Not Installed</h3>
              <p className="text-gray-400 mb-6">
                Ollama is required to run local AI models. Would you like to install it?
              </p>
              
              {isInstallingOllama ? (
                <div className="max-w-md mx-auto">
                  <div className="bg-gray-700 rounded-lg p-4">
                    <div className="text-sm text-white mb-2">{ollamaInstallProgress}</div>
                    <div className="w-full bg-gray-600 rounded-full h-2">
                      <div className="bg-blue-500 h-2 rounded-full animate-pulse" style={{ width: '100%' }} />
                    </div>
                  </div>
                </div>
              ) : (
                <button
                  onClick={installOllama}
                  className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors"
                >
                  Install Ollama via Homebrew
                </button>
              )}
            </div>
          ) : (
            // Ollama installed - show models
            <div className="space-y-6">
              {/* Installed Models */}
              {installedModels.length > 0 && (
                <div>
                  <h3 className="text-lg font-bold text-white mb-3">📦 Installed Models</h3>
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-700">
                          <th className="text-left py-2 px-3 text-sm font-semibold text-gray-300">Model</th>
                          <th className="text-right py-2 px-3 text-sm font-semibold text-gray-300">Size</th>
                          <th className="text-right py-2 px-3 text-sm font-semibold text-gray-300">Modified</th>
                          <th className="text-right py-2 px-3 text-sm font-semibold text-gray-300">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {installedModels.map(model => (
                          <tr
                            key={model.name}
                            className={`border-b border-gray-700 hover:bg-gray-750 ${
                              currentModel === model.name ? 'bg-blue-500 bg-opacity-10' : ''
                            }`}
                          >
                            <td className="py-3 px-3">
                              <span className="font-medium text-white">{model.name}</span>
                              {currentModel === model.name && (
                                <span className="ml-2 text-xs bg-blue-600 px-2 py-0.5 rounded font-medium">ACTIVE</span>
                              )}
                            </td>
                            <td className="py-3 px-3 text-sm text-gray-300 text-right">{formatSize(model.size)}</td>
                            <td className="py-3 px-3 text-sm text-gray-400 text-right">
                              {new Date(model.modified_at).toLocaleDateString()}
                            </td>
                            <td className="py-3 px-3 text-right">
                              <div className="flex gap-2 justify-end">
                                <button
                                  onClick={() => selectModel(model.name)}
                                  className={`px-3 py-1.5 rounded text-sm font-medium transition-colors ${
                                    currentModel === model.name
                                      ? 'bg-blue-600 text-white cursor-default'
                                      : 'bg-gray-700 hover:bg-gray-600 text-white'
                                  }`}
                                  disabled={currentModel === model.name}
                                >
                                  {currentModel === model.name ? '✓ Active' : 'Select'}
                                </button>
                                <button
                                  onClick={() => deleteModel(model.name)}
                                  className="px-2 py-1.5 bg-red-600 hover:bg-red-700 text-white rounded text-sm font-medium transition-colors"
                                  title="Delete model"
                                >
                                  🗑️
                                </button>
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* Recommended Models */}
              <div>
                <h3 className="text-lg font-bold text-white mb-3">⭐ Recommended Models</h3>
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-gray-700">
                        <th className="text-left py-2 px-3 text-sm font-semibold text-gray-300">Model</th>
                        <th className="text-left py-2 px-3 text-sm font-semibold text-gray-300">Description</th>
                        <th className="text-right py-2 px-3 text-sm font-semibold text-gray-300">Size</th>
                        <th className="text-right py-2 px-3 text-sm font-semibold text-gray-300">Parameters</th>
                        <th className="text-right py-2 px-3 text-sm font-semibold text-gray-300">Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {recommendedModels.map(model => {
                        const installed = isModelInstalled(model.name);
                        const isDownloading = downloadingModel === model.name;
                        const progress = downloadProgress[model.name] || 0;

                        return (
                          <tr key={model.name} className="border-b border-gray-700 hover:bg-gray-750">
                            <td className="py-3 px-3">
                              <div className="flex items-center gap-2">
                                <span className="font-medium text-white">{model.displayName}</span>
                                {model.recommended && (
                                  <span className="text-xs bg-blue-600 px-2 py-0.5 rounded font-medium">RECOMMENDED</span>
                                )}
                              </div>
                            </td>
                            <td className="py-3 px-3 text-sm text-gray-400">{model.description}</td>
                            <td className="py-3 px-3 text-sm text-gray-300 text-right">{model.size}</td>
                            <td className="py-3 px-3 text-sm text-gray-300 text-right">{model.parameters}</td>
                            <td className="py-3 px-3 text-right">
                              {installed ? (
                                <button
                                  onClick={() => selectModel(model.name)}
                                  className="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 text-white rounded text-sm font-medium transition-colors"
                                >
                                  Select
                                </button>
                              ) : isDownloading ? (
                                <div className="w-24 inline-block">
                                  <div className="text-xs text-gray-400 mb-1">{progress}%</div>
                                  <div className="w-full bg-gray-600 rounded-full h-1.5">
                                    <div
                                      className="bg-blue-500 h-1.5 rounded-full transition-all"
                                      style={{ width: `${progress}%` }}
                                    />
                                  </div>
                                </div>
                              ) : (
                                <button
                                  onClick={() => downloadModel(model.name)}
                                  className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded text-sm font-medium transition-colors"
                                >
                                  Download
                                </button>
                              )}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-gray-700 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
