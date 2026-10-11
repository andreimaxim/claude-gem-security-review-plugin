import type { Register } from 'claude-code'

export const register: Register = (on) => {
  on('session.start', async ($, e, next) => {
    await $.agent.register({
      name: 'researcher',
      description: 'Research a Ruby gem version change and its application impact.',
      prompt: await $.fs.read(`${$.plugin.root}/prompts/research.md`),
      model: 'claude-opus-5-5',
      effort: 'low',
      tools: ['Read', 'Glob', 'Grep', 'WebSearch', 'WebFetch'],
    })
    await $.tool.register({
      name: 'research',
      description: 'Research a Ruby gem upgrade before applying it. Starts a read-only subagent whose source-linked report of release changes, application impact, required adaptations, and validation needs arrives in a follow-up message. Wait for that report before making upgrade decisions.',
      inputSchema: {
        type: 'object',
        properties: {
          gem: { type: 'string', minLength: 1, description: 'Ruby gem name.' },
          currentVersion: { type: 'string', minLength: 1, description: 'Exact current gem version.' },
          requestedVersion: { type: 'string', minLength: 1, description: 'Exact version to research upgrading to.' },
        },
        required: ['gem', 'currentVersion', 'requestedVersion'],
        additionalProperties: false,
      },
    })
    return next(e)
  })

  on('agent.offer', { agent: 'gem-upgrade:researcher' }, () => ({ isOffered: false }))

  on('tool.call', { tool: 'mcp__gem-upgrade__research' }, async ($, e) => {
    const { gem, currentVersion, requestedVersion } = e
    if (![gem, currentVersion, requestedVersion].every(value => typeof value === 'string' && value.trim())) {
      return { deny: 'Supply gem, currentVersion, and requestedVersion as nonempty strings.' }
    }
    const spawned = await $.agent.spawn({
      subagentType: 'gem-upgrade:researcher',
      description: `Research ${gem} ${currentVersion} → ${requestedVersion}`,
      prompt: `Gem: ${gem}\nCurrent version: ${currentVersion}\nRequested version: ${requestedVersion}`,
    })
    if (spawned.deny || !spawned.agentId) {
      return { deny: spawned.deny || 'The research subagent did not start.' }
    }
    return {
      result: `Research started for ${gem} ${currentVersion} → ${requestedVersion} (agent ${spawned.agentId}). The report will arrive in a follow-up message; this acknowledgement is not a research result.`,
    }
  }).catch(($, e, next) => ({ deny: `Research tool failed: ${next.error.message ?? next.error.kind}` }))

  on('turn.complete', async ($, e, next) => {
    if (!e.agentId || e.reason === 'aborted') return next(e)

    const agent = (await $.agent.list()).find(agent =>
      agent.id === e.agentId && agent.type === 'gem-upgrade:researcher' && agent.spawnedBy === $.plugin.name)
    if (!agent) return next(e)

    const outcome = e.reason === 'answer' && e.answer.trim()
      ? 'completed'
      : `failed (${e.reason}); no completed report`
    // Submission waits for the main loop to be idle; do not hold completion open.
    void $.prompt.submit({ text: `${agent.description} (agent ${agent.id}) ${outcome}.\n\n${e.answer}` })
      .catch(error => $.ui.log(`Could not deliver research report: ${String(error)}`))
    return next(e)
  })
}
