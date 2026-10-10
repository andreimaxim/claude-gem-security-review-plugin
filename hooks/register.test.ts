import { expect, test } from 'claude-code/testing'

test('rejects an incomplete version-change request', async ($) => {
  const result = await $.tool.call({
    tool: 'mcp__gem-upgrade__research',
    gem: 'faraday',
    currentVersion: ' ',
    requestedVersion: '2.14.4',
  })

  expect(result.deny).toBe('Supply gem, currentVersion, and requestedVersion as nonempty strings.')
})

test('does not claim research started when a hook returns no worker identity', async ($, on) => {
  on('agent.spawn', () => ({ model: 'opus' }))

  const result = await $.tool.call({
    tool: 'mcp__gem-upgrade__research',
    gem: 'faraday',
    currentVersion: '2.14.2',
    requestedVersion: '2.14.4',
  })

  expect(result.deny).toBe('The research subagent did not start.')
})

test('reports a refused spawn instead of claiming research started', async ($, on) => {
  on('agent.spawn', () => ({ deny: 'Blocked by policy.' }))

  const result = await $.tool.call({
    tool: 'mcp__gem-upgrade__research',
    gem: 'faraday',
    currentVersion: '2.14.2',
    requestedVersion: '2.14.4',
  })

  expect(result.deny).toBe('Blocked by policy.')
})

test('delivers a researcher report to the main session without forwarding other agents or looping', async ($, on) => {
  const prompts: string[] = []
  on('agent.list', () => ({ value: [
    { id: 'research-1', type: 'gem-upgrade:researcher', spawnedBy: 'gem-upgrade', description: 'Research faraday 2.14.2 → 2.14.4', status: 'completed' },
    { id: 'other-agent', type: 'Explore', description: 'Explore the application', status: 'completed' },
    { id: 'other-plugin', type: 'gem-upgrade:researcher', spawnedBy: 'another-plugin', description: 'Another request', status: 'completed' },
  ] }))
  on('prompt.submit', ($, e) => {
    prompts.push(e.text)
    return { text: e.text }
  })
  on('turn.complete', ($, e) => ({ text: e.answer }))

  for (const agentId of ['other-agent', 'other-plugin', 'research-1', undefined]) {
    await $.turn.complete({
      agentId,
      turnId: `turn-${agentId}`,
      reason: 'answer',
      isAborted: false,
      durationMs: 100_000,
      answer: 'Release changes and application impact: https://example.com/releases',
    })
  }

  expect(prompts).toEqual([
    'Research faraday 2.14.2 → 2.14.4 completed.\n\nRelease changes and application impact: https://example.com/releases',
  ])
})

test('reports a research failure but does not restart the main session after cancellation', async ($, on) => {
  const prompts: string[] = []
  on('agent.list', () => ({ value: [
    { id: 'research-1', type: 'gem-upgrade:researcher', spawnedBy: 'gem-upgrade', description: 'Research rack 3.2.6 → 3.2.7', status: 'failed' },
  ] }))
  on('prompt.submit', ($, e) => {
    prompts.push(e.text)
    return { text: e.text }
  })
  on('turn.complete', ($, e) => ({ text: e.answer }))

  await $.turn.complete({
    agentId: 'research-1', turnId: 'cancelled', reason: 'aborted', isAborted: true,
    durationMs: 1_000, answer: 'Incomplete research.',
  })
  expect(prompts).toEqual([])

  await $.turn.complete({
    agentId: 'research-1', turnId: 'failed', reason: 'error', isAborted: false,
    durationMs: 1_000, answer: 'The provider is unavailable.',
  })
  expect(prompts).toEqual([
    'Research rack 3.2.6 → 3.2.7 failed (error); no completed report.\n\nThe provider is unavailable.',
  ])
})
