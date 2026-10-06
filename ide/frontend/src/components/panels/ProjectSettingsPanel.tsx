import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useProjectStore } from '../../state/projectStore';
import { useSettings } from '../../state/settingsStore';
import './SettingsPanel.css';
import './ProjectSettingsPanel.css';

/** Parse "vX.Y.Z[-suffix]" into numeric parts; unknown shapes sort last. */
function tagParts(tag: string): number[] | null {
  const m = /^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?/.exec(tag);
  if (!m) return null;
  return [Number(m[1]), Number(m[2] ?? 0), Number(m[3] ?? 0)];
}

/** Newest first. Pre-release suffixes sort below the plain release. */
function compareTagsDesc(a: string, b: string): number {
  const pa = tagParts(a);
  const pb = tagParts(b);
  if (pa && !pb) return -1;
  if (!pa && pb) return 1;
  if (pa && pb) {
    for (let i = 0; i < 3; i++) {
      if (pa[i] !== pb[i]) return pb[i] - pa[i];
    }
    const sa = a.includes('-');
    const sb = b.includes('-');
    if (sa !== sb) return sa ? 1 : -1;
  }
  return b.localeCompare(a);
}

function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}

function joinPath(root: string, tag: string): string {
  const sep = root.includes('\\') && !root.includes('/') ? '\\' : '/';
  return root.endsWith(sep) ? `${root}${tag}` : `${root}${sep}${tag}`;
}

/**
 * The Arm GNU Toolchain uvm2 builds compile with. It is never downloaded (large, per
 * platform), so this only reports what the build will find — and warns when a uvm2
 * project has none.
 */
const ArmToolchainSection: React.FC<{ needed: boolean }> = ({ needed }) => {
  const { t } = useTranslation(['common']);
  const sdk = window.sdk;
  const [status, setStatus] = useState<ToolchainStatus | null>(null);
  const [checking, setChecking] = useState(false);

  const check = useCallback(async () => {
    if (!sdk?.toolchain) return;
    setChecking(true);
    try {
      setStatus(await sdk.toolchain());
    } finally {
      setChecking(false);
    }
  }, [sdk]);

  useEffect(() => { void check(); }, [check]);

  if (!sdk?.toolchain) return null;
  const rejected = status?.candidates.filter(c => c.problem) ?? [];

  return (
    <div className="settings-section">
      <h3>{t('projectSettings.toolchain.title', 'Arm GNU Toolchain')}</h3>
      <p className="settings-description">
        {t('projectSettings.toolchain.description', 'The compiler UVM2 builds use. It is not downloaded by the IDE: install it once from Arm.')}
      </p>

      {!status && <p className="settings-description">{t('projectSettings.sdk.loading', 'Loading...')}</p>}

      {status?.found && (
        <>
          <div className="ps-row">
            <span className="ps-label">{t('projectSettings.toolchain.found', 'Found:')}</span>
            <span className="ps-version">{status.found.version ?? '?'}</span>
            <span className="ps-badge ps-badge-ok">{t('projectSettings.sdk.mark.installed', 'installed')}</span>
          </div>
          <p className="ps-small ps-path" title={status.found.dir}>{status.found.dir}</p>
        </>
      )}

      {status && !status.found && (
        <div className={`ps-message ${needed ? 'ps-error' : 'ps-notice'}`}>
          <div>
            {needed
              ? t('projectSettings.toolchain.missingNeeded', 'This project builds for UVM2, and no usable Arm GNU Toolchain was found: the build will fail.')
              : t('projectSettings.toolchain.missing', 'No Arm GNU Toolchain found. Only UVM2 builds need it.')}
          </div>
          <div className="ps-small">
            {t('projectSettings.toolchain.howTo', 'Install the "arm-none-eabi" (bare-metal AArch32) toolchain from developer.arm.com — not the Homebrew one — or set UVM2_ARM_TOOLCHAIN to its arm-none-eabi folder before starting the IDE.')}
          </div>
          {rejected.length > 0 && (
            <ul className="ps-small ps-candidates">
              {rejected.map(c => (
                <li key={c.dir} title={c.dir}>
                  <span className="ps-path">{c.dir}</span> — {c.problem}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      <div className="ps-row">
        {status && !status.found && (
          <button className="pitrex-sd-browse" onClick={() => void sdk.openToolchainDownload()}>
            {t('projectSettings.toolchain.download', 'Open download page')}
          </button>
        )}
        <button className="pitrex-sd-browse" onClick={() => void check()} disabled={checking}>
          {t('projectSettings.toolchain.recheck', 'Check again')}
        </button>
      </div>
    </div>
  );
};

interface ProjectVersionState {
  version: string;
  pinned: boolean;
}

export const ProjectSettingsPanel: React.FC = () => {
  const { t } = useTranslation(['common']);
  const vpyProject = useProjectStore(s => s.vpyProject);
  const projectFile = vpyProject?.projectFile;
  // C projects declare their target; VPy projects build for the target chosen in Settings.
  const globalTarget = useSettings(s => s.buildTarget);
  const buildsForUvm2 = (vpyProject?.isExternal ? vpyProject?.target : globalTarget) === 'uvm2';
  const sdk = window.sdk;

  const [list, setList] = useState<SdkListResult | null>(null);
  const [listLoading, setListLoading] = useState(false);
  const [proj, setProj] = useState<ProjectVersionState | null>(null);
  const [projError, setProjError] = useState<string | null>(null);
  const [versionError, setVersionError] = useState<string | null>(null);

  const [installingTag, setInstallingTag] = useState<string | null>(null);
  const [progress, setProgress] = useState<SdkProgress | null>(null);
  const [installError, setInstallError] = useState<{ tag: string; error: string } | null>(null);
  const [saving, setSaving] = useState(false);

  const installingRef = useRef<string | null>(null);

  const refreshList = useCallback(async (refresh = false) => {
    if (!sdk) return;
    setListLoading(true);
    try {
      setList(await sdk.list({ refresh }));
    } catch (err) {
      console.error('[ProjectSettingsPanel] sdk.list failed:', err);
    } finally {
      setListLoading(false);
    }
  }, [sdk]);

  // Load the project's pinned version and the version list whenever the project changes.
  useEffect(() => {
    if (!sdk || !projectFile) return;
    let cancelled = false;
    setProj(null);
    setProjError(null);
    setVersionError(null);
    setInstallError(null);
    (async () => {
      try {
        const r = await sdk.getProjectVersion(projectFile);
        if (cancelled) return;
        if (r.ok) setProj({ version: r.version, pinned: r.pinned });
        else setProjError(r.error);
      } catch (err) {
        if (!cancelled) setProjError(String(err));
      }
      // Fetched after getProjectVersion so a freshly pinned project sees fresh data.
      if (!cancelled) await refreshList(false);
    })();
    return () => { cancelled = true; };
  }, [sdk, projectFile, refreshList]);

  // Install progress (only the tag this panel is installing).
  useEffect(() => {
    if (!sdk) return;
    return sdk.onProgress(p => {
      if (installingRef.current && p.tag === installingRef.current) setProgress(p);
    });
  }, [sdk]);

  const installed = useMemo(() => new Set(list?.installed ?? []), [list]);

  const versions = useMemo(() => {
    const all = new Set<string>([...(list?.installed ?? []), ...(list?.remote ?? [])]);
    if (proj?.version) all.add(proj.version);
    return [...all].sort(compareTagsDesc);
  }, [list, proj]);

  const install = useCallback(async (tag: string) => {
    if (!sdk || installingRef.current) return;
    installingRef.current = tag;
    setInstallingTag(tag);
    setProgress(null);
    setInstallError(null);
    try {
      const r = await sdk.install(tag);
      if (!r.ok) setInstallError({ tag, error: r.error });
    } catch (err) {
      setInstallError({ tag, error: String(err) });
    } finally {
      installingRef.current = null;
      setInstallingTag(null);
      setProgress(null);
      await refreshList(false);
    }
  }, [sdk, refreshList]);

  const handleSelect = async (tag: string) => {
    if (!sdk || !projectFile || !proj || tag === proj.version) return;
    setSaving(true);
    setVersionError(null);
    setInstallError(null);
    try {
      const r = await sdk.setProjectVersion(projectFile, tag);
      if (!r.ok) {
        setVersionError(r.error);
        return;
      }
      setProj({ version: tag, pinned: false });
    } catch (err) {
      setVersionError(String(err));
      return;
    } finally {
      setSaving(false);
    }
    // Pinning a version that isn't on disk: download it right away so the next
    // build doesn't stall on it.
    if (!installed.has(tag)) void install(tag);
  };

  if (!projectFile) {
    return (
      <div className="settings-panel">
        <h2>{t('projectSettings.title', 'Project Settings')}</h2>
        <p className="settings-description">{t('projectSettings.noProject', 'Open a project to see its settings.')}</p>
      </div>
    );
  }

  if (!sdk) {
    return (
      <div className="settings-panel">
        <h2>{t('projectSettings.title', 'Project Settings')}</h2>
        <p className="settings-description">{t('projectSettings.sdk.unavailable', 'SDK management is only available in the desktop app.')}</p>
      </div>
    );
  }

  const busy = installingTag !== null || saving;
  const current = proj?.version ?? null;
  const currentInstalled = current ? installed.has(current) : false;
  const offline = list !== null && list.remote === null;

  const pct = progress && progress.total ? Math.min(100, (progress.received / progress.total) * 100) : null;
  let progressLabel = '';
  if (installingTag) {
    if (!progress || progress.phase === 'download') {
      const received = formatBytes(progress?.received ?? 0);
      progressLabel = progress?.total
        ? t('projectSettings.sdk.progress.downloadTotal', 'Downloading {{tag}}: {{received}} / {{total}}', { tag: installingTag, received, total: formatBytes(progress.total) })
        : t('projectSettings.sdk.progress.download', 'Downloading {{tag}}: {{received}}', { tag: installingTag, received });
    } else if (progress.phase === 'extract') {
      progressLabel = t('projectSettings.sdk.progress.extract', 'Extracting {{tag}}...', { tag: installingTag });
    } else {
      progressLabel = t('projectSettings.sdk.progress.done', 'Finishing {{tag}}...', { tag: installingTag });
    }
  }

  const optionLabel = (tag: string) => {
    const marks: string[] = [];
    if (list?.latest === tag) marks.push(t('projectSettings.sdk.mark.latest', 'latest'));
    if (installed.has(tag)) marks.push(t('projectSettings.sdk.mark.installed', 'installed'));
    return marks.length ? `${tag} (${marks.join(', ')})` : tag;
  };

  return (
    <div className="settings-panel project-settings-panel">
      <h2>{t('projectSettings.title', 'Project Settings')}</h2>

      <div className="settings-section">
        <h3>{t('projectSettings.sdk.title', 'SDK')}</h3>
        <p className="settings-description">
          {t('projectSettings.sdk.description', 'The uvmc2-sdk version this project builds against. It is stored in the project file and downloaded automatically when missing.')}
        </p>

        {projError && (
          <div className="ps-message ps-error">
            {t('projectSettings.sdk.readError', 'Could not read the project SDK version: {{error}}', { error: projError })}
          </div>
        )}

        {proj?.pinned && (
          <div className="ps-message ps-notice">
            {t('projectSettings.sdk.pinnedNotice', 'This project had no SDK version; it has been pinned to {{version}}.', { version: proj.version })}
          </div>
        )}

        {!proj && !projError && (
          <p className="settings-description">{t('projectSettings.sdk.loading', 'Loading...')}</p>
        )}

        {proj && (
          <>
            <div className="ps-row">
              <span className="ps-label">{t('projectSettings.sdk.current', 'Current version:')}</span>
              <span className="ps-version">{proj.version}</span>
              <span className={`ps-badge ${currentInstalled ? 'ps-badge-ok' : 'ps-badge-missing'}`}>
                {currentInstalled
                  ? t('projectSettings.sdk.mark.installed', 'installed')
                  : t('projectSettings.sdk.notInstalled', 'not installed')}
              </span>
            </div>

            <div className="ps-row">
              <select
                className="ps-select"
                value={proj.version}
                disabled={busy}
                onChange={e => void handleSelect(e.target.value)}
                title={t('projectSettings.sdk.selectTitle', 'Change the SDK version of this project')}
              >
                {versions.map(tag => (
                  <option key={tag} value={tag}>{optionLabel(tag)}</option>
                ))}
              </select>
              <button
                className="pitrex-sd-browse"
                onClick={() => void refreshList(true)}
                disabled={busy || listLoading}
                title={t('projectSettings.sdk.refreshTitle', 'Check GitHub for new versions')}
              >
                {listLoading ? t('projectSettings.sdk.refreshing', 'Refreshing...') : t('action.refresh', 'Refresh')}
              </button>
            </div>

            {offline && (
              <p className="ps-small">
                {t('projectSettings.sdk.offline', 'Offline: only installed versions are listed.')}
              </p>
            )}

            {!currentInstalled && !installingTag && (
              <div className="ps-row">
                <button
                  className="pitrex-sd-browse"
                  onClick={() => void install(proj.version)}
                  disabled={busy}
                >
                  {t('projectSettings.sdk.download', 'Download {{tag}}', { tag: proj.version })}
                </button>
              </div>
            )}

            {installingTag && (
              <div className="ps-progress">
                <div className="ps-progress-track">
                  <div
                    className={`ps-progress-bar ${pct === null ? 'ps-progress-indeterminate' : ''}`}
                    style={pct === null ? undefined : { width: `${pct}%` }}
                  />
                </div>
                <span className="ps-small">{progressLabel}</span>
              </div>
            )}

            {installError && (
              <div className="ps-message ps-error">
                <div>{t('projectSettings.sdk.installError', 'Could not download {{tag}}: {{error}}', { tag: installError.tag, error: installError.error })}</div>
                <button
                  className="pitrex-sd-browse ps-retry"
                  onClick={() => void install(installError.tag)}
                  disabled={busy}
                >
                  {t('projectSettings.sdk.retry', 'Retry')}
                </button>
              </div>
            )}

            {versionError && (
              <div className="ps-message ps-error">
                {t('projectSettings.sdk.setError', 'Could not change the SDK version: {{error}}', { error: versionError })}
              </div>
            )}

            {list?.root && (
              <p className="ps-small ps-path" title={joinPath(list.root, proj.version)}>
                {t('projectSettings.sdk.folder', 'Install folder:')} {joinPath(list.root, proj.version)}
              </p>
            )}
          </>
        )}
      </div>

      <ArmToolchainSection needed={buildsForUvm2} />
    </div>
  );
};
