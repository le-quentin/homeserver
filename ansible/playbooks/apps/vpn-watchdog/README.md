# VPN watchdog

Stops a gluetun container stuck in a reconnection loop, and warns before a Proton WireGuard key expires
(Proton sends no warning). How and why: see the header of `vpn-watchdog.sh`. Test: `test/check_vpn_watchdog.sh`.

## Uptime Kuma monitors (created by hand)

Create two monitors of type **Push** in Uptime Kuma, and put the token at the end of each push URL
(`/api/push/<token>`) in `inventories/prod/group_vars/vpn-watchdog/secrets.yaml`:

| Monitor | Token variable | Heartbeat interval | Retries | Resend notification if down X times |
|---|---|---|---|---|
| `VPN watchdog` | `vpn_watchdog_kuma_breaker_token` | 300 s | 0 | 0 |
| `VPN keys expiry` | `vpn_watchdog_kuma_expiry_token` | 300 s | 0 | 720 (a reminder a day) |

The watchdog pushes every 2 minutes. `VPN watchdog` goes down when the breaker stops a tunnel, when it
cannot check them, or when the watchdog itself stops pushing (dead container). Attach a notification
to both monitors.

## When it trips

The breaker stops a tunnel at 50 connection attempts in an hour made while internet was reachable (dead,
expired or shared key: a real loop is stopped in ~6 minutes), or at 300 attempts in 3 hours whatever the
internet check says. An ISP outage alone does not trip it, unless it lasts more than ~30 minutes
(gluetun retries ~10 times a minute): then there is nothing to fix, only to restart.

The stopped `*-vpn-client-*` container stays down, with its app. Find the cause in its logs
(`docker logs`), fix it, then restart the app's compose project. The monitor goes back up on the next run.

## When a key is about to expire

Extend it in the Proton dashboard (Downloads > WireGuard configuration > Extend), update
`<app>_vpn_key_expires` in the inventory, deploy this playbook. If Proton gives a new private key, update
`<app>_vpn_private_key` too and redeploy the app.
