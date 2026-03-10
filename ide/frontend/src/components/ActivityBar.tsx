import React from 'react';
import { useTranslation } from 'react-i18next';
import './ActivityBar.css';

export type ActivityBarItem = 'files' | 'git' | 'playground' | 'eprom' | 'settings' | null;

interface ActivityBarProps {
  activeItem: ActivityBarItem;
  onItemClick: (item: ActivityBarItem) => void;
}

export const ActivityBar: React.FC<ActivityBarProps> = ({ activeItem, onItemClick }) => {
  const { t } = useTranslation(['common']);
  const handleClick = (item: ActivityBarItem) => {
    // Toggle: if clicking active item, collapse (set to null)
    onItemClick(activeItem === item ? null : item);
  };

  return (
    <div className="activity-bar">
      <div className="activity-bar-top">
        <button
          className={`activity-bar-item ${activeItem === 'files' ? 'active' : ''}`}
          onClick={() => handleClick('files')}
          title={t('panel.files', 'Files')}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/>
            <polyline points="13 2 13 9 20 9"/>
          </svg>
        </button>

        <button
          className={`activity-bar-item ${activeItem === 'git' ? 'active' : ''}`}
          onClick={() => handleClick('git')}
          title={t('panel.sourceControl', 'Source Control')}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="18" cy="18" r="3"/>
            <circle cx="6" cy="6" r="3"/>
            <path d="M13 6h3a2 2 0 0 1 2 2v7"/>
            <line x1="6" y1="9" x2="6" y2="21"/>
          </svg>
        </button>

        <button
          className={`activity-bar-item ${activeItem === 'playground' ? 'active' : ''}`}
          onClick={() => handleClick('playground')}
          title={t('panel.playground', 'Playground')}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <rect x="3" y="3" width="18" height="18" rx="2"/>
            <circle cx="12" cy="12" r="3"/>
            <path d="M12 3v6M12 15v6M3 12h6M15 12h6"/>
          </svg>
        </button>
      </div>

      <div className="activity-bar-bottom">
        <button
          className={`activity-bar-item ${activeItem === 'eprom' ? 'active' : ''}`}
          onClick={() => handleClick('eprom')}
          title={t('panel.eprom', 'EPROM Programmer')}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <rect x="5" y="2" width="14" height="20" rx="1"/>
            <line x1="5" y1="6" x2="3" y2="6"/>
            <line x1="5" y1="10" x2="3" y2="10"/>
            <line x1="5" y1="14" x2="3" y2="14"/>
            <line x1="5" y1="18" x2="3" y2="18"/>
            <line x1="19" y1="6" x2="21" y2="6"/>
            <line x1="19" y1="10" x2="21" y2="10"/>
            <line x1="19" y1="14" x2="21" y2="14"/>
            <line x1="19" y1="18" x2="21" y2="18"/>
            <circle cx="12" cy="9" r="2"/>
            <path d="M10 18h4"/>
          </svg>
        </button>

        <button
          className={`activity-bar-item ${activeItem === 'settings' ? 'active' : ''}`}
          onClick={() => handleClick('settings')}
          title={t('panel.settings', 'Settings')}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="3"/>
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
          </svg>
        </button>
      </div>
    </div>
  );
};
