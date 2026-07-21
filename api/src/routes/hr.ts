import { Hono } from 'hono'
import { db } from '../db'
import { requirePriv } from '../privileges'
import type { Bindings, Variables } from '../index'

type Env = { Bindings: Bindings; Variables: Variables }

export const hr = new Hono<Env>()

const r2 = (n: number) => Math.round(n * 100) / 100

// ------------------------------------------------------------ masters: departments & positions
hr.get('/departments', requirePriv('hr.masters.read'), async (c) => {
  const { data, error } = await db(c.env).from('departments').select('*')
    .eq('entity_id', c.get('entityId')).order('code')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

hr.post('/departments', requirePriv('hr.masters.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('departments')
    .insert({ entity_id: c.get('entityId'), code: b.code, name: b.name })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

hr.patch('/departments/:id', requirePriv('hr.masters.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('departments')
    .update({ name: b.name, active: b.active })
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId'))
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

hr.get('/positions', requirePriv('hr.masters.read'), async (c) => {
  const { data, error } = await db(c.env).from('positions').select('*, departments(code, name)')
    .eq('entity_id', c.get('entityId')).order('code')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

hr.post('/positions', requirePriv('hr.masters.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('positions')
    .insert({ entity_id: c.get('entityId'), code: b.code, title: b.title, department_id: b.departmentId ?? null })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

hr.patch('/positions/:id', requirePriv('hr.masters.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('positions')
    .update({ title: b.title, department_id: b.departmentId ?? null, active: b.active })
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId'))
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// ------------------------------------------------------------ legacy staff link options
// Read-only list of live staff_members so an employee can be linked to the staff PWA identity.
hr.get('/staff-members', requirePriv('hr.employees.read'), async (c) => {
  const { data, error } = await db(c.env).from('staff_members')
    .select('id, code, name, active').eq('active', true).order('name')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

// ------------------------------------------------------------ employees
const employeePatch = (b: Record<string, unknown>) => ({
  display_name: b.displayName, phone: b.phone ?? null, email: b.email ?? null,
  pan: b.pan ?? null, aadhaar_last4: b.aadhaarLast4 ?? null, uan: b.uan ?? null,
  esi_no: b.esiNo ?? null, bank_account: b.bankAccount ?? null, bank_ifsc: b.bankIfsc ?? null,
  join_date: b.joinDate ?? null, exit_date: b.exitDate ?? null,
  staff_member_id: b.staffMemberId ?? null, active: b.active,
})

hr.get('/employees', requirePriv('hr.employees.read'), async (c) => {
  const { data, error } = await db(c.env).from('employees')
    .select('*, departments(code, name), positions(code, title), branches(branch_no, name)')
    .eq('entity_id', c.get('entityId')).order('employee_no')
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

hr.get('/employees/:id', requirePriv('hr.employees.read'), async (c) => {
  const sb = db(c.env)
  const id = c.req.param('id')
  const [{ data: emp, error }, { data: history }, { data: structure }] = await Promise.all([
    sb.from('employees').select('*, departments(code, name), positions(code, title), branches(branch_no, name)')
      .eq('id', id).eq('entity_id', c.get('entityId')).single(),
    sb.from('employment_history').select('*, departments(code, name), positions(code, title), branches(branch_no, name)')
      .eq('employee_id', id).order('from_date', { ascending: false }),
    sb.from('salary_structures').select('*').eq('employee_id', id).maybeSingle(),
  ])
  if (error) return c.json({ error: error.message }, 404)
  return c.json({ ...emp, history: history ?? [], salary_structure: structure ?? null })
})

hr.post('/employees', requirePriv('hr.employees.write'), async (c) => {
  const b = await c.req.json()
  if (!b.displayName) return c.json({ error: 'displayName required' }, 400)
  const sb = db(c.env)
  const { data: no, error: seqErr } = await sb.rpc('allocate_number', { p_entity: c.get('entityId'), p_code: 'EMP' })
  if (seqErr) return c.json({ error: seqErr.message }, 400)
  const { data, error } = await sb.from('employees')
    .insert({ entity_id: c.get('entityId'), employee_no: no, ...employeePatch(b), active: true })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

hr.patch('/employees/:id', requirePriv('hr.employees.write'), async (c) => {
  const b = await c.req.json()
  const { data, error } = await db(c.env).from('employees')
    .update(employeePatch(b))
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId'))
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// Add an employment-history row: closes the previous open row and updates the
// employee's current position/department/branch snapshot.
hr.post('/employees/:id/history', requirePriv('hr.employees.write'), async (c) => {
  const b = await c.req.json()
  if (!b.fromDate) return c.json({ error: 'fromDate required' }, 400)
  const sb = db(c.env)
  const id = c.req.param('id')
  const { data: emp, error: eErr } = await sb.from('employees').select('id')
    .eq('id', id).eq('entity_id', c.get('entityId')).single()
  if (eErr || !emp) return c.json({ error: eErr?.message ?? 'employee not found' }, 404)

  const dayBefore = new Date(new Date(b.fromDate + 'T00:00:00Z').getTime() - 86400000).toISOString().slice(0, 10)
  const { error: closeErr } = await sb.from('employment_history')
    .update({ to_date: dayBefore }).eq('employee_id', id).is('to_date', null)
  if (closeErr) return c.json({ error: closeErr.message }, 400)

  const { data: row, error } = await sb.from('employment_history')
    .insert({
      employee_id: id, entity_id: c.get('entityId'),
      position_id: b.positionId ?? null, department_id: b.departmentId ?? null, branch_id: b.branchId ?? null,
      from_date: b.fromDate, monthly_salary: b.monthlySalary ?? null, note: b.note ?? null,
    })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)

  const { error: snapErr } = await sb.from('employees')
    .update({ position_id: b.positionId ?? null, department_id: b.departmentId ?? null, branch_id: b.branchId ?? null })
    .eq('id', id)
  if (snapErr) return c.json({ error: snapErr.message }, 400)
  return c.json(row, 201)
})

// Upsert the employee's single active salary structure.
hr.put('/employees/:id/salary-structure', requirePriv('hr.employees.write'), async (c) => {
  const b = await c.req.json()
  const sb = db(c.env)
  const id = c.req.param('id')
  const { data: emp, error: eErr } = await sb.from('employees').select('id')
    .eq('id', id).eq('entity_id', c.get('entityId')).single()
  if (eErr || !emp) return c.json({ error: eErr?.message ?? 'employee not found' }, 404)
  const { data, error } = await sb.from('salary_structures')
    .upsert({
      entity_id: c.get('entityId'), employee_id: id,
      basic: b.basic ?? 0, hra: b.hra ?? 0, allowances: b.allowances ?? 0,
      pf_percent: b.pfPercent ?? 12, esi_percent: b.esiPercent ?? 0.75,
      pt_amount: b.ptAmount ?? 200, tds_amount: b.tdsAmount ?? 0,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'employee_id' })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// ------------------------------------------------------------ payroll runs
hr.get('/runs', requirePriv('hr.payroll.read'), async (c) => {
  const { data, error } = await db(c.env).from('payroll_runs').select('*')
    .eq('entity_id', c.get('entityId')).order('period_code', { ascending: false })
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})

hr.post('/runs', requirePriv('hr.payroll.write'), async (c) => {
  const b = await c.req.json()
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(b.periodCode ?? '')) {
    return c.json({ error: 'periodCode must look like 2026-07' }, 400)
  }
  const { data, error } = await db(c.env).from('payroll_runs')
    .insert({ entity_id: c.get('entityId'), period_code: b.periodCode, created_by: c.get('user').id })
    .select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data, 201)
})

hr.get('/runs/:id', requirePriv('hr.payroll.read'), async (c) => {
  const sb = db(c.env)
  const [{ data: run, error }, { data: lines, error: lErr }] = await Promise.all([
    sb.from('payroll_runs').select('*').eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single(),
    sb.from('payroll_lines').select('*, employees(employee_no, display_name)')
      .eq('run_id', c.req.param('id')),
  ])
  if (error) return c.json({ error: error.message }, 404)
  if (lErr) return c.json({ error: lErr.message }, 500)
  const sorted = (lines ?? []).sort((a, b) =>
    String(a.employees?.employee_no ?? '').localeCompare(String(b.employees?.employee_no ?? '')))
  return c.json({ ...run, lines: sorted })
})

// Regenerate draft lines from salary structures + legacy attendance/incentives (SQL function, one transaction).
hr.post('/runs/:id/generate', requirePriv('hr.payroll.write'), async (c) => {
  const { data, error } = await db(c.env).rpc('generate_payroll', { p_run: c.req.param('id'), p_actor: c.get('user').id })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ lines: data })
})

// Draft-only manual edit: advance recovery. Recomputes the line net and the run totals.
hr.patch('/runs/:id/lines/:lineId', requirePriv('hr.payroll.write'), async (c) => {
  const b = await c.req.json()
  const adv = r2(Number(b.advanceRecovery ?? 0))
  if (!(adv >= 0)) return c.json({ error: 'advanceRecovery must be >= 0' }, 400)
  const sb = db(c.env)
  const runId = c.req.param('id')
  const { data: run, error: rErr } = await sb.from('payroll_runs').select('id, status')
    .eq('id', runId).eq('entity_id', c.get('entityId')).single()
  if (rErr) return c.json({ error: rErr.message }, 404)
  if (run.status !== 'draft') return c.json({ error: `run is ${run.status}, only draft lines can be edited` }, 400)

  const { data: line, error: lErr } = await sb.from('payroll_lines').select('*')
    .eq('id', c.req.param('lineId')).eq('run_id', runId).single()
  if (lErr) return c.json({ error: lErr.message }, 404)
  const net = r2(Number(line.gross) + Number(line.incentives) - Number(line.pf) - Number(line.esi)
    - Number(line.pt) - Number(line.tds) - adv)
  const { error: uErr } = await sb.from('payroll_lines')
    .update({ advance_recovery: adv, net }).eq('id', line.id)
  if (uErr) return c.json({ error: uErr.message }, 400)

  const { data: all, error: aErr } = await sb.from('payroll_lines').select('gross, net').eq('run_id', runId)
  if (aErr) return c.json({ error: aErr.message }, 500)
  const totals = (all ?? []).reduce((s, l) => ({ gross: s.gross + Number(l.gross), net: s.net + Number(l.net) }), { gross: 0, net: 0 })
  const { data: updated, error: tErr } = await sb.from('payroll_runs')
    .update({ total_gross: r2(totals.gross), total_net: r2(totals.net) }).eq('id', runId).select().single()
  if (tErr) return c.json({ error: tErr.message }, 400)
  return c.json(updated)
})

hr.post('/runs/:id/approve', requirePriv('hr.payroll.approve'), async (c) => {
  const sb = db(c.env)
  const { data: run, error: rErr } = await sb.from('payroll_runs').select('id, status')
    .eq('id', c.req.param('id')).eq('entity_id', c.get('entityId')).single()
  if (rErr) return c.json({ error: rErr.message }, 404)
  if (run.status !== 'draft') return c.json({ error: `run is ${run.status}, only draft can be approved` }, 400)
  const { data, error } = await sb.from('payroll_runs').update({ status: 'approved' }).eq('id', run.id).select().single()
  if (error) return c.json({ error: error.message }, 400)
  return c.json(data)
})

// Post to GL (backbone rule 4, one Postgres transaction via the SQL function).
hr.post('/runs/:id/post', requirePriv('hr.payroll.post'), async (c) => {
  const { data, error } = await db(c.env).rpc('post_payroll', { p_run: c.req.param('id'), p_actor: c.get('user').id })
  if (error) return c.json({ error: error.message }, 400)
  return c.json({ voucherId: data })
})

// ------------------------------------------------------------ reports
hr.get('/reports/payroll-register', requirePriv('hr.reports.read'), async (c) => {
  const period = c.req.query('period')
  if (!period) return c.json({ error: 'period query param required (e.g. 2026-07)' }, 400)
  const { data, error } = await db(c.env).rpc('payroll_register', { p_entity: c.get('entityId'), p_period: period })
  if (error) return c.json({ error: error.message }, 500)
  return c.json(data)
})
