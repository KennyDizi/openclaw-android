import { useState, useEffect } from 'react'
import { useRoute } from '../lib/router'
import { bridge } from '../lib/bridge'

interface AppInfo {
  versionName: string
  versionCode: number
  packageName: string
}

export function SettingsAbout() {
  const { navigate } = useRoute()
  const [appInfo, setAppInfo] = useState<AppInfo | null>(null)
  const [scriptVersion, setScriptVersion] = useState<string>('—')
  const [runtimeInfo, setRuntimeInfo] = useState<Record<string, string>>({})

  const [apkUpdateAvailable, setApkUpdateAvailable] = useState(false)

  useEffect(() => {
    const info = bridge.callJson<AppInfo>('getAppInfo')
    if (info) setAppInfo(info)



    // Check APK update availability (async, non-blocking)
    setTimeout(() => {
      const apkInfo = bridge.callJson<{ updateAvailable?: boolean }>('getApkUpdateInfo')
      if (apkInfo?.updateAvailable) setApkUpdateAvailable(true)
    }, 0)

    // Get runtime versions
    const nodeV = bridge.callJson<{ stdout: string }>('runCommand', 'node -v 2>/dev/null')
    const gitV = bridge.callJson<{ stdout: string }>('runCommand', 'git --version 2>/dev/null')
    const oaV = bridge.callJson<{ stdout: string }>('runCommand', 'oa --version 2>/dev/null | head -1')
    setScriptVersion(oaV?.stdout?.trim() || '—')
    setRuntimeInfo({
      'Node.js': nodeV?.stdout?.trim() || '—',
      'git': gitV?.stdout?.trim()?.replace('git version ', '') || '—',
    })
  }, [])

  return (
    <div className="page">
      <div className="page-header">
        <button className="back-btn" onClick={() => navigate('/settings')}>←</button>
        <div className="page-title">About</div>
      </div>

      <div style={{ textAlign: 'center', padding: '24px 0' }}>
        <img src="./claw-icon.svg" alt="Claw" style={{ width: 64, height: 64, marginBottom: 8 }} />
        <div style={{ fontSize: 20, fontWeight: 700 }}>Claw</div>
      </div>

      <div className="section-title">Version</div>
      <div className="card">
        <div className="info-row">
          <span className="label">APK</span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            {appInfo?.versionName || '\u2014'}
            {apkUpdateAvailable && (
              <span style={{
                  fontSize: 11, fontWeight: 600,
                  color: '#10b981', border: '1px solid #10b981',
                  borderRadius: 4, padding: '1px 6px', cursor: 'pointer'
                }}
                onClick={() => bridge.call('openUrl', 'https://github.com/AidanPark/openclaw-android/releases/latest')}
              >Update available</span>
            )}
          </span>
        </div>

        <div className="info-row">
          <span className="label">Package</span>
          <span style={{ fontSize: 12 }}>{appInfo?.packageName || '—'}</span>
        </div>
        <div className="info-row">
          <span className="label">Script</span>
          <span>{scriptVersion}</span>
        </div>
      </div>

      <div className="section-title">Runtime</div>
      <div className="card">
        {Object.entries(runtimeInfo).map(([key, val]) => (
          <div className="info-row" key={key}>
            <span className="label">{key}</span>
            <span>{val}</span>
          </div>
        ))}
      </div>

      <div className="divider" />

      <div className="card">
        <div className="info-row">
          <span className="label">License</span>
          <span>GPL v3</span>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 12, marginTop: 16 }}>
        <button
          className="btn btn-secondary"
          style={{ flex: 1 }}
          onClick={() => {
            bridge.call('openSystemSettings', 'app_info')
          }}
        >
          App Info
        </button>
      </div>

      <div style={{
        textAlign: 'center',
        color: 'var(--text-secondary)',
        fontSize: 13,
        marginTop: 32,
      }}>
        Made for Android
      </div>
    </div>
  )
}
