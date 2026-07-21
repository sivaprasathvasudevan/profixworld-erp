import { z } from 'zod'

// ---- primitives ----
export const uuid = z.string().uuid()
export const money = z.number().multipleOf(0.01) // numeric(14,2) in DB
export const isoDate = z.string() // 'YYYY-MM-DD' or ISO timestamp

// ---- Phase 1: legal entities ----
export const legalEntitySchema = z.object({
  id: uuid,
  code: z.string().min(1),
  name: z.string().min(1),
  gstin: z.string().length(15).optional(),
  address: z.string().optional(),
  baseCurrency: z.string().default('INR'),
  fiscalYearStart: z.string().optional(), // 'MM-DD'
  active: z.boolean().default(true),
})
export type LegalEntity = z.infer<typeof legalEntitySchema>

export const numberSequenceSchema = z.object({
  entityId: uuid,
  code: z.string().min(1), // e.g. 'SALES_INV'
  prefix: z.string().default(''),
  suffix: z.string().default(''),
  nextNo: z.number().int().nonnegative(),
  padding: z.number().int().min(0).default(5),
  resetPolicy: z.enum(['never', 'yearly', 'monthly']).default('never'),
})
export type NumberSequence = z.infer<typeof numberSequenceSchema>

// ---- header/lines document pattern (backbone rule 3) ----
export const docLineSchema = z.object({
  lineNo: z.number().int().positive(),
  itemId: uuid.nullable(),
  description: z.string().optional(),
  qty: z.number(),
  unitPrice: money,
  discount: money.default(0),
  tax: money.default(0),
  lineAmount: money,
})
export type DocLine = z.infer<typeof docLineSchema>

export const docStatus = z.enum(['draft', 'confirmed', 'posted', 'cancelled'])
export type DocStatus = z.infer<typeof docStatus>

// ---- privilege string: module.function.action (backbone rule 5) ----
export const privilege = z.string().regex(/^[a-z_]+\.[a-z_]+\.[a-z_]+$/)
export type Privilege = z.infer<typeof privilege>

// ---- Phase 6: HR & Payroll ----
export const payrollPeriod = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/) // e.g. '2026-07'

export const salaryStructureSchema = z.object({
  employeeId: uuid,
  basic: money,
  hra: money.default(0),
  allowances: money.default(0),
  pfPercent: z.number().min(0).max(100).default(12),
  esiPercent: z.number().min(0).max(100).default(0.75),
  ptAmount: money.default(200),
  tdsAmount: money.default(0),
})
export type SalaryStructure = z.infer<typeof salaryStructureSchema>

const r2 = (n: number) => Math.round(n * 100) / 100

/**
 * Reference implementation of the payroll line math — mirrors public.generate_payroll in
 * db/supabase/migrations/00000000000008_hr_payroll.sql (keep the two in sync):
 * prorate basic/hra/allowances by days_present/days_in_month (capped at 1),
 * PF % of prorated basic, ESI % of gross only when gross <= 21000, flat PT/TDS,
 * net = gross + incentives - PF - ESI - PT - TDS - advance recovery.
 */
export function computePayrollLine(
  s: { basic: number; hra: number; allowances: number; pfPercent: number; esiPercent: number; ptAmount: number; tdsAmount: number },
  daysPresent: number,
  daysInMonth: number,
  incentives = 0,
  advanceRecovery = 0,
) {
  const factor = Math.min(daysPresent / daysInMonth, 1)
  const basic = r2(s.basic * factor)
  const hra = r2(s.hra * factor)
  const allowances = r2(s.allowances * factor)
  const gross = r2(basic + hra + allowances)
  const pf = r2(basic * s.pfPercent / 100)
  const esi = gross <= 21000 ? r2(gross * s.esiPercent / 100) : 0
  const pt = r2(s.ptAmount)
  const tds = r2(s.tdsAmount)
  const net = r2(gross + incentives - pf - esi - pt - tds - advanceRecovery)
  return { basic, hra, allowances, gross, pf, esi, pt, tds, incentives: r2(incentives), advanceRecovery: r2(advanceRecovery), net }
}

// ---- Phase 8: Asset Management ----
export type DepreciationMethod = 'straight_line' | 'wdv'

export type DepreciableAsset = {
  cost: number
  salvageValue: number
  accumulatedDepreciation: number
  method: DepreciationMethod
  ratePercent: number       // WDV annual rate
  usefulLifeMonths: number  // straight-line life
}

/**
 * Reference implementation of one month of depreciation — mirrors public.generate_depreciation
 * in db/supabase/migrations/00000000000009_assets_dms.sql (keep the two in sync):
 * straight_line: (cost - salvage) / useful_life_months; wdv: (cost - accumulated) * rate%/12;
 * capped so accumulated never exceeds (cost - salvage); zero/negative amounts become 0 (skipped).
 */
export function computeDepreciationMonth(a: DepreciableAsset): number {
  const base = r2(a.cost - a.salvageValue)
  let amount = a.method === 'straight_line'
    ? (a.usefulLifeMonths > 0 ? r2(base / a.usefulLifeMonths) : 0)
    : r2((a.cost - a.accumulatedDepreciation) * (a.ratePercent / 100) / 12)
  if (a.accumulatedDepreciation + amount > base) amount = r2(base - a.accumulatedDepreciation)
  return amount > 0 ? amount : 0
}

/** Monthly projection until fully depreciated (max maxMonths rows) — the asset form's schedule preview. */
export function computeDepreciationSchedule(a: DepreciableAsset, maxMonths = 120) {
  const rows: { monthNo: number; amount: number; accumulatedAfter: number; bookValueAfter: number }[] = []
  const base = r2(a.cost - a.salvageValue)
  let accumulated = a.accumulatedDepreciation
  for (let m = 1; m <= maxMonths && accumulated < base - 0.005; m++) {
    const amount = computeDepreciationMonth({ ...a, accumulatedDepreciation: accumulated })
    if (amount <= 0) break
    accumulated = r2(accumulated + amount)
    rows.push({ monthNo: m, amount, accumulatedAfter: accumulated, bookValueAfter: r2(a.cost - accumulated) })
  }
  return rows
}

/** Disposal math — mirrors public.dispose_asset: book value = cost - accumulated, gain/loss = proceeds - book value. */
export function computeDisposal(cost: number, accumulatedDepreciation: number, proceeds: number) {
  const bookValue = r2(cost - accumulatedDepreciation)
  return { bookValue, gainLoss: r2(proceeds - bookValue) }
}
