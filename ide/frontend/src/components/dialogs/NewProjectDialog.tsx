/**
 * NewProjectDialog - Visual Studio 2022-style project creation dialog
 * 
 * Allows users to select project type (Game or Library) and configure
 * the project name and location.
 */

import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import './NewProjectDialog.css';

interface ProjectTemplate {
  id: string;
  name: string;
  description: string;
  icon: string;
  tags: string[];
  type: 'game' | 'library';
}

const PROJECT_TEMPLATES: ProjectTemplate[] = [
  {
    id: 'game',
    name: 'Vectrex Game',
    description: 'Create a new Vectrex game project with main loop structure and basic graphics setup.',
    icon: '🎮',
    tags: ['VPy', 'Game', 'Vectrex'],
    type: 'game',
  },
  {
    id: 'library',
    name: 'VPy Library',
    description: 'Create a reusable library package that can be shared across multiple projects.',
    icon: '📚',
    tags: ['VPy', 'Library', 'Module'],
    type: 'library',
  },
];

/** Project language: a VPy project (.vpyproj) or a C project on the SDK's libvpy runtime (.cvproj). */
export type ProjectKind = 'vpy' | 'c';

interface NewProjectDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onCreate: (options: { name: string; location: string; template: string; type: 'game' | 'library'; kind: ProjectKind }) => void;
  defaultLocation?: string;
}

export const NewProjectDialog: React.FC<NewProjectDialogProps> = ({
  isOpen,
  onClose,
  onCreate,
  defaultLocation = '',
}) => {
  const { t } = useTranslation();
  const [selectedTemplate, setSelectedTemplate] = useState<string>('game');
  const [kind, setKind] = useState<ProjectKind>('vpy');
  const [projectName, setProjectName] = useState('');
  const [location, setLocation] = useState(defaultLocation);
  const [searchFilter, setSearchFilter] = useState('');
  const [nameError, setNameError] = useState('');

  // Reset state when dialog opens
  useEffect(() => {
    if (isOpen) {
      setSelectedTemplate('game');
      setKind('vpy');
      setProjectName('');
      setLocation(defaultLocation);
      setSearchFilter('');
      setNameError('');
    }
  }, [isOpen, defaultLocation]);

  // Validate project name
  const validateName = useCallback((name: string): string => {
    if (!name.trim()) {
      return t('dialog.newProject.errorEmpty', 'Project name is required');
    }
    if (!/^[a-zA-Z][a-zA-Z0-9_-]*$/.test(name)) {
      return t('dialog.newProject.errorInvalid', 'Name must start with a letter and contain only letters, numbers, hyphens, and underscores');
    }
    if (name.length > 50) {
      return t('dialog.newProject.errorTooLong', 'Name is too long (max 50 characters)');
    }
    return '';
  }, [t]);

  const handleNameChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const name = e.target.value;
    setProjectName(name);
    setNameError(name ? validateName(name) : '');
  };

  const handleBrowseLocation = async () => {
    try {
      // Use Electron's file API exposed via preload
      const filesAPI = (window as any).files;
      if (filesAPI?.openFolder) {
        const result = await filesAPI.openFolder();
        if (result && typeof result === 'object' && 'path' in result) {
          setLocation(result.path);
        }
      } else {
        console.warn('Folder dialog not available in this environment');
      }
    } catch (error) {
      console.error('Failed to open folder dialog:', error);
    }
  };

  const handleCreate = () => {
    const error = validateName(projectName);
    if (error) {
      setNameError(error);
      return;
    }

    const template = PROJECT_TEMPLATES.find(t => t.id === selectedTemplate);
    if (!template) return;

    onCreate({
      name: projectName,
      location: location,
      template: selectedTemplate,
      type: template.type,
      kind,
    });
    onClose();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      onClose();
    } else if (e.key === 'Enter' && projectName && !nameError) {
      handleCreate();
    }
  };

  // Filter templates based on search
  const filteredTemplates = PROJECT_TEMPLATES.filter(template => {
    if (!searchFilter) return true;
    const search = searchFilter.toLowerCase();
    return (
      template.name.toLowerCase().includes(search) ||
      template.description.toLowerCase().includes(search) ||
      template.tags.some(tag => tag.toLowerCase().includes(search))
    );
  });

  if (!isOpen) return null;

  return (
    <div className="new-project-overlay" onClick={onClose} onKeyDown={handleKeyDown}>
      <div className="new-project-dialog" onClick={(e) => e.stopPropagation()}>
        <div className="new-project-header">
          <h2>{t('dialog.newProject.title', 'Create a new project')}</h2>
          <p>{t('dialog.newProject.subtitle', 'Choose a project template to get started')}</p>
        </div>

        <div className="new-project-search">
          <input
            type="text"
            placeholder={t('dialog.newProject.searchPlaceholder', 'Search for templates (e.g., "game", "library")...')}
            value={searchFilter}
            onChange={(e) => setSearchFilter(e.target.value)}
            autoFocus
          />
        </div>

        <div className="new-project-templates">
          {filteredTemplates.map((template) => (
            <div
              key={template.id}
              className={`project-template ${selectedTemplate === template.id ? 'selected' : ''}`}
              onClick={() => setSelectedTemplate(template.id)}
            >
              <div className="project-template-icon">{template.icon}</div>
              <div className="project-template-info">
                <h3 className="project-template-name">{template.name}</h3>
                <p className="project-template-desc">{template.description}</p>
                <div className="project-template-tags">
                  {template.tags.map((tag) => (
                    <span key={tag} className="project-template-tag">{tag}</span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="new-project-config">
          <div className="config-row">
            <label>{t('dialog.newProject.language', 'Language')}</label>
            <div className="config-kind" role="radiogroup">
              {(['vpy', 'c'] as ProjectKind[]).map((k) => (
                <button
                  key={k}
                  type="button"
                  role="radio"
                  aria-checked={kind === k}
                  className={`config-kind-option ${kind === k ? 'selected' : ''}`}
                  onClick={() => setKind(k)}
                >
                  {k === 'vpy' ? t('dialog.newProject.languageVpy', 'VPy') : t('dialog.newProject.languageC', 'C (SDK)')}
                </button>
              ))}
            </div>
          </div>
          <div className="config-kind-hint">
            {kind === 'vpy'
              ? t('dialog.newProject.languageVpyHint', 'Python-like VPy: builds for the original cartridge (6809) and the ARM targets.')
              : t('dialog.newProject.languageCHint', 'C on the SDK (uvmc2-sdk, libvpy runtime): runs in the simulator and builds for the RP2350 cartridge and the UVMC2 multicart.')}
          </div>

          <div className="config-row">
            <label>{t('dialog.newProject.name', 'Project name')}</label>
            <input
              type="text"
              value={projectName}
              onChange={handleNameChange}
              placeholder={t('dialog.newProject.namePlaceholder', 'MyVectrexGame')}
              className={nameError ? 'error' : ''}
            />
          </div>
          {nameError && <div className="error-message">{nameError}</div>}

          <div className="config-row">
            <label>{t('dialog.newProject.location', 'Location')}</label>
            <div className="config-location">
              <input
                type="text"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                placeholder={t('dialog.newProject.locationPlaceholder', '/path/to/projects')}
              />
              <button onClick={handleBrowseLocation}>
                {t('dialog.newProject.browse', 'Browse...')}
              </button>
            </div>
          </div>
        </div>

        <div className="new-project-footer">
          <button className="new-project-btn new-project-btn-secondary" onClick={onClose}>
            {t('dialog.newProject.cancel', 'Cancel')}
          </button>
          <button
            className="new-project-btn new-project-btn-primary"
            onClick={handleCreate}
            disabled={!projectName || !!nameError}
          >
            {t('dialog.newProject.create', 'Create')}
          </button>
        </div>
      </div>
    </div>
  );
};

export default NewProjectDialog;
