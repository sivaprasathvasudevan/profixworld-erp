import { describe, expect, it } from 'vitest'
import { docLineSchema, legalEntitySchema, numberSequenceSchema, privilege } from './index'

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

describe('document line (header/lines backbone rule)', () => {
  it('parses a sane line and rejects sub-paise amounts', () => {
    const ok = docLineSchema.safeParse({ lineNo: 1, itemId: null, qty: 2, unitPrice: 499.5, lineAmount: 999 })
    expect(ok.success).toBe(true)
    const bad = docLineSchema.safeParse({ lineNo: 1, itemId: null, qty: 1, unitPrice: 0.001, lineAmount: 0.001 })
    expect(bad.success).toBe(false)
  })
})
