import React from 'react';
import { useTranslation } from 'react-i18next';
import { useSettings } from '../../state/settingsStore';
import './SettingsPanel.css';

export const SettingsPanel: React.FC = () => {
  const { t } = useTranslation(['common']);
  const {
    compiler, setCompiler,
    buildTarget, setBuildTarget,
    pitrexCopyToSD, setPitrexCopyToSD,
    pitrexSdPath, setPitrexSdPath,
    uvm2CopyToSD, setUvm2CopyToSD,
    uvm2SdPath, setUvm2SdPath,
    rp2350FlashMethod, setRp2350FlashMethod,
    rp2350FirmwareDir, setRp2350FirmwareDir,
  } = useSettings();

  const handleBrowseSD = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    try {
      const result = await (window as any).file.openFolder();
      if (result && result.path) {
        setPitrexSdPath(result.path);
      }
    } catch (err) {
      console.error('[SettingsPanel] Browse SD failed:', err);
    }
  };

  const handleBrowseRp2350Firmware = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    try {
      const result = await (window as any).file.openFolder();
      if (result && result.path) {
        setRp2350FirmwareDir(result.path);
      }
    } catch (err) {
      console.error('[SettingsPanel] Browse RP2350 firmware failed:', err);
    }
  };

  const handleBrowseUvm2SD = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    try {
      const result = await (window as any).file.openFolder();
      if (result && result.path) {
        setUvm2SdPath(result.path);
      }
    } catch (err) {
      console.error('[SettingsPanel] Browse UVM2 SD failed:', err);
    }
  };

  return (
    <div className="settings-panel">
      <h2>{t('settings.title', 'Settings')}</h2>

      <div className="settings-section">
        <h3>{t('section.compiler', 'Compiler')}</h3>
        <p className="settings-description">
          {t('settings.compiler.description', 'Select which compiler backend to use for building VPy projects.')}
        </p>

        <div className="settings-option">
          <label className="settings-radio">
            <input
              type="radio"
              name="compiler"
              value="buildtools"
              checked={compiler === 'buildtools'}
              onChange={() => setCompiler('buildtools')}
            />
            <div className="radio-content">
              <span className="radio-title">{t('settings.compiler.buildtools.title', 'Buildtools (New)')}</span>
              <span className="radio-description">
                {t('settings.compiler.buildtools.desc', 'Modular 9-phase pipeline. Supports multibank ROMs and PDB debug symbols. Some edge cases may not compile correctly yet.')}
              </span>
            </div>
          </label>

          <label className="settings-radio">
            <input
              type="radio"
              name="compiler"
              value="core"
              checked={compiler === 'core'}
              onChange={() => setCompiler('core')}
            />
            <div className="radio-content">
              <span className="radio-title">{t('settings.compiler.core.title', 'Core (Legacy)')}</span>
              <span className="radio-description">
                {t('settings.compiler.core.desc', 'Original compiler. Stable and well-tested. Always outputs a fixed 32KB ROM. No PDB debug symbols. Recommended for most projects.')}
              </span>
            </div>
          </label>
        </div>
      </div>

      <div className="settings-section">
        <h3>{t('section.target', 'Build Target')}</h3>
        <p className="settings-description">
          {t('settings.target.description', 'Select the hardware target for compilation. M6809 targets the original Vectrex hardware. RP2350 targets the debug cartridge. PiTrex targets the Pi Zero inside a PiTrex cartridge.')}
        </p>

        <div className="settings-option">
          <label className="settings-radio">
            <input
              type="radio"
              name="buildTarget"
              value="m6809"
              checked={buildTarget === 'm6809'}
              onChange={() => setBuildTarget('m6809')}
            />
            <div className="radio-content">
              <span className="radio-title">{t('settings.target.m6809.title', 'M6809 (Vectrex)')}</span>
              <span className="radio-description">
                {t('settings.target.m6809.desc', 'Original Vectrex hardware. Produces a .bin ROM cartridge image.')}
              </span>
            </div>
          </label>

          <div className="settings-radio-group">
            <label className="settings-radio">
              <input
                type="radio"
                name="buildTarget"
                value="rp2350"
                checked={buildTarget === 'rp2350'}
                onChange={() => setBuildTarget('rp2350')}
              />
              <div className="radio-content">
                <span className="radio-title">{t('settings.target.rp2350.title', 'RP2350 (Debug Cartridge)')}</span>
                <span className="radio-description">
                  {t('settings.target.rp2350.desc', 'ARM Thumb2 target for the RP2350 debug cartridge. Requires arm-none-eabi toolchain on PATH.')}
                </span>
              </div>
            </label>
            {buildTarget === 'rp2350' && (
              <div className="pitrex-suboption">
                <span className="rp2350-flash-label">
                  {t('settings.target.rp2350.flash.title', 'Flash on Build & Run:')}
                </span>
                <label className="settings-checkbox">
                  <input
                    type="radio"
                    name="rp2350FlashMethod"
                    value="none"
                    checked={rp2350FlashMethod === 'none'}
                    onChange={() => setRp2350FlashMethod('none')}
                  />
                  <span>{t('settings.target.rp2350.flash.off', 'Off')}</span>
                </label>
                <label className="settings-checkbox">
                  <input
                    type="radio"
                    name="rp2350FlashMethod"
                    value="swd"
                    checked={rp2350FlashMethod === 'swd'}
                    onChange={() => setRp2350FlashMethod('swd')}
                  />
                  <span>{t('settings.target.rp2350.flash.swd', 'SWD (BIOS)')}</span>
                </label>
                <label className="settings-checkbox">
                  <input
                    type="radio"
                    name="rp2350FlashMethod"
                    value="usb"
                    checked={rp2350FlashMethod === 'usb'}
                    onChange={() => setRp2350FlashMethod('usb')}
                  />
                  <span>{t('settings.target.rp2350.flash.usb', 'USB (BOOTSEL)')}</span>
                </label>
                <div className="pitrex-sd-path">
                  <input
                    className="pitrex-sd-input"
                    type="text"
                    placeholder={t('settings.target.rp2350.firmwareDir.placeholder', 'Firmware directory (Rust crate with src/intro.s)')}
                    value={rp2350FirmwareDir}
                    onChange={e => setRp2350FirmwareDir(e.target.value)}
                    spellCheck={false}
                  />
                  <button type="button" className="pitrex-sd-browse" onClick={handleBrowseRp2350Firmware}>
                    Browse
                  </button>
                </div>
              </div>
            )}
          </div>

          <div className="settings-radio-group">
            <label className="settings-radio">
              <input
                type="radio"
                name="buildTarget"
                value="pitrex"
                checked={buildTarget === 'pitrex'}
                onChange={() => setBuildTarget('pitrex')}
              />
              <div className="radio-content">
                <span className="radio-title">{t('settings.target.pitrex.title', 'PiTrex (Pi Zero / ARMv6)')}</span>
                <span className="radio-description">
                  {t('settings.target.pitrex.desc', 'ARM32 native target for the PiTrex cartridge (Pi Zero). Produces a .img file. Requires arm-none-eabi toolchain and PITREX_SDK.')}
                </span>
              </div>
            </label>
            {buildTarget === 'pitrex' && (
              <div className="pitrex-suboption">
                <label className="settings-checkbox">
                  <input
                    type="checkbox"
                    checked={pitrexCopyToSD}
                    onChange={e => setPitrexCopyToSD(e.target.checked)}
                  />
                  <span>{t('settings.target.pitrex.copyToSD', 'Copy to SD')}</span>
                </label>
                {pitrexCopyToSD && (
                  <div className="pitrex-sd-path">
                    <input
                      className="pitrex-sd-input"
                      type="text"
                      placeholder="/Volumes/BAREMETAL  (leave empty to auto-detect)"
                      value={pitrexSdPath}
                      onChange={e => setPitrexSdPath(e.target.value)}
                      spellCheck={false}
                    />
                    <button type="button" className="pitrex-sd-browse" onClick={handleBrowseSD}>
                      Browse
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="settings-radio-group">
            <label className="settings-radio">
              <input
                type="radio"
                name="buildTarget"
                value="uvm2"
                checked={buildTarget === 'uvm2'}
                onChange={() => setBuildTarget('uvm2')}
              />
              <div className="radio-content">
                <span className="radio-title">{t('settings.target.uvm2.title', 'UVM2 (Ultimate Vectrex Multicart)')}</span>
                <span className="radio-description">
                  {t('settings.target.uvm2.desc', 'ARM Thumb2 target for the Ultimate Vectrex Multicart 2 (RP2350/Cortex-M33). Produces a .um2 raw binary for SD card.')}
                </span>
              </div>
            </label>
            {buildTarget === 'uvm2' && (
              <div className="pitrex-suboption">
                <label className="settings-checkbox">
                  <input
                    type="checkbox"
                    checked={uvm2CopyToSD}
                    onChange={e => setUvm2CopyToSD(e.target.checked)}
                  />
                  <span>{t('settings.target.uvm2.copyToSD', 'Copy to SD card')}</span>
                </label>
                {uvm2CopyToSD && (
                  <div className="pitrex-sd-path">
                    <input
                      className="pitrex-sd-input"
                      type="text"
                      placeholder="/Volumes/SD  (leave empty to auto-detect)"
                      value={uvm2SdPath}
                      onChange={e => setUvm2SdPath(e.target.value)}
                      spellCheck={false}
                    />
                    <button type="button" className="pitrex-sd-browse" onClick={handleBrowseUvm2SD}>
                      Browse
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="settings-info">
        <p>
          {t('settings.note', 'Note: Changes take effect on the next build. The compiler setting is saved in your browser\'s local storage.')}
        </p>
      </div>
    </div>
  );
};
