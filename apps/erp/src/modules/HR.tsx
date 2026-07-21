import { useEffect, useState } from 'react'
import { api } from '../lib/api'

type Department = { id: string; code: string; name: string; active: boolean }
type Position = { id: string; code: string; title: string; department_id?: string; active: boolean; departments?: { code: string; name: string } }
type Branch = { id: string; branch_no: string; name: string }
type StaffMember = { id: string; code: string; name: string; active: boolean }
type Employee = {
  id: string; employee_no: string; display_name: string; phone?: string; email?: string
  pan?: string; aadhaar_last4?: string; uan?: string; esi_no?: string
  bank_account?: string; bank_ifsc?: string; join_date?: string; exit_date?: string
  staff_member_id?: string; department_id?: string; position_id?: string; branch_id?: string; active: boolean
  departments?: { code: string; name: string } | null
  positions?: { code: string; title: string } | null
  branches?: { branch_no: string; name: string } | null
}
type HistoryRow = {
  id: string; from_date: string; to_date?: string; monthly_salary?: number; note?: string
  departments?: { code: string; name: string } | null
  positions?: { code: string; title: string } | null
  branches?: { branch_no: string; name: string } | null
}
type Structure = { basic: number; hra: number; allowances: number; pf_percent: number; esi_percent: number; pt_amount: number; tds_amount: number }
type EmployeeDetail = Employee & { history: HistoryRow[]; salary_structure: Structure | null }
type Run = { id: string; period_code: string; status: string; total_gross: number; total_net: number; voucher_id?: string }
type Line = {
  id: string; employee_id: string; days_present: number; days_in_month: number
  basic: number; hra: number; allowances: number; gross: number
  pf: number; esi: number; pt: number; tds: number; advance_recovery: number; incentives: number; net: number
  employees?: { employee_no: string; display_name: string }
}
type RunDetail = Run & { lines: Line[] }
type RegRow = {
  employee_no: string; employee_name: string; days_present: number; days_in_month: number
  basic: number; hra: number; allowances: number; gross: number
  pf: number; esi: number; pt: number; tds: number; advance_recovery: number; incentives: number; net: number; status: string
}

const TABS = ['Employees', 'Masters', 'Payroll', 'Reports'] as const
const box: React.CSSProperties = { border: '1px solid #e2e8f0', borderRadius: 8, padding: 16, marginBottom: 16 }
const th: React.CSSProperties = { textAlign: 'left', padding: '6px 10px', background: '#f1f5f9', fontSize: 13 }
const td: React.CSSProperties = { padding: '6px 10px', borderTop: '1px solid #e2e8f0', fontSize: 13 }
const num: React.CSSProperties = { ...td, textAlign: 'right', fontVariantNumeric: 'tabular-nums' }
const inp: React.CSSProperties = { padding: '6px 8px', border: '1px solid #cbd5e1', borderRadius: 6, fontSize: 13 }
const btn: React.CSSProperties = { padding: '6px 12px', border: 0, borderRadius: 6, background: '#0b1320', color: '#fff', cursor: 'pointer', fontSize: 13 }
const fmt = (n: number) => Number(n ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })

function downloadCsv(name: string, headers: string[], rows: (string | number)[][]) {
  const esc = (v: string | number) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [headers.map(esc).join(','), ...rows.map((r) => r.map(esc).join(','))].join('\n')
  const a = document.createElement('a')
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }))
  a.download = `${name}.csv`
  a.click()
}

export function HR({ entityId }: { entityId: string }) {
  const [tab, setTab] = useState<(typeof TABS)[number]>('Employees')
  const [err, setErr] = useState('')
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        {TABS.map((t) => (
          <button key={t} onClick={() => { setTab(t); setErr('') }}
            style={{ ...btn, background: tab === t ? '#0b1320' : '#e2e8f0', color: tab === t ? '#fff' : '#334155' }}>{t}</button>
        ))}
      </div>
      {err && <div style={{ color: '#b91c1c', marginBottom: 12, fontSize: 13 }}>{err}</div>}
      {tab === 'Employees' && <Employees entityId={entityId} setErr={setErr} />}
      {tab === 'Masters' && <Masters entityId={entityId} setErr={setErr} />}
      {tab === 'Payroll' && <Payroll entityId={entityId} setErr={setErr} />}
      {tab === 'Reports' && <Reports entityId={entityId} setErr={setErr} />}
    </div>
  )
}

// ------------------------------------------------------------ Employees
const emptyProfile = { displayName: '', phone: '', email: '', pan: '', aadhaarLast4: '', uan: '', esiNo: '', bankAccount: '', bankIfsc: '', joinDate: '', exitDate: '', staffMemberId: '', active: true }
type Profile = typeof emptyProfile

const toProfile = (e: Employee): Profile => ({
  displayName: e.display_name, phone: e.phone ?? '', email: e.email ?? '', pan: e.pan ?? '',
  aadhaarLast4: e.aadhaar_last4 ?? '', uan: e.uan ?? '', esiNo: e.esi_no ?? '',
  bankAccount: e.bank_account ?? '', bankIfsc: e.bank_ifsc ?? '',
  joinDate: e.join_date ?? '', exitDate: e.exit_date ?? '', staffMemberId: e.staff_member_id ?? '', active: e.active,
})

const profileBody = (p: Profile) => ({
  displayName: p.displayName, phone: p.phone || null, email: p.email || null, pan: p.pan || null,
  aadhaarLast4: p.aadhaarLast4 || null, uan: p.uan || null, esiNo: p.esiNo || null,
  bankAccount: p.bankAccount || null, bankIfsc: p.bankIfsc || null,
  joinDate: p.joinDate || null, exitDate: p.exitDate || null,
  staffMemberId: p.staffMemberId || null, active: p.active,
})

function Employees({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [rows, setRows] = useState<Employee[]>([])
  const [staff, setStaff] = useState<StaffMember[]>([])
  const [departments, setDepartments] = useState<Department[]>([])
  const [positions, setPositions] = useState<Position[]>([])
  const [branches, setBranches] = useState<Branch[]>([])
  const [form, setForm] = useState({ displayName: '', phone: '', joinDate: '', staffMemberId: '' })
  const [openId, setOpenId] = useState('')
  const [detail, setDetail] = useState<EmployeeDetail | null>(null)
  const load = () => {
    api<Employee[]>('/hr/employees', { entityId }).then(setRows).catch((e) => setErr(e.message))
    api<StaffMember[]>('/hr/staff-members', { entityId }).then(setStaff).catch(() => {})
    api<Department[]>('/hr/departments', { entityId }).then(setDepartments).catch(() => {})
    api<Position[]>('/hr/positions', { entityId }).then(setPositions).catch(() => {})
    api<Branch[]>('/entities/' + entityId + '/branches', { entityId }).then(setBranches).catch(() => {})
  }
  useEffect(() => { load(); setOpenId(''); setDetail(null) }, [entityId])
  const openEmployee = (id: string) => {
    setOpenId(id)
    api<EmployeeDetail>('/hr/employees/' + id, { entityId }).then(setDetail).catch((e) => setErr(e.message))
  }
  return (
    <div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>New employee (employee no is allocated automatically)</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <input style={{ ...inp, flex: 1, minWidth: 160 }} placeholder="Display name" value={form.displayName} onChange={(e) => setForm({ ...form, displayName: e.target.value })} />
          <input style={inp} placeholder="Phone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
          <input style={inp} type="date" title="Join date" value={form.joinDate} onChange={(e) => setForm({ ...form, joinDate: e.target.value })} />
          <select style={inp} value={form.staffMemberId} onChange={(e) => setForm({ ...form, staffMemberId: e.target.value })}>
            <option value="">Legacy staff link (optional)…</option>
            {staff.map((s) => <option key={s.id} value={s.id}>{s.code} {s.name}</option>)}
          </select>
          <button style={btn} disabled={!form.displayName}
            onClick={() => api<Employee>('/hr/employees', { method: 'POST', body: { displayName: form.displayName, phone: form.phone || null, joinDate: form.joinDate || null, staffMemberId: form.staffMemberId || null }, entityId })
              .then((e) => { setForm({ displayName: '', phone: '', joinDate: '', staffMemberId: '' }); load(); openEmployee(e.id) })
              .catch((e) => setErr(e.message))}>Create</button>
        </div>
      </div>
      {detail && detail.id === openId && (
        <EmployeeDetailPanel key={detail.id} entityId={entityId} setErr={setErr} detail={detail} staff={staff}
          departments={departments} positions={positions} branches={branches}
          reload={() => { load(); openEmployee(detail.id) }} close={() => { setOpenId(''); setDetail(null) }} />
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>No</th><th style={th}>Name</th><th style={th}>Phone</th><th style={th}>Department</th><th style={th}>Position</th><th style={th}>Branch</th><th style={th}>Staff link</th><th style={th}>Active</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.id} onClick={() => openEmployee(r.id)} style={{ cursor: 'pointer', background: r.id === openId ? '#f8fafc' : undefined }}>
            <td style={td}><b>{r.employee_no}</b></td><td style={td}>{r.display_name}</td><td style={td}>{r.phone ?? ''}</td>
            <td style={td}>{r.departments?.name ?? ''}</td><td style={td}>{r.positions?.title ?? ''}</td><td style={td}>{r.branches?.name ?? ''}</td>
            <td style={td}>{r.staff_member_id ? '🔗 linked' : '—'}</td><td style={td}>{r.active ? 'Yes' : 'No'}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function EmployeeDetailPanel({ entityId, setErr, detail, staff, departments, positions, branches, reload, close }: {
  entityId: string; setErr: (s: string) => void; detail: EmployeeDetail; staff: StaffMember[]
  departments: Department[]; positions: Position[]; branches: Branch[]; reload: () => void; close: () => void
}) {
  const [profile, setProfile] = useState<Profile>(toProfile(detail))
  const [struct, setStruct] = useState({
    basic: Number(detail.salary_structure?.basic ?? 0), hra: Number(detail.salary_structure?.hra ?? 0),
    allowances: Number(detail.salary_structure?.allowances ?? 0), pfPercent: Number(detail.salary_structure?.pf_percent ?? 12),
    esiPercent: Number(detail.salary_structure?.esi_percent ?? 0.75), ptAmount: Number(detail.salary_structure?.pt_amount ?? 200),
    tdsAmount: Number(detail.salary_structure?.tds_amount ?? 0),
  })
  const [hist, setHist] = useState({ positionId: detail.position_id ?? '', departmentId: detail.department_id ?? '', branchId: detail.branch_id ?? '', fromDate: '', monthlySalary: '', note: '' })
  const field = (label: string, key: keyof Profile, type = 'text', width = 130) => (
    <label style={{ fontSize: 12, color: '#64748b' }}>{label}<br />
      <input style={{ ...inp, width }} type={type} value={String(profile[key] ?? '')}
        onChange={(e) => setProfile({ ...profile, [key]: e.target.value })} />
    </label>
  )
  return (
    <div style={box}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <b style={{ fontSize: 14 }}>{detail.employee_no} — {detail.display_name}</b>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={close}>Close</button>
      </div>

      <div style={{ display: 'flex', gap: 10, marginTop: 10, flexWrap: 'wrap', alignItems: 'flex-end' }}>
        {field('Name', 'displayName', 'text', 160)}
        {field('Phone', 'phone')}
        {field('Email', 'email', 'text', 160)}
        {field('PAN', 'pan')}
        {field('Aadhaar last 4', 'aadhaarLast4', 'text', 90)}
        {field('UAN', 'uan')}
        {field('ESI no', 'esiNo')}
        {field('Bank account', 'bankAccount', 'text', 150)}
        {field('IFSC', 'bankIfsc')}
        {field('Join date', 'joinDate', 'date')}
        {field('Exit date', 'exitDate', 'date')}
        <label style={{ fontSize: 12, color: '#64748b' }}>Legacy staff link<br />
          <select style={inp} value={profile.staffMemberId} onChange={(e) => setProfile({ ...profile, staffMemberId: e.target.value })}>
            <option value="">— none —</option>
            {staff.map((s) => <option key={s.id} value={s.id}>{s.code} {s.name}</option>)}
          </select>
        </label>
        <label style={{ fontSize: 12, color: '#64748b' }}>Active<br />
          <select style={inp} value={profile.active ? '1' : '0'} onChange={(e) => setProfile({ ...profile, active: e.target.value === '1' })}>
            <option value="1">Yes</option><option value="0">No</option>
          </select>
        </label>
        <button style={btn}
          onClick={() => api('/hr/employees/' + detail.id, { method: 'PATCH', body: profileBody(profile), entityId }).then(reload).catch((e) => setErr(e.message))}>Save profile</button>
      </div>

      <div style={{ marginTop: 16, borderTop: '1px solid #e2e8f0', paddingTop: 12 }}>
        <b style={{ fontSize: 13 }}>Salary structure (monthly)</b>
        <div style={{ display: 'flex', gap: 10, marginTop: 8, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          {([['Basic', 'basic'], ['HRA', 'hra'], ['Allowances', 'allowances'], ['PF %', 'pfPercent'], ['ESI %', 'esiPercent'], ['PT amount', 'ptAmount'], ['TDS amount', 'tdsAmount']] as const).map(([label, key]) => (
            <label key={key} style={{ fontSize: 12, color: '#64748b' }}>{label}<br />
              <input style={{ ...inp, width: 90 }} type="number" value={struct[key] || ''}
                onChange={(e) => setStruct({ ...struct, [key]: +e.target.value })} />
            </label>
          ))}
          <span style={{ fontSize: 13 }}>Gross <b>{fmt(struct.basic + struct.hra + struct.allowances)}</b></span>
          <button style={btn}
            onClick={() => api('/hr/employees/' + detail.id + '/salary-structure', { method: 'PUT', body: struct, entityId }).then(reload).catch((e) => setErr(e.message))}>Save structure</button>
        </div>
      </div>

      <div style={{ marginTop: 16, borderTop: '1px solid #e2e8f0', paddingTop: 12 }}>
        <b style={{ fontSize: 13 }}>Employment history (new entry closes the previous one and updates the snapshot)</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap', alignItems: 'center' }}>
          <select style={inp} value={hist.departmentId} onChange={(e) => setHist({ ...hist, departmentId: e.target.value })}>
            <option value="">Department…</option>{departments.map((d) => <option key={d.id} value={d.id}>{d.code} {d.name}</option>)}
          </select>
          <select style={inp} value={hist.positionId} onChange={(e) => setHist({ ...hist, positionId: e.target.value })}>
            <option value="">Position…</option>{positions.map((p) => <option key={p.id} value={p.id}>{p.code} {p.title}</option>)}
          </select>
          <select style={inp} value={hist.branchId} onChange={(e) => setHist({ ...hist, branchId: e.target.value })}>
            <option value="">Branch (workplace)…</option>{branches.map((b) => <option key={b.id} value={b.id}>{b.branch_no} {b.name}</option>)}
          </select>
          <input style={inp} type="date" title="From date" value={hist.fromDate} onChange={(e) => setHist({ ...hist, fromDate: e.target.value })} />
          <input style={{ ...inp, width: 120 }} type="number" placeholder="Monthly salary" value={hist.monthlySalary} onChange={(e) => setHist({ ...hist, monthlySalary: e.target.value })} />
          <input style={{ ...inp, minWidth: 140 }} placeholder="Note" value={hist.note} onChange={(e) => setHist({ ...hist, note: e.target.value })} />
          <button style={btn} disabled={!hist.fromDate}
            onClick={() => api('/hr/employees/' + detail.id + '/history', {
              method: 'POST', entityId,
              body: { positionId: hist.positionId || null, departmentId: hist.departmentId || null, branchId: hist.branchId || null, fromDate: hist.fromDate, monthlySalary: hist.monthlySalary ? +hist.monthlySalary : null, note: hist.note || null },
            }).then(() => { setHist({ ...hist, fromDate: '', monthlySalary: '', note: '' }); reload() }).catch((e) => setErr(e.message))}>Add entry</button>
        </div>
        <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 8 }}>
          <thead><tr><th style={th}>From</th><th style={th}>To</th><th style={th}>Department</th><th style={th}>Position</th><th style={th}>Branch</th><th style={th}>Monthly salary</th><th style={th}>Note</th></tr></thead>
          <tbody>{detail.history.map((h) => (
            <tr key={h.id}>
              <td style={td}>{h.from_date}</td><td style={td}>{h.to_date ?? 'current'}</td>
              <td style={td}>{h.departments?.name ?? ''}</td><td style={td}>{h.positions?.title ?? ''}</td><td style={td}>{h.branches?.name ?? ''}</td>
              <td style={num}>{h.monthly_salary != null ? fmt(+h.monthly_salary) : ''}</td><td style={td}>{h.note ?? ''}</td>
            </tr>
          ))}</tbody>
        </table>
        {detail.history.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No history yet — add the first entry above.</p>}
      </div>
    </div>
  )
}

// ------------------------------------------------------------ Masters
function Masters({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [departments, setDepartments] = useState<Department[]>([])
  const [positions, setPositions] = useState<Position[]>([])
  const [dForm, setDForm] = useState({ code: '', name: '' })
  const [pForm, setPForm] = useState({ code: '', title: '', departmentId: '' })
  const load = () => {
    api<Department[]>('/hr/departments', { entityId }).then(setDepartments).catch((e) => setErr(e.message))
    api<Position[]>('/hr/positions', { entityId }).then(setPositions).catch((e) => setErr(e.message))
  }
  useEffect(() => { load() }, [entityId])
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
      <div style={box}>
        <b style={{ fontSize: 14 }}>Departments</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
          <input style={{ ...inp, width: 80 }} placeholder="Code" value={dForm.code} onChange={(e) => setDForm({ ...dForm, code: e.target.value })} />
          <input style={{ ...inp, flex: 1 }} placeholder="Name" value={dForm.name} onChange={(e) => setDForm({ ...dForm, name: e.target.value })} />
          <button style={btn} disabled={!dForm.code || !dForm.name}
            onClick={() => api('/hr/departments', { method: 'POST', body: dForm, entityId }).then(() => { setDForm({ code: '', name: '' }); load() }).catch((e) => setErr(e.message))}>Add</button>
        </div>
        <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 10 }}>
          <thead><tr><th style={th}>Code</th><th style={th}>Name</th><th style={th}>Active</th></tr></thead>
          <tbody>{departments.map((d) => (
            <tr key={d.id}><td style={td}><b>{d.code}</b></td><td style={td}>{d.name}</td><td style={td}>{d.active ? 'Yes' : 'No'}</td></tr>
          ))}</tbody>
        </table>
      </div>
      <div style={box}>
        <b style={{ fontSize: 14 }}>Positions</b>
        <div style={{ display: 'flex', gap: 8, marginTop: 10, flexWrap: 'wrap' }}>
          <input style={{ ...inp, width: 80 }} placeholder="Code" value={pForm.code} onChange={(e) => setPForm({ ...pForm, code: e.target.value })} />
          <input style={{ ...inp, flex: 1, minWidth: 120 }} placeholder="Title" value={pForm.title} onChange={(e) => setPForm({ ...pForm, title: e.target.value })} />
          <select style={inp} value={pForm.departmentId} onChange={(e) => setPForm({ ...pForm, departmentId: e.target.value })}>
            <option value="">Department…</option>{departments.map((d) => <option key={d.id} value={d.id}>{d.code} {d.name}</option>)}
          </select>
          <button style={btn} disabled={!pForm.code || !pForm.title}
            onClick={() => api('/hr/positions', { method: 'POST', body: { code: pForm.code, title: pForm.title, departmentId: pForm.departmentId || null }, entityId }).then(() => { setPForm({ code: '', title: '', departmentId: '' }); load() }).catch((e) => setErr(e.message))}>Add</button>
        </div>
        <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 10 }}>
          <thead><tr><th style={th}>Code</th><th style={th}>Title</th><th style={th}>Department</th><th style={th}>Active</th></tr></thead>
          <tbody>{positions.map((p) => (
            <tr key={p.id}><td style={td}><b>{p.code}</b></td><td style={td}>{p.title}</td><td style={td}>{p.departments?.name ?? ''}</td><td style={td}>{p.active ? 'Yes' : 'No'}</td></tr>
          ))}</tbody>
        </table>
      </div>
    </div>
  )
}

// ------------------------------------------------------------ Payroll
function Payroll({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [runs, setRuns] = useState<Run[]>([])
  const [period, setPeriod] = useState('')
  const [open, setOpen] = useState<RunDetail | null>(null)
  const [advEdit, setAdvEdit] = useState<Record<string, string>>({})
  const load = () => api<Run[]>('/hr/runs', { entityId }).then(setRuns).catch((e) => setErr(e.message))
  useEffect(() => { load(); setOpen(null) }, [entityId])
  const openRun = (id: string) =>
    api<RunDetail>('/hr/runs/' + id, { entityId }).then((r) => { setOpen(r); setAdvEdit({}) }).catch((e) => setErr(e.message))
  const act = (path: string, then?: () => void) =>
    api('/hr/runs/' + open!.id + path, { method: 'POST', body: {}, entityId })
      .then(() => { load(); openRun(open!.id); then?.() }).catch((e) => setErr(e.message))
  const saveAdv = (line: Line) => {
    const v = advEdit[line.id]
    if (v === undefined || +v === +line.advance_recovery) return
    api('/hr/runs/' + open!.id + '/lines/' + line.id, { method: 'PATCH', body: { advanceRecovery: +v || 0 }, entityId })
      .then(() => { load(); openRun(open!.id) }).catch((e) => setErr(e.message))
  }
  return (
    <div>
      <div style={box}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <input style={inp} type="month" value={period} onChange={(e) => setPeriod(e.target.value)} />
          <button style={btn} disabled={!period}
            onClick={() => api<Run>('/hr/runs', { method: 'POST', body: { periodCode: period }, entityId })
              .then((r) => { setPeriod(''); load(); openRun(r.id) }).catch((e) => setErr(e.message))}>Create run</button>
          <span style={{ fontSize: 13, color: '#64748b' }}>One run per entity per month. Generate pulls attendance & incentives from the live staff app.</span>
        </div>
      </div>
      {open && (
        <div style={box}>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
            <b style={{ fontSize: 14 }}>Payroll {open.period_code} ({open.status})</b>
            {open.status === 'draft' && <button style={btn} onClick={() => act('/generate')}>Generate</button>}
            {open.status === 'draft' && <button style={{ ...btn, background: '#854d0e' }} disabled={!open.lines.length} onClick={() => act('/approve')}>Approve</button>}
            {open.status === 'approved' && <button style={{ ...btn, background: '#166534' }} onClick={() => act('/post')}>Post to GL</button>}
            <span style={{ fontSize: 13 }}>Gross <b>{fmt(+open.total_gross)}</b> · Net <b>{fmt(+open.total_net)}</b></span>
            <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} onClick={() => setOpen(null)}>Close</button>
          </div>
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 10 }}>
            <thead><tr>
              <th style={th}>Employee</th><th style={th}>Days</th><th style={th}>Basic</th><th style={th}>HRA</th><th style={th}>Allow.</th><th style={th}>Gross</th>
              <th style={th}>PF</th><th style={th}>ESI</th><th style={th}>PT</th><th style={th}>TDS</th><th style={th}>Incentives</th><th style={th}>Adv. recovery</th><th style={th}>Net</th>
            </tr></thead>
            <tbody>{open.lines.map((l) => (
              <tr key={l.id}>
                <td style={td}><b>{l.employees?.employee_no}</b> {l.employees?.display_name}</td>
                <td style={num}>{Number(l.days_present)}/{l.days_in_month}</td>
                <td style={num}>{fmt(+l.basic)}</td><td style={num}>{fmt(+l.hra)}</td><td style={num}>{fmt(+l.allowances)}</td><td style={num}>{fmt(+l.gross)}</td>
                <td style={num}>{fmt(+l.pf)}</td><td style={num}>{fmt(+l.esi)}</td><td style={num}>{fmt(+l.pt)}</td><td style={num}>{fmt(+l.tds)}</td>
                <td style={num}>{fmt(+l.incentives)}</td>
                <td style={num}>{open.status === 'draft'
                  ? <input style={{ ...inp, width: 90, textAlign: 'right' }} type="number"
                      value={advEdit[l.id] ?? String(+l.advance_recovery || '')}
                      onChange={(e) => setAdvEdit({ ...advEdit, [l.id]: e.target.value })}
                      onBlur={() => saveAdv(l)} />
                  : fmt(+l.advance_recovery)}</td>
                <td style={num}><b>{fmt(+l.net)}</b></td>
              </tr>
            ))}</tbody>
          </table>
          {open.lines.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No lines yet — hit Generate (active employees need a salary structure).</p>}
        </div>
      )}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr><th style={th}>Period</th><th style={th}>Status</th><th style={th}>Total gross</th><th style={th}>Total net</th></tr></thead>
        <tbody>{runs.map((r) => (
          <tr key={r.id} onClick={() => openRun(r.id)} style={{ cursor: 'pointer', background: open?.id === r.id ? '#f8fafc' : undefined }}>
            <td style={td}><b>{r.period_code}</b></td>
            <td style={td}>{r.status === 'posted' ? '✅ posted' : r.status}</td>
            <td style={num}>{fmt(+r.total_gross)}</td><td style={num}>{fmt(+r.total_net)}</td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

// ------------------------------------------------------------ Reports
function Reports({ entityId, setErr }: { entityId: string; setErr: (s: string) => void }) {
  const [period, setPeriod] = useState(new Date().toISOString().slice(0, 7))
  const [rows, setRows] = useState<RegRow[]>([])
  const run = () => api<RegRow[]>('/hr/reports/payroll-register?period=' + period, { entityId }).then(setRows).catch((e) => setErr(e.message))
  useEffect(() => { run() }, [entityId])
  const tot = (k: keyof RegRow) => rows.reduce((s, r) => s + Number(r[k] ?? 0), 0)
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 12, alignItems: 'center' }}>
        <input style={inp} type="month" value={period} onChange={(e) => setPeriod(e.target.value)} />
        <button style={btn} onClick={run}>Run</button>
        <button style={{ ...btn, background: '#e2e8f0', color: '#334155' }} disabled={!rows.length}
          onClick={() => downloadCsv(`payroll-register-${period}`,
            ['Employee no', 'Name', 'Days present', 'Days in month', 'Basic', 'HRA', 'Allowances', 'Gross', 'PF', 'ESI', 'PT', 'TDS', 'Incentives', 'Advance recovery', 'Net', 'Status'],
            rows.map((r) => [r.employee_no, r.employee_name, r.days_present, r.days_in_month, r.basic, r.hra, r.allowances, r.gross, r.pf, r.esi, r.pt, r.tds, r.incentives, r.advance_recovery, r.net, r.status]))}>
          Download CSV</button>
        <span style={{ fontSize: 13 }}>Employees <b>{rows.length}</b> · Gross <b>{fmt(tot('gross'))}</b> · Net <b>{fmt(tot('net'))}</b></span>
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr>
          <th style={th}>Employee</th><th style={th}>Days</th><th style={th}>Basic</th><th style={th}>HRA</th><th style={th}>Allow.</th><th style={th}>Gross</th>
          <th style={th}>PF</th><th style={th}>ESI</th><th style={th}>PT</th><th style={th}>TDS</th><th style={th}>Incentives</th><th style={th}>Adv.</th><th style={th}>Net</th><th style={th}>Status</th>
        </tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.employee_no}>
            <td style={td}><b>{r.employee_no}</b> {r.employee_name}</td>
            <td style={num}>{Number(r.days_present)}/{r.days_in_month}</td>
            <td style={num}>{fmt(+r.basic)}</td><td style={num}>{fmt(+r.hra)}</td><td style={num}>{fmt(+r.allowances)}</td><td style={num}>{fmt(+r.gross)}</td>
            <td style={num}>{fmt(+r.pf)}</td><td style={num}>{fmt(+r.esi)}</td><td style={num}>{fmt(+r.pt)}</td><td style={num}>{fmt(+r.tds)}</td>
            <td style={num}>{fmt(+r.incentives)}</td><td style={num}>{fmt(+r.advance_recovery)}</td><td style={num}><b>{fmt(+r.net)}</b></td><td style={td}>{r.status}</td>
          </tr>
        ))}</tbody>
      </table>
      {rows.length === 0 && <p style={{ fontSize: 13, color: '#94a3b8' }}>No payroll run for this period.</p>}
    </div>
  )
}
