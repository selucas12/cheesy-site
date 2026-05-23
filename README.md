# cheesy-site

Marketing site + install script for **Cheesyboy** — control Claude Code from Telegram.

Live at **https://cheesyboy.dev**.

## Contents

| Path | Purpose |
|---|---|
| `index.html` | Landing page |
| `install/index.html` | Post-purchase install instructions (linked from LemonSqueezy receipt) |
| `install.sh` | One-command installer, served at https://cheesyboy.dev/install.sh |
| `thanks.html` | Order confirmation page |
| `cats/`, `sounds/` | Mascot assets |

## Install command

```bash
bash <(curl -fsSL https://cheesyboy.dev/install.sh)
```

Runs preflight (macOS, Node ≥ 18, npm, Claude Code), `npm install -g @selucas12/cheesy`, then hands off to `cheesy init`.

## Deploys

Pushes to `master` auto-deploy to Vercel (project: `cheesyboy/cheesy-site`). No manual `vercel --prod` needed.

## Related

- CLI source: https://github.com/selucas12/cheesy
- npm package: https://www.npmjs.com/package/@selucas12/cheesy
