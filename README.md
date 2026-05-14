# fazer.ai skills for Claude Code

A [Claude Code](https://claude.com/claude-code) marketplace of plugins
built by [fazer.ai](https://fazer.ai).

Adding the marketplace is free. Installing any plugin requires an active
fazer.ai subscription.

## Available plugins

| Name | Description |
| ---- | ----------- |
| `fazer-ai-atendimento` | Sets up a complete AI WhatsApp assistant for your business from scratch, all on your own infrastructure. |
| `fazer-ai-negocio` | Skills for the commercial and operational cycle: custom Chatwoot funnel design, proposal, discovery, case study, call coach, support reporting, and video-based content generation. |
| `fazer-ai-vps` | Skills to operate AI VPS infrastructure: debugging, migration, backup, alerts, deployment, hardening, and observability. |
| `fazer-ai-agentes` | Skills to design, debug, and optimize AI agents: cost, model, prompt, simulation, and transcript debugging. |
| `fazer-ai-skills-dev` | Skills for creating and maintaining Claude Code skills: security auditing, SKILL.md generation following the community standard, automated review loops. |

## Getting started

### 1. Subscribe

Sign up for a plan at [app.fazer.ai](https://app.fazer.ai). You'll get a
setup token tied to your subscription. The token is revoked automatically
if the subscription lapses.

### 2. Configure npm auth

Run the setup CLI once (works on Linux, macOS, and Windows):

```sh
bunx @fazer-ai/setup <token>
```

`npx`, `pnpm dlx`, and `yarn dlx` work too. Re-run any time to rotate the
credential.

### 3. Add this marketplace

In Claude Code:

```text
/add-marketplace fazer-ai/skills
```

Or declare it in `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "fazer-ai": {
      "source": {
        "source": "github",
        "repo": "fazer-ai/skills"
      }
    }
  }
}
```

### 4. Install a plugin

In Claude Code:

```text
/install fazer-ai-atendimento@fazer-ai
```

Or declare it in `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "fazer-ai-atendimento@fazer-ai": true
  }
}
```

## Troubleshooting

If a plugin fails to install:

- Confirm your subscription is active at [app.fazer.ai](https://app.fazer.ai).
- Re-run `bunx @fazer-ai/setup <token>` with a fresh token from the hub.

## Adding a new plugin

See [`docs/plugin-publish-workflow.md`](docs/plugin-publish-workflow.md)
for the plugin-repo checklist, the `descriptions` i18n convention, and
the GitHub Actions template that opens an auto-bump PR against this
repo on each release.

## License

This repository contains only the marketplace metadata and documentation
needed to discover fazer.ai Claude Code plugins. Each plugin is
distributed under its own license.

"fazer.ai" and the associated logos are trademarks of FAZER.AI LTDA.
