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
