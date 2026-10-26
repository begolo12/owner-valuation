import { useCallback, useEffect, useState } from 'react';
import { api, forgetToken, saveToken, token } from './api.js';
import { Notice, Spinner } from './components.jsx';
import Dashboard from './pages/Dashboard.jsx';
import Holding from './pages/Holding.jsx';
import Owner from './pages/Owner.jsx';
import Settings from './pages/Settings.jsx';

// Rute sederhana berbasis hash: cukup untuk 4 layar, tanpa router.
function parseRoute() {
  const h = window.location.hash.replace(/^#\/?/, '');
  const [kind, id] = h.split('/');
  if (kind === 'holding' && id) return { kind: 'holding', id };
  if (kind === 'owner' && id) return { kind: 'owner', id };
  if (kind === 'settings') return { kind: 'settings' };
  return { kind: 'dashboard' };
}

export default function App() {
  const [route, setRoute] = useState(parseRoute);
  // Token tersimpan = langsung masuk, tanpa isi ulang di perangkat yang sama.
  const [unlocked, setUnlocked] = useState(() => Boolean(token()));
  const [meta, setMeta] = useState(null);
  const [error, setError] = useState(null);
  const [booting, setBooting] = useState(true);

  useEffect(() => {
    const onHash = () => setRoute(parseRoute());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  // Muat meta sekali; dipakai semua form untuk daftar model & skema bayar.
  useEffect(() => {
    if (!unlocked) {
      setBooting(false);
      return;
    }
    let alive = true;
    setBooting(true);
    api
      .meta()
      .then((m) => {
        if (!alive) return;
        setMeta(m);
        setError(null);
      })
      .catch((e) => {
        if (!alive) return;
        // Token bisa sudah dirotasi di server: buang, jangan menyandera sesi.
        if (e.status === 401) {
          forgetToken();
          setUnlocked(false);
        } else setError(e.message);
      })
      .finally(() => alive && setBooting(false));
    return () => {
      alive = false;
    };
  }, [unlocked]);

  const go = useCallback((path) => {
    window.location.hash = path;
    window.scrollTo({ top: 0 });
  }, []);

  if (!unlocked) return <Unlock onDone={() => setUnlocked(true)} />;

  if (booting && !meta) {
    return (
      <div className="center-screen">
        <Spinner />
      </div>
    );
  }

  if (error) {
    return (
      <div className="center-screen">
        <div className="auth-card card">
          <h2>Tidak bisa terhubung</h2>
          <p className="sub">{error}</p>
          <div className="modal-actions">
            <button onClick={() => setUnlocked(false)}>Ganti token</button>
            <button className="primary" onClick={() => window.location.reload()}>
              Coba lagi
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="shell">
      <header className="topbar">
        <div className="brand">
          <svg width="20" height="20" viewBox="0 0 100 100" aria-hidden>
            <path
              d="M26 70V34l24-12 24 12v36"
              stroke="var(--accent)"
              strokeWidth="9"
              fill="none"
              strokeLinejoin="round"
            />
          </svg>
          Penilaian Owner
          <small>konstruksi</small>
        </div>
        <nav className="nav">
          <button className={route.kind === 'dashboard' ? 'active' : ''} onClick={() => go('/')}>
            Dashboard
          </button>
          <button
            className={route.kind === 'settings' ? 'active' : ''}
            onClick={() => go('/settings')}
          >
            Pengaturan
          </button>
        </nav>
      </header>

      {route.kind === 'dashboard' && <Dashboard meta={meta} go={go} />}
      {route.kind === 'holding' && <Holding id={route.id} go={go} />}
      {route.kind === 'owner' && <Owner id={route.id} meta={meta} go={go} />}
      {route.kind === 'settings' && (
        <Settings
          meta={meta}
          onSaved={() => window.location.reload()}
          onForget={() => {
            forgetToken();
            setUnlocked(false);
          }}
        />
      )}
    </div>
  );
}

function Unlock({ onDone }) {
  const [tok, setTok] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);

  const submit = async (e) => {
    e.preventDefault();
    const value = tok.trim();
    if (!value) return setErr('Token belum diisi.');
    setBusy(true);
    setErr(null);
    // Simpan dulu supaya header ikut terkirim; hapus lagi kalau server menolak
    // agar token salah tidak ikut tersimpan dan mengunci perangkat.
    saveToken(value);
    try {
      await api.meta();
      onDone();
    } catch (ex) {
      forgetToken();
      setErr(ex.status === 401 ? 'Token salah.' : ex.message);
      setBusy(false);
    }
  };

  return (
    <div className="center-screen">
      <form className="auth-card card" onSubmit={submit}>
        <h2>Penilaian Owner</h2>
        <p className="sub">
          Masukkan token aplikasi sekali. Perangkat ini akan mengingatnya, jadi lain kali langsung
          masuk.
        </p>
        {err && <Notice error>{err}</Notice>}
        <div className="field">
          <label htmlFor="tok">Token aplikasi</label>
          <input
            id="tok"
            type="password"
            value={tok}
            onChange={(e) => setTok(e.target.value)}
            placeholder="••••••••"
            autoComplete="current-password"
            autoFocus
          />
        </div>
        <div className="modal-actions">
          <button className="primary" disabled={busy} type="submit">
            {busy ? 'Memeriksa…' : 'Buka'}
          </button>
        </div>
      </form>
    </div>
  );
}
