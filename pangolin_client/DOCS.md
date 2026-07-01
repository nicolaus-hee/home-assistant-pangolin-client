# Pangolin Client

Runs the official [Pangolin CLI](https://github.com/fosrl/cli) tunnel client (`pangolin-cli`) in
the background, so Home Assistant Core can reach private [Pangolin](https://pangolin.net) resources
directly by IP, the same way a regular VPN client would give you access.

## Configuration

| Option | Required | Description |
|---|---|---|
| `endpoint` | yes | Base URL of your Pangolin server. |
| `client_id` / `client_secret` | yes | Machine credentials from your Pangolin dashboard (Clients → Machines). Not your personal Pangolin login. |
| `org_id` | no | Only needed if your account has access to more than one organization. |
| `auto_update` | no | Check GitHub for a newer `pangolin-cli` release on every start. |
| `pinned_version` | no | Pin an exact `pangolin-cli` release tag (e.g. `0.10.0`) instead of always using latest. Overrides `auto_update` entirely while set — `auto_update` is then ignored regardless of its own value. |
| `log_level` | no | Verbosity of `pangolin-cli`'s own log output. |

## Permissions

- `host_network` — shares the host's network namespace, so Home Assistant Core can see the
  `pangolin` tunnel interface and its routes.
- `/dev/net/tun` — needed to create that interface.
- `NET_ADMIN` / `NET_RAW` — needed to create the interface and manage routes/DNS.

<!--
## Known limitation: resolving Pangolin aliases by hostname (currently disabled, see run.sh)

Setting `aliases` makes this add-on redirect Home Assistant's internal DNS server's outgoing DNS
queries towards Pangolin's resolver (via an iptables NAT rule), so Pangolin-internal hostnames
*can* be resolved. That redirection mechanism is implemented and verified working end-to-end.

However, getting Home Assistant's Supervisor to actually use that redirected path for ordinary
hostname lookups currently runs into a separate, unrelated bug in Supervisor itself (DNS server
settings not being applied to its DNS server's running configuration). Until that's resolved on
the Supervisor side, resolving Pangolin aliases *by name* from Home Assistant Core does not work,
which is why the option is commented out for now rather than shown as a working feature.

This does **not** affect reaching Pangolin resources by their private tunnel IP address, which
always works.
-->

