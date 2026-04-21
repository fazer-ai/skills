# fazer-ai/skills

Claude Code marketplace for [fazer.ai](https://fazer.ai) plugins.

This is the discovery point for fazer.ai's Claude Code plugins. Adding
this marketplace is free. Installing any listed plugin requires an
active fazer.ai subscription.

## Plugins

| Name | Description |
| ---- | ----------- |
| [`n8n-agent-kit`](https://github.com/fazer-ai/n8n-agent-kit) | Provision an n8n + Chatwoot + Coolify virtual assistant stack end-to-end on a VPS. |

## Install

### 1. Subscribe

Subscribe to the relevant fazer.ai plan on
[app.fazer.ai](https://app.fazer.ai). The hub then shows you a setup
token bound to your subscription. The token is revoked automatically
if the subscription lapses.

### 2. Configure npm auth

Run the setup CLI (works on Linux, macOS, Windows):

```sh
bunx @fazer-ai/setup <token>
# or npx / pnpm dlx / yarn dlx @fazer-ai/setup <token>
```

Re-run any time to rotate the credential.

### 3. Add this marketplace

```text
/add-marketplace fazer-ai/skills
```

Or in `~/.claude/settings.json`:

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

### 4. Install plugins

```text
/install <plugin-name>@fazer-ai
```

For example:

```text
/install n8n-agent-kit@fazer-ai
```

Or in `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "n8n-agent-kit@fazer-ai": true
  }
}
```

If a plugin fails to install, re-run `bunx @fazer-ai/setup <token>` and
confirm that your subscription is still active at
[app.fazer.ai](https://app.fazer.ai).

## License

The contents of this repository (marketplace metadata and
documentation) are published to support discovery of fazer.ai Claude
Code plugins. Each listed plugin is distributed under its own license,
which you can find in its respective repository.

"fazer.ai" and the associated logos are trademarks of FAZER.AI LTDA.
