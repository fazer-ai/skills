# fazer-ai/skills

Claude Code marketplace for [fazer.ai](https://fazer.ai) plugins.

This repository is a public discovery point. It lists the plugins
published by fazer.ai and where to install them from. The plugin
artifacts themselves live in the fazer.ai private npm registry
(`https://npm.fazer.ai/`) and require an active subscription to install.

## Plugins

| Name | Description |
| ---- | ----------- |
| [`n8n-agent-kit`](https://github.com/fazer-ai/n8n-agent-kit) | Provision an n8n + Chatwoot + Coolify virtual assistant stack end-to-end on a VPS. |

New plugins are added to this marketplace as they ship.

## Install

Step-by-step for end users:

### 1. Subscribe

Subscribe to the relevant fazer.ai plan on
[app.fazer.ai](https://app.fazer.ai). The app issues an npm credential
(username + secret) bound to your subscription. The credential is
revoked automatically if the subscription lapses.

### 2. Configure npm auth

Add to `~/.npmrc`, replacing `<auth>` with
`base64(<your-user>:<your-secret>)`:

```ini
@fazer-ai:registry=https://npm.fazer.ai/
//npm.fazer.ai/:_auth=<auth>
```

Generate the auth blob with:

```bash
echo -n 'your-user:your-secret' | base64 -w0
```

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

Adding the marketplace is public and does not grant access to any plugin.
Installation still requires the npm credential from step 2.

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

If `bun` or `npm` cannot resolve `@fazer-ai/<plugin>`, double-check that
`~/.npmrc` has the correct auth blob and that your subscription is
active.

## Publishing a new plugin (internal)

Each plugin lives in its own repository and is published to the private
registry as `@fazer-ai/<plugin-name>`. Adding it to this marketplace is
a two-step process:

1. Publish the plugin to `npm.fazer.ai` (see the plugin repo's release
   workflow).
2. Open a PR in this repo bumping `plugins[]` in
   `.claude-plugin/marketplace.json` with the new entry or version.

For now the version in this marketplace is pinned per plugin for
reproducible installs. A later iteration may automate the PR step from
each plugin's release workflow.

## License

The contents of this repository (marketplace metadata and documentation)
are published to support discovery of fazer.ai Claude Code plugins.
Each listed plugin is distributed under its own license, which you can
find in its respective repository.

"fazer.ai" and the associated logos are trademarks of FAZER.AI LTDA.
