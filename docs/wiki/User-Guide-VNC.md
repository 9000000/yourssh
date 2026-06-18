# VNC (Virtual Network Computing)

Connect to Linux VNC servers — **TigerVNC**, **x11vnc**, **TightVNC** — directly from a YourSSH tab, alongside your SSH and RDP sessions.

<!-- SCREENSHOT: VNC workspace tab connected to a Linux desktop -->

## Creating a VNC Host

1. Open the host editor (new host, or edit an existing one).
2. Switch the **SSH / RDP / VNC** selector at the top to **VNC**. The port auto-flips to `5900` (a custom port is preserved).
3. Fill in:
   - **Host / Port / Password** — the password is the VNC server password (VNC Authentication). A username is accepted but ignored by most VNC-auth servers.
   - **SSH tunnel** — optionally route the VNC connection through one of your saved SSH hosts (its full connection chain, including multi-hop bastions, is reused).

VNC hosts show a **VNC badge** on the dashboard, in list rows, and in the host panel header.

## Connecting

Click **Connect** like any host.

> **Security note:** plain VNC has **no TLS/encryption layer** — there is no certificate trust dialog because there is no certificate. Raw VNC traffic (including the password challenge) is unencrypted on the wire. For anything beyond a trusted LAN, set an **SSH tunnel** on the host so the session rides inside an encrypted SSH connection.

## Using the Desktop

- **Keyboard** — printable keys, modifiers, and common navigation/function keys mapped to X11 keysyms; app hotkeys are swallowed so they don't also type into the remote desktop.
- **Mouse** — left/right/middle click and scroll; coordinates scale with the window into the server's framebuffer space.
- **Clipboard** — bidirectional (`ServerCutText` / `ClientCutText`). Remote copies land in your local clipboard; the local clipboard is pushed when the VNC view gains focus.
- **Resolution** — the desktop renders at the server's framebuffer size; if the server resizes (e.g. `SetDesktopSize`), the view adapts automatically.

## Fullscreen

Press the **fullscreen** button in the toolbar (enabled while connected). All app chrome disappears.

To exit, move the mouse to the **top screen edge** — an mstsc-style pill appears (it also flashes for a moment when entering fullscreen) with exit / disconnect. The app automatically drops back to windowed mode if the session disconnects or you switch tabs.

## Disconnects

If the connection drops or the server closes it, the tab shows a clean message with a **Retry** button. Unexpected drops also land in the notification bell, and connects/disconnects are written to the [Audit Log](User-Guide-Audit-Log) (source `vnc`).

## Tab Parity with SSH

Rename, color tags, and pinning work on VNC tabs and persist across restarts. VNC tabs are restored on relaunch like SSH and RDP tabs.

## What's Not Supported (yet)

- TLS / VeNCrypt auth, macOS Screen Sharing / Apple Remote Desktop (DH-based) auth, RealVNC RA2, UltraVNC MS-Logon — the first release targets Linux VNC servers with None / VNC-password auth
- Audio redirection and file transfer
- Recording, split view, input bar, and snippets are SSH-only features and are hidden for VNC tabs
