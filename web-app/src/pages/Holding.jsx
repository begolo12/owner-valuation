import { useCallback, useEffect, useState } from 'react';
import { api } from '../api.js';
import { Modal, Notice, OwnerRow, Spinner } from '../components.jsx';
import { useEscape } from '../useEscape.js';

export default function Holding({ id, go }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [adding, setAdding] = useState(false);

  const load = useCallback(async () => {
    try {
      setData(await api.holding(id));
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  if (error) {
    return (
      <div className="page">
        <Notice error>{error}</Notice>
        <div style={{ marginTop: 12 }}>
          <button onClick={() => go('/')}>← Kembali</button>
        </div>
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

  return (
    <div className="page">
      <div className="page-head">
        <div style={{ minWidth: 0 }}>
          <button className="back" onClick={() => go('/')}>
            ← Dashboard
          </button>
          <h1>{data.holding.name}</h1>
          <p>
            {data.owners.length} owner/proyek · kuartal {data.quarter}
          </p>
        </div>
        <div className="spacer" />
        <button className="primary" onClick={() => setAdding(true)}>
          + Owner / proyek
        </button>
      </div>

      {data.owners.length === 0 ? (
        <div className="card empty">
          Belum ada owner di holding ini.
          <br />
          Tambahkan pihak yang menerima material beserta nama proyeknya.
        </div>
      ) : (
        <div className="stack">
          {data.owners.map((o) => (
            <OwnerRow key={o.id} owner={o} onClick={() => go(`/owner/${o.id}`)} />
          ))}
        </div>
      )}

      {adding && (
        <AddOwner
          holdingId={id}
          onClose={() => setAdding(false)}
          onSaved={() => {
            setAdding(false);
            load();
          }}
        />
      )}
    </div>
  );
}

function AddOwner({ holdingId, onClose, onSaved }) {
  const [name, setName] = useState('');
  const [project, setProject] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);
  useEscape(onClose);

  const save = async (e) => {
    e.preventDefault();
    if (!name.trim()) return setErr('Nama owner belum diisi.');
    setBusy(true);
    setErr(null);
    try {
      await api.createOwner(holdingId, name.trim(), project.trim() || null);
      onSaved();
    } catch (ex) {
      setErr(ex.message);
      setBusy(false);
    }
  };

  return (
    <Modal
      title="Owner / proyek baru"
      subtitle="Nama pihak yang menerima material, dan proyek yang dikerjakan."
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
          <label htmlFor="on">Nama owner</label>
          <input
            id="on"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Contoh: PT Griya Utama"
            autoFocus
          />
        </div>
        <div className="field">
          <label htmlFor="op">Proyek (opsional)</label>
          <input
            id="op"
            value={project}
            onChange={(e) => setProject(e.target.value)}
            placeholder="Contoh: Apartemen Bukit Hijau — Tower B"
          />
        </div>
      </form>
    </Modal>
  );
}
