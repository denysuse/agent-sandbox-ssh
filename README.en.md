# SSH Into Your AI Agent's Sandbox Computer

Scripts + guide for opening SSH access from your machine into an **AI
agent's sandbox computer** (e.g. a personal agent running on a platform
like Cue by Manus) when that sandbox:

- has no public IP address (link-local only),
- accepts no inbound connections from the internet,
- has its password login locked,

…so plain SSH is impossible. The fix: meet both machines inside a private
**Tailscale** network (WireGuard), then SSH as usual inside it.

Distilled from a real, end-to-end verified case (2 Nov 2026): an agent
reachable only by email got working SSH access in one evening, and its
sandbox (Ubuntu 24.04, 8 vCPU, 23 GiB RAM) immediately took on real work —
installing a JDK + Android SDK and running builds.

Full guide (Indonesian): [README.md](README.md)

## How it works

```
Operator machine                                Agent sandbox
────────────────                                ─────────────
ssh -i dedicated-key ──► private tailnet ──► WireGuard tunnel ──► sshd :22
                         (coordination server     (no public        authorized_keys
                          only introduces peers)   ports opened)    = your public key
Result: a shell on the agent's computer.
```

Traffic is end-to-end encrypted between devices; the coordination server
never sees the content.

## Quick start

1. Generate a dedicated key pair:
   `ssh-keygen -t ed25519 -f ~/.ssh/agent-access -C "operator-to-agent-sandbox"`
2. Inside the sandbox, run:
   `OPERATOR_PUBKEY="ssh-ed25519 AAAA... " bash scripts/target-setup.sh`
3. In the sandbox run `sudo tailscale up`; the **owner personally** opens
   the login URL and approves the device. Join the operator machine to the
   same tailnet.
4. Connect:
   `TARGET_IP=100.x.x.x bash scripts/connect.sh "hostname; nproc"`
5. Send files as one checksum-verified archive:
   `TARGET_IP=100.x.x.x bash scripts/send-files.sh ./project /home/ubuntu/project`

## Files

| File | Purpose |
| --- | --- |
| `scripts/target-setup.sh` | Sandbox side: environment checks, Tailscale install, public-key install, sshd check |
| `scripts/connect.sh` | Operator side SSH with a long timeout + one automatic retry |
| `scripts/ts-connect.py` | ProxyCommand helper for environments that must egress through an HTTP proxy |
| `scripts/send-files.sh` | One-archive, SHA-256-verified folder transfer |
| `templates/email-ke-agen.md` | Step-by-step instruction email for email-only agents (Indonesian) |

## Hard-won lessons

- **Short timeouts lie.** The first connection to a new tailnet address can
  stall waiting for the owner's address approval; use a long
  `ConnectTimeout` (we use 280s) and retry once.
- **Ping proves nothing** — ICMP may not traverse proxy/relay paths. A
  successful SSH login is the only real proof.
- **Per-file transfers crawl** over high-latency relays; one `tar.gz` plus
  a SHA-256 check on both ends is faster and safer.
- **A cautious agent is a good agent.** In the real case the agent refused
  to install a public key until the owner's specific approval was relayed.
  Design your flow with explicit approval stages.
- **Ask about persistence early.** If the sandbox is discarded after each
  session, none of this setup survives.

## Alternatives to Tailscale

- **Headscale** — self-hosted, open-source reimplementation of the
  Tailscale coordination server; same clients, your own server.
- **Plain reverse SSH tunnel** — the sandbox dials out to your own public
  server and opens a reverse port. No third party at all; you manage keys
  and keepalives yourself.

## License

MIT — see [LICENSE](LICENSE).
