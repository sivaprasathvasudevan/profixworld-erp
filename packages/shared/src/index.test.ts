import { describe, expect, it } from 'vitest'
import { computePayrollLine, docLineSchema, legalEntitySchema, numberSequenceSchema, payrollPeriod, privilege } from './index'

describe('privilege codes (module.function.action)', () => {
  it('accepts valid codes', () => {
    expect(privilege.safeParse('sysadmin.entities.write').success).toBe(true)
    expect(privilege.safeParse('gl.journals.post').success).toBe(true)
  })
  it('rejects malformed codes', () => {
    for (const bad of ['sysadmin', 'sysadmin.entities', 'SysAdmin.Entities.Write', 'a.b.c.d', 'a.b.']) {
      expect(privilege.safeParse(bad).success).toBe(false)
    }
  })
})

describe('legal entity schema', () => {
  it('requires code and name, defaults INR', () => {
    const e = legalEntitySchema.parse({ id: '4dc7d896-6c6c-4634-9f8f-4da9c9db984f', code: 'PROFIX', name: 'ProFix World' })
    expect(e.baseCurrency).toBe('INR')
    expect(e.active).toBe(true)
    expect(() => legalEntitySchema.parse({ id: 'x', code: '', name: '' })).toThrow()
  })
  it('validates GSTIN length when present', () => {
    expect(legalEntitySchema.safeParse({ id: '4dc7d896-6c6c-4634-9f8f-4da9c9db984f', code: 'A', name: 'A', gstin: '33ABCDE1234F1Z5' }).success).toBe(true)
    expect(legalEntitySchema.safeParse({ id: '4dc7d896-6c6c-4634-9f8f-4da9c9db984f', code: 'A', name: 'A', gstin: 'short' }).success).toBe(false)
  })
})

describe('number sequence schema', () => {
  it('defaults padding 5 and never-reset', () => {
    const s = numberSequenceSchema.parse({ entityId: '4dc7d896-6c6c-4634-9f8f-4da9c9db984f', code: 'SINV', nextNo: 1 })
    expect(s.padding).toBe(5)
    expect(s.resetPolicy).toBe('never')
  })
})

describe('payroll line math (mirrors generate_payroll SQL)', () => {
  const s = { basic: 12000, hra: 4000, allowances: 2000, pfPercent: 12, esiPercent: 0.75, ptAmount: 200, tdsAmount: 0 }

  it('full month: no proration, PF on basic, ESI on gross under 21000', () => {
    const l = computePayrollLine(s, 31, 31)
    expect(l.gross).toBe(18000)
    expect(l.pf).toBe(1440)          // 12% of 12000
    expect(l.esi).toBe(135)          // 0.75% of 18000
    expect(l.pt).toBe(200)
    expect(l.net).toBe(18000 - 1440 - 135 - 200)
  })

  it('LOP proration caps the factor at 1 and rounds per component', () => {
    const l = computePayrollLine(s, 20, 30)
    expect(l.basic).toBe(8000)
    expect(l.gross).toBe(12000)
    const over = computePayrollLine(s, 35, 30) // more days than the month: capped
    expect(over.gross).toBe(18000)
  })

  it('ESI is zero once gross crosses the 21000 threshold', () => {
    const rich = computePayrollLine({ ...s, basic: 20000, hra: 5000 }, 30, 30)
    expect(rich.gross).toBe(27000)
    expect(rich.esi).toBe(0)
  })

  it('net = gross + incentives - deductions - advance recovery, and the GL balances', () => {
    const l = computePayrollLine(s, 30, 30, 1500, 1000)
    expect(l.net).toBe(l.gross + 1500 - l.pf - l.esi - l.pt - l.tds - 1000)
    // post_payroll voucher: Dr 5200 (gross+incentives) = Cr 2310 (statutory) + Cr 2300 (net) + Cr 2300 (advance recovery)
    const dr = l.gross + l.incentives
    const cr = (l.pf + l.esi + l.pt + l.tds) + l.net + l.advanceRecovery
    expect(Math.abs(dr - cr)).toBeLessThanOrEqual(0.05)
  })

  it('period codes look like YYYY-MM', () => {
    expect(payrollPeriod.safeParse('2026-07').success).toBe(true)
    expect(payrollPeriod.safeParse('2026-13').success).toBe(false)
    expect(payrollPeriod.safeParse('202607').success).toBe(false)
  })
})

describe('document line (header/lines backbone rule)', () => {
  it('parses a sane line and rejects sub-paise amounts', () => {
    const ok = docLineSchema.safeParse({ lineNo: 1, itemId: null, qty: 2, unitPrice: 499.5, lineAmount: 999 })
    expect(ok.success).toBe(true)
    const bad = docLineSchema.safeParse({ lineNo: 1, itemId: null, qty: 1, unitPrice: 0.001, lineAmount: 0.001 })
    expect(bad.success).toBe(false)
  })
})
