import type { Plugin } from "@opencode-ai/plugin"

/**
 * Haishin Guardrails Plugin
 *
 * - Blocks access to sensitive files (secrets, credentials, keys)
 * - Blocks destructive bash commands
 * - Reminds the model to verify Swift edits against skills
 */
const Guardrails: Plugin = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      const { tool } = input
      const args = output.args as Record<string, unknown>

      // Block sensitive file access
      if (tool === "read" || tool === "write" || tool === "edit") {
        const filePath = (args.filePath as string) || ""
        const sensitivePatterns = [
          /\.env$/i,
          /\.env\..+$/i,
          /credentials\.json$/i,
          /secrets?\.(json|yaml|yml|plist)$/i,
          /api[_-]?keys?\.(json|yaml|yml|plist)$/i,
          /private[_-]?key/i,
          /\.pem$/i,
          /\.p12$/i,
        ]

        for (const pattern of sensitivePatterns) {
          if (pattern.test(filePath)) {
            throw new Error(
              `BLOCKED: Cannot ${tool} sensitive file "${filePath}". ` +
                `If you genuinely need to modify this file, ask the user to do it manually.`,
            )
          }
        }
      }

      // Block dangerous bash commands
      if (tool === "bash") {
        const command = (args.command as string) || ""
        const dangerousPatterns = [
          /rm\s+-rf\s+[\/~]/,
          />\s*\/dev\/sd[a-z]/,
          /mkfs\./,
          /dd\s+if=/,
        ]

        for (const pattern of dangerousPatterns) {
          if (pattern.test(command)) {
            throw new Error(`BLOCKED: Dangerous command: "${command}".`)
          }
        }
      }
    },

    "tool.execute.after": async (input, output) => {
      const { tool } = input
      const args = output.args as Record<string, unknown>

      if (tool === "write" || tool === "edit") {
        const filePath = (args.filePath as string) || ""

        if (filePath.endsWith(".swift")) {
          const existingMetadata = (output.metadata as Record<string, unknown>) ?? {}
          output.metadata = {
            ...existingMetadata,
            skillsReminder:
              `Verify ${filePath} against the swift-style and new-feature ` +
              `skills before continuing.`,
          }
        }
      }
    },
  }
}

export default Guardrails
