# Pangolin Client — Home Assistant Add-on

Runs the official [pangolin-cli](https://github.com/fosrl/cli) tunnel client in the background,
so Home Assistant Core can reach private [Pangolin](https://pangolin.net) resources directly by
IP — the same way a regular VPN client would.

## Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**
2. Click the menu (⋮) in the top right and select **Repositories**
3. Add this URL: `https://github.com/nicolaus-hee/home-assistant-pangolin-client`
4. The **Pangolin Client** add-on will appear in the store — click it and install

Alternatively, copy the `pangolin_client/` folder manually into `/addons/local/` on your Home
Assistant host for a local installation.

## Configuration

| Option | Required | Default | Description |
|---|---|---|---|
| `endpoint` | yes | `https://app.pangolin.net` | Base URL of your Pangolin server. |
| `client_id` | yes | — | Machine credential ID from your Pangolin dashboard (Clients → Machines). |
| `client_secret` | yes | — | Machine credential secret for the Client ID above. |
| `org_id` | no | — | Only needed if your account has access to more than one organization. |
| `auto_update` | no | `true` | Check GitHub for a newer `pangolin-cli` release on every start. |
| `pinned_version` | no | — | Pin an exact `pangolin-cli` release tag (e.g. `0.10.0`). Overrides `auto_update` entirely while set. |
| `log_level` | no | `info` | Verbosity of `pangolin-cli`'s own log output (`debug`, `info`, `warn`, `error`). |

Machine credentials are found and created in the Pangolin dashboard under **Clients → Machines** — not your
personal Pangolin login.

## Requirements

- Home Assistant OS or Supervised
- A running [Pangolin](https://pangolin.net) server with at least one site configured
- Machine credentials (client ID + secret) for that site

## Links

- [pangolin-cli upstream](https://github.com/fosrl/cli)
- [Pangolin](https://pangolin.net)
- [Home Assistant](https://www.home-assistant.io)

---

*This project is not affiliated with or endorsed by Pangolin or the Home Assistant project. Developed with [Claude Code](https://claude.ai/code).*
