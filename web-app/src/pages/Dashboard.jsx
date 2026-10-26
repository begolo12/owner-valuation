import { useCallback, useEffect, useState } from 'react';
import { api } from '../api.js';
import { Grade, Modal, Notice, Spinner } from '../components.jsx';
import { gradeOf, modelLabels } from '../labels.js';
import { useEscape } from '../useEscape.js';

export default function Dashboard({ go }) {
  const [data, setData] = useState(null);
  const [holdings, setHoldings] = useState([]);
  const [error, setError] = useState(null);
  const [adding, setAdding] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(null);

  const load = useCallback(async () => {
    try {
      const [dash, hs] = await Promise.all([api.dashboard(), api.holdings()]);
      setData(dash);
      setHoldings(hs.items);
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  if (error) {
    return (
      <div className="page">
        <Notice error>{error}</Notice>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="page">
        <div className="empty">
          <Spinner />
        </div>
      </div>
    );
  }

  const done =
    data.totals.owners === 0 ? 0 : Math.round((data.totals.assessed * 100) / data.totals.owners);

  return (
    <div className="page">
      <div className="page-head">
        <div>
          <h1>Dashboard</h1>
          <p>
            Kuartal {data.quarter} · {data.totals.owners} owner/proyek
          </p>
        </div>
        <div className="spacer" />
        <button className="primary" onClick={() => setAdding(true)}>
          + Holding
        </button>
      </div>

      <div className="grid-3">
        <div className="stat">
          <div className="k">Holding</div>
          <div className="v">{data.totals.holdings}</div>
          <div className="h">grup usaha</div>
        </div>
        <div className="stat">
          <div className="k">Owner / proyek</div>
          <div className="v">{data.totals.owners}</div>
          <div className="h">pihak yang dinilai</div>
        </div>
        <div className="stat">
          <div className="k">Sudah dinilai</div>
          <div className="v">{done}%</div>
          <div className="bar">
            <span style={{ width: `${done}%` }} />
          </div>
          <div className="h">
            {data.totals.assessed} dari {data.totals.owners} kuartal ini
            {data.totals.missing > 0 ? ` · ${data.totals.missing} belum` : ''}
          </div>
        </div>
      </div>

      {data.byModel.length > 0 && (
        <div className="card" style={{ marginTop: 12 }}>
          <h2>Rata-rata per model</h2>
          <p className="sub">Kuartal {data.quarter}</p>
          {data.byModel.map((m) => (
            <div className="row" key={m.model} style={{ padding: '7px 0' }}>
              <span style={{ flex: 1 }}>{modelLabels[m.model] || m.model}</span>
              <span className="meta">
                {m.avg.toFixed(1)} · {m.count} owner
              </span>
              <Grade grade={gradeOf(m.avg)} compact />
            </div>
          ))}
        </div>
      )}

      {data.top.length > 0 && (
        <div className="card" style={{ marginTop: 12 }}>
          <h2>Peringkat teratas</h2>
          <p className="sub">Skor kuartal {data.quarter}</p>
          {data.top.slice(0, 5).map((t, i) => (
            <div className="row" key={`${t.ownerId}-${t.model}`} style={{ padding: '7px 0' }}>
              <span className="meta" style={{ width: 16, fontVariantNumeric: 'tabular-nums' }}>
                {i + 1}
              </span>
              <span style={{ flex: 1, minWidth: 0 }}>
                <div style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {t.name}
                </div>
                <div className="meta">
                  {t.holding}
                  {t.project ? ` · ${t.project}` : ''} · {modelLabels[t.model] || t.model}
                </div>
              </span>
              <strong style={{ fontVariantNumeric: 'tabular-nums' }}>{t.total.toFixed(1)}</strong>
              <Grade grade={t.grade} compact />
            </div>
          ))}
        </div>
      )}

      <div className="section">Holding</div>
      {holdings.length === 0 ? (
        <div className="card empty">
          Belum ada holding.
          <br />
          Tekan “+ Holding” untuk menambah grup usaha pertama.
        </div>
      ) : (
        <div className="stack">
          {holdings.map((h) => (
            <div className="item" key={h.id}>
              <button
                className="ghost"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  flex: 1,
                  minWidth: 0,
                  border: 0,
                  background: 'transparent',
                  padding: 0,
                  textAlign: 'left',
                }}
                onClick={() => go(`/holding/${h.id}`)}
              >
                <div className="avatar">{h.name.trim().charAt(0).toUpperCase()}</div>
                <div className="grow">
                  <div className="name">{h.name}</div>
                  <div className="meta">{h.ownerCount} owner/proyek</div>
                </div>
                <span className="chev">›</span>
              </button>
              <button
                className="ghost danger"
                onClick={() => setConfirmDelete(h)}
                title="Hapus holding"
                aria-label={`Hapus ${h.name}`}
              >
                ✕
              </button>
            </div>
          ))}
        </div>
      )}

      {adding && (
        <AddHolding
          onClose={() => setAdding(false)}
          onSaved={() => {
            setAdding(false);
            load();
          }}
        />
      )}

      {confirmDelete && (
        <DeleteHolding
          holding={confirmDelete}
          onClose={() => setConfirmDelete(null)}
          onDeleted={() => {
            setConfirmDelete(null);
            load();
          }}
        />
      )}
    </div>
  );
}

function AddHolding({ onClose, onSaved }) {
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);
  useEscape(onClose);

  const save = async (e) => {
    e.preventDefault();
    if (!name.trim()) return setErr('Nama holding belum diisi.');
    setBusy(true);
    setErr(null);
    try {
      await api.createHolding(name.trim());
      onSaved();
    } catch (ex) {
      setErr(ex.message);
      setBusy(false);
    }
  };

  return (
    <Modal
      title="Holding baru"
      subtitle="Holding adalah grup usaha. Proyek dan owner ditambahkan di dalamnya."
      onClose={onClose}
      actions={
        <>
          <button onClick={onClose}>Batal</button>
          <button className="primary" disabled={busy} onClick={save}>
            {busy ? 'Menyimpan…' : 'Simpan'}
          </button>
        </>
      }
    >
      {err && <Notice error>{err}</Notice>}
      <form onSubmit={save}>
        <div className="field">
          <label htmlFor="hn">Nama holding</label>
          <input
            id="hn"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Contoh: PT Bangun Sentosa"
            autoFocus
          />
        </div>
      </form>
    </Modal>
  );
}

function DeleteHolding({ holding, onClose, onDeleted }) {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);
  useEscape(onClose);

  const run = async () => {
    setBusy(true);
    try {
      await api.deleteHolding(holding.id);
      onDeleted();
    } catch (ex) {
      setErr(ex.message);
      setBusy(false);
    }
  };

  return (
    <Modal
      title="Hapus holding?"
      subtitle={`“${holding.name}” beserta ${holding.ownerCount} owner dan seluruh penilaiannya akan terhapus permanen.`}
      onClose={onClose}
      actions={
        <>
          <button onClick={onClose}>Batal</button>
          <button className="danger" disabled={busy} onClick={run}>
            {busy ? 'Menghapus…' : 'Hapus permanen'}
          </button>
        </>
      }
    >
      {err && <Notice error>{err}</Notice>}
    </Modal>
  );
}
