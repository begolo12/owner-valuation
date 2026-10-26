import { useState } from 'react';
import { saveConnection, token } from '../api.js';
import { Notice } from '../components.jsx';

export default function Settings({ meta, onSaved, onForget }) {
  const [tok, setTok] = useState('');
  const [status, setStatus] = useState(null);
  const [busy, setBusy] = useState(false);

  const save = async () => {
    if (!tok.trim()) {
      setStatus({ error: true, text: 'Token belum diisi.' });
      return;
    }
    setBusy(true);
    saveConnection({ tok: tok.trim() });
    setStatus({ text: 'Token tersimpan. Memuat ulang…' });
    onSaved();
  };

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <h1>Pengaturan</h1>
          <p>Token akses dan informasi aplikasi</p>
        </div>
      </div>

      {status && <Notice error={status.error}>{status.text}</Notice>}

      <div className="card" style={{ marginTop: 12 }}>
        <h2>Token aplikasi</h2>
        <p className="sub">
          {token() ? `Terpasang: ${token().slice(0, 6)}…${token().slice(-4)}` : 'Belum ada token.'}
        </p>
        <div className="field">
          <label htmlFor="nt">Token baru</label>
          <input
            id="nt"
            type="password"
            value={tok}
            onChange={(e) => setTok(e.target.value)}
            placeholder="••••••••"
          />
          <div className="help">
            Token dibuat di server (env <code>APP_TOKEN</code>). Tidak pernah disimpan di dalam bundle.
          </div>
        </div>
        <div className="row" style={{ marginTop: 12 }}>
          <button className="primary" disabled={busy} onClick={save}>
            Simpan & muat ulang
          </button>
          <button className="danger" onClick={onForget}>
            Lupakan token
          </button>
        </div>
      </div>

      <div className="card">
        <h2>Server</h2>
        <p className="sub">
          Kuartal berjalan: <strong>{meta.currentQuarter}</strong>
        </p>
        <div className="help">
          Model: {meta.models.join(', ')}
        </div>
        <div className="help">
          Skema bayar: {meta.paymentMethods.join(', ')}
        </div>
      </div>

      <div className="card">
        <h2>Alur kerja</h2>
        <ol className="sub" style={{ paddingLeft: 18, margin: 0 }}>
          <li>Tambah holding.</li>
          <li>Tambah owner / proyek di dalam holding.</li>
          <li>Tekan “Nilai”: pilih skema bayar, TOP, kredibilitas owner, dan prospek proyek.</li>
          <li>Skema bayar dan TOP otomatis menentukan skornya.</li>
        </ol>
      </div>
    </div>
  );
}
