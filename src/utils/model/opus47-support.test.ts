import { afterEach, beforeEach, describe, expect, test } from 'bun:test'
import { readFileSync } from 'fs'
import { resetModelStringsForTestingOnly, resetStateForTests } from '../../bootstrap/state.js'
import { getHardcodedTeammateModelFallback } from '../swarm/teammateModel.js'
import {
  getDefaultOpusModel,
  getMarketingNameForModel,
  getPublicModelDisplayName,
} from './model.js'
import { getModelOptions } from './modelOptions.js'

const PROVIDER_ENV_VARS = [
  'CLAUDE_CODE_USE_BEDROCK',
  'CLAUDE_CODE_USE_VERTEX',
  'CLAUDE_CODE_USE_FOUNDRY',
  'CLAUDE_CODE_USE_OPENAI',
  'ANTHROPIC_API_KEY',
  'ANTHROPIC_DEFAULT_OPUS_MODEL',
  'ANTHROPIC_DEFAULT_SONNET_MODEL',
  'ANTHROPIC_DEFAULT_HAIKU_MODEL',
] as const

const ORIGINAL_ENV = Object.fromEntries(
  PROVIDER_ENV_VARS.map(key => [key, process.env[key]]),
)

describe('formal Opus 4.7 support', () => {
  beforeEach(() => {
    process.env.NODE_ENV = 'test'
    resetStateForTests()
    resetModelStringsForTestingOnly()
    for (const key of PROVIDER_ENV_VARS) {
      delete process.env[key]
    }
    process.env.ANTHROPIC_API_KEY = 'test-key'
  })

  afterEach(() => {
    for (const key of PROVIDER_ENV_VARS) {
      const value = ORIGINAL_ENV[key]
      if (value === undefined) {
        delete process.env[key]
      } else {
        process.env[key] = value
      }
    }
    resetStateForTests()
    resetModelStringsForTestingOnly()
  })

  test('uses Opus 4.7 as the default Opus model on first-party provider', () => {
    expect(getDefaultOpusModel()).toBe('claude-opus-4-7')
    expect(getHardcodedTeammateModelFallback()).toBe('claude-opus-4-7')
  })

  test('shows Opus 4.7 in public display helpers and the /model picker', () => {
    expect(getPublicModelDisplayName('claude-opus-4-7')).toBe('Opus 4.7')
    expect(getPublicModelDisplayName('claude-opus-4-7[1m]')).toBe(
      'Opus 4.7 (1M context)',
    )
    expect(getMarketingNameForModel('claude-opus-4-7')).toBe('Opus 4.7')
    expect(getMarketingNameForModel('claude-opus-4-7[1m]')).toBe(
      'Opus 4.7 (with 1M context)',
    )

    const options = getModelOptions(false)
    expect(options.some(option => option.description.includes('Opus 4.7'))).toBe(
      true,
    )
  })

  test('updates informational prompt copy to reference Opus 4.7', () => {
    const promptSource = readFileSync(
      new URL('../../constants/prompts.ts', import.meta.url),
      'utf8',
    )

    expect(promptSource).toContain("const FRONTIER_MODEL_NAME = 'Claude Opus 4.7'")
    expect(promptSource).toContain("opus: 'claude-opus-4-7'")
    expect(promptSource).toContain('The most recent Claude model family is Claude 4.5/4.7.')
  })
})
