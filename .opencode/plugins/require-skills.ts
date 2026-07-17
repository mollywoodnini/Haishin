import type { Plugin } from "@opencode-ai/plugin"

/**
 * Haishin Skill Enforcer Plugin
 *
 * Refuses `edit` / `write` on Swift files until the model has loaded the
 * skills that govern the file's category. Skill loads are tracked per
 * session via the `skill` tool's `tool.execute.before` hook.
 */

type Rule = {
  match: RegExp
  requires: string[]
}

const RULES: Rule[] = [
  // Base: every Swift file requires style rules
  { match: /\.swift$/i, requires: ["swift-style"] },

  // ViewModels require MVVM scaffolding knowledge
  { match: /ViewModel\.swift$/i, requires: ["swift-style", "new-feature"] },

  // Test files
  { match: /Tests?\.swift$/i, requires: ["swift-style"] },
  { match: /\/HaishinTests\//i, requires: ["swift-style"] },
]

const loadedSkills = new Map<string, Set<string>>()

function rulesFor(filePath: string): string[] {
  const required = new Set<string>()
  for (const rule of RULES) {
    if (rule.match.test(filePath)) {
      for (const skill of rule.requires) required.add(skill)
    }
  }
  return [...required]
}

function missingSkills(sessionID: string, required: string[]): string[] {
  const loaded = loadedSkills.get(sessionID) ?? new Set<string>()
  return required.filter((s) => !loaded.has(s))
}

const SkillEnforcer: Plugin = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      const { tool, sessionID } = input
      const args = output.args as Record<string, unknown>

      // Track skill loads
      if (tool === "skill") {
        const name = args.name as string | undefined
        if (name) {
          let set = loadedSkills.get(sessionID)
          if (!set) {
            set = new Set<string>()
            loadedSkills.set(sessionID, set)
          }
          set.add(name)
        }
        return
      }

      // Enforce on file-mutating tools
      if (tool !== "edit" && tool !== "write") return

      const filePath = (args.filePath as string) || ""
      if (!filePath) return

      const required = rulesFor(filePath)
      if (required.length === 0) return

      const missing = missingSkills(sessionID, required)
      if (missing.length === 0) return

      throw new Error(
        `BLOCKED: Cannot ${tool} "${filePath}" — load the following skill(s) ` +
          `first via the \`skill\` tool: ${missing.join(", ")}. ` +
          `These skills are the source of truth for the rules that apply to ` +
          `this file. After loading them, retry the ${tool} call.`,
      )
    },
  }
}

export default SkillEnforcer
