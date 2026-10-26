import { modelLabels, paymentLabels, rupiah } from './labels.js';

export function Grade({ grade, compact }) {
  return <span className={`badge ${grade.toLowerCase()}`}>{compact ? grade : `Grade ${grade}`}</span>;
}

export function Notice({ children, error }) {
  return <div className={`notice${error ? ' error' : ''}`}>{children}</div>;
}

export function Modal({ title, subtitle, onClose, children, actions }) {
  return (
    <div className="backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal" role="dialog" aria-modal="true" aria-label={title}>
        <h2>{title}</h2>
        {subtitle && <p className="sub">{subtitle}</p>}
        {children}
        {actions && <div className="modal-actions">{actions}</div>}
      </div>
    </div>
  );
}

export function Spinner() {
  return <span className="spinner" />;
}

// Baris ringkas owner + dua skor terakhir.
export function OwnerRow({ owner, onClick }) {
  const latest = owner.latest || [];
  const by = (m) => latest.find((l) => l.model === m);
  const existing = by('market_existing');
  const baru = by('market_baru');
  return (
    <button className="item" onClick={onClick}>
      <div className="avatar">{owner.name.trim().charAt(0).toUpperCase()}</div>
      <div className="grow">
        <div className="name">{owner.name}</div>
        <div className="meta">
          {owner.project ? `${owner.project} · ` : ''}
          {latest.length === 0
            ? 'Belum dinilai'
            : `Existing ${existing ? existing.total.toFixed(1) : '—'} · Baru ${
                baru ? baru.total.toFixed(1) : '—'
              }`}
        </div>
      </div>
      {existing && <Grade grade={existing.grade} compact />}
      <span className="chev">›</span>
    </button>
  );
}

export function AssessmentRow({ a, onDelete }) {
  return (
    <div className="item" style={{ alignItems: 'flex-start' }}>
      <div className="grow">
        <div className="name">
          {a.quarter} · {modelLabels[a.model] || a.model}
        </div>
        <div className="meta">
          {paymentLabels[a.paymentMethod] || a.paymentMethod} · TOP {a.paymentTenor} hari
          {a.projectionValue ? ` · proyeksi ${rupiah(a.projectionValue)}` : ''}
        </div>
        {a.projectionNotes && (
          <div className="meta" style={{ whiteSpace: 'normal' }}>
            {a.projectionNotes}
          </div>
        )}
      </div>
      <div className="row" style={{ flex: 'none' }}>
        <strong style={{ fontVariantNumeric: 'tabular-nums' }}>{a.total.toFixed(1)}</strong>
        <Grade grade={a.grade} compact />
        <button className="ghost danger" onClick={onDelete} title="Hapus penilaian" aria-label="Hapus penilaian">
          ✕
        </button>
      </div>
    </div>
  );
}
