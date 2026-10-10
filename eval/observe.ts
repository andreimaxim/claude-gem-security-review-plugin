import type { Register } from 'claude-code'

// Only added to the evaluation copy. Does not change models, effort or tools.
export const register: Register = (on) => {
  on('turn.step', ($, e, next) => {
    $.ui.log(`GEM_UPGRADE_EVAL_STEP ${JSON.stringify({
      turnId: e.turnId,
      index: e.index,
      agentId: e.agentId ?? null,
      model: e.model,
      effort: e.effort ?? null,
    })}`)
    return next(e)
  })
}
