# RDP (Remote Desktop)

Connect to Windows, xrdp, and any RDP-compatible remote desktop directly from a YourSSH tab — alongside your SSH sessions.

<!-- SCREENSHOT: RDP workspace tab connected to a Windows desktop -->

## Creating an RDP Host

1. Open the host editor (new host, or edit an existing one).
2. Switch the **SSH / RDP** selector at the top to **RDP**. The port auto-flips to `3389` (a custom port is preserved).
3. Fill in:
   - **Host / Port / Username / Password** — as usual
   - **Domain** — optional Windows domain
   - **Security** — `Auto` (recommended), `NLA`, or `TLS`
   - **SSH tunnel** — optionally route the RDP connection through one of your saved SSH hosts (its full connection chain, including multi-hop bastions, is reused)

RDP hosts show an **RDP badge** on the dashboard, in list rows, and in the host panel header.

## Connecting

Click **Connect** like any host. The first connection shows a **trust dialog** with the server's certificate fingerprint (TOFU — trust on first use).

> **Security note:** the pinned fingerprint is enforced *before* your credentials are sent. If the server's certificate ever changes, the connection aborts pre-authentication and you're asked to re-trust explicitly — your password never reaches an unverified server.

## Using the Desktop

- **Keyboard** — all printable keys, function keys, arrows; app hotkeys are swallowed so they don't also type into the remote desktop. Use the toolbar button for **Ctrl+Alt+Del**.
- **Mouse** — left/right/middle click, vertical + horizontal scroll; coordinates scale with the window.
- **Clipboard** — bidirectional. Copy on the remote side lands in your local clipboard; the local clipboard is pushed when the RDP view gains focus.
- **Resolution** — the requested size follows your window; if the server negotiates a different size the view adapts.

## Fullscreen

Press the **fullscreen** button in the toolbar (enabled while connected). All app chrome disappears.

To exit, move the mouse to the **top screen edge** — an mstsc-style pill appears (it also flashes for a moment when entering fullscreen) with Ctrl+Alt+Del / clipboard / exit / disconnect. The app automatically drops back to windowed mode if the session disconnects or you switch tabs.

## Disconnects

If the remote side ends the session (you signed out, another client took over the session, or an admin disconnected you), the tab shows a clean "server ended the session" message with a **Retry** button. Unexpected drops also land in the notification bell, and connects/disconnects are written to the [Audit Log](User-Guide-Audit-Log).

## Tab Parity with SSH

Rename, color tags, and pinning work on RDP tabs and persist across restarts. RDP tabs are restored on relaunch like SSH tabs.

## What's Not Supported (yet)

- Audio redirection
- Drive / printer redirection
- Dynamic resize while connected (reconnect applies the new size)
- Recording, split view, input bar, and snippets are SSH-only features and are hidden for RDP tabs
