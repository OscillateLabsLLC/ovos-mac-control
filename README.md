# ovos-mac-control

[![Status: Proof of Concept](https://img.shields.io/badge/status-proof%20of%20concept-orange)](https://github.com/OscillateLabsLLC/.github/blob/main/SUPPORT_STATUS.md)

> **Proof of concept: experimental, may change or be abandoned.**

Fast on/off control for a native (ovos-installer) OVOS install on macOS.

`ovos-installer` already ships a per-service launchd helper. This adds the
things it does not: a single all-services toggle, at-a-glance status, log
rotation, an upgrade wrapper with branch support, and a menubar switch.

## Why this exists

The installer's services are LaunchAgents. Turning OVOS off means five
`launchctl bootout` calls with full `gui/<uid>/<label>` paths, and turning it
back on means five more — plus clearing launchd's *disabled* override flag,
which otherwise makes `bootstrap` fail with a bare `Input/output error`.

## Install

```zsh
brew trust --formula oscillatelabsllc/tap/ovos-mac-control
brew install oscillatelabsllc/tap/ovos-mac-control
```

Homebrew requires the trust step for formulae from third-party taps.

Or from a checkout:

```zsh
ln -sf "$PWD/bin/ovosctl" ~/.local/bin/ovosctl
```

`~/.local/bin` must be on your `PATH`.

## Usage

```
ovosctl start           # start every installed service (rotates logs first)
ovosctl stop            # stop everything, waiting for full shutdown
ovosctl restart
ovosctl restart audio   # any of start/stop/restart can target one service
ovosctl toggle          # start if down, stop if up
ovosctl status          # per-service state and pid
ovosctl is-running      # exit 0 if everything is up (for scripts)
ovosctl logs core        # tail a log: core messagebus audio phal listener
ovosctl logs core err    # tail stderr instead
ovosctl say "hello"     # speak through OVOS
ovosctl cli             # OVOS text client
ovosctl upgrade                          # re-run the installer (main)
ovosctl upgrade --branch fix/some-branch # test an installer branch
ovosctl upgrade --keep                   # leave the checkout in ~/ovos-installer
ovosctl conf            # has the installer dropped any hand-maintained config?
ovosctl conf apply      # merge mycroft.conf.overlay.json back into mycroft.conf
```

## Keeping hand-made config across upgrades

The installer rewrites `~/.config/mycroft/mycroft.conf` from its wizard answers
on every run, so anything added by hand (PHAL plugin entries, a G2P plugin, a
different TTS voice) silently disappears. Put those sections in
`~/.config/mycroft/mycroft.conf.overlay.json` instead. `ovosctl upgrade` merges
the overlay back automatically after a successful run, and `ovosctl conf`
tells you at any time whether the live file has drifted from it.

The merge is a deep merge: objects combine key by key, anything else in the
overlay (lists included) replaces the installer's value. `apply` backs up the
live file first as `mycroft.conf.pre-overlay.<timestamp>` and is a no-op when
nothing has drifted. `bin/ovos-conf-merge` is the tool underneath, plain
Python 3 with no dependencies, and takes `--conf PATH` to try it on a copy.

`stop` persists across reboots — OVOS stays off until you run `ovosctl start`.

### Relationship to the installer's `ovos` command

`~/.config/ovos-installer/ovos-launchd.zsh` defines an `ovos` shell function
for per-service control (`ovos restart ovos-audio`). That file is the source of
truth for which services exist and how they are addressed; `ovosctl` sources it
rather than duplicating its tables, so re-running the installer will not put the
two out of sync. Both commands coexist. `ovosctl` adds log rotation and waits
for a full shutdown, for one service or all of them, and accepts short names
(`core`, `audio`) as well as full ones (`ovos-core`).

## GUI (always on)

`ovosctl gui install` writes LaunchAgents for the GUI stack and starts it:

| service           | runs                                                               |
|-------------------|--------------------------------------------------------------------|
| `ovos-gui`        | `ovos-gui-service` from `~/.venvs/ovos-gui`                        |
| `ovos-homescreen` | `ovos-skill-launcher ovos-skill-homescreen.openvoiceos`, same venv |
| `ovos-visage-app` | the native [OVOS Visage](https://github.com/OscillateLabsLLC/ovos-gui-visage) app |
| `ovos-visage`     | the browser Visage server, on port 8766, instead of the app        |

Visage is the native app when it's installed:

```zsh
brew trust --cask oscillatelabsllc/tap/ovos-gui-visage
brew install --cask oscillatelabsllc/tap/ovos-gui-visage
```

To use the browser version instead, set `OVOS_VISAGE_DIR` to an
[ovos-visage](https://github.com/OscillateLabsLLC/ovos-visage) checkout before
`install`. It runs from the checkout's `.venv`, so a branch checked out there is
what the service runs after its next restart. Switching between the two and
re-running `install` removes the other one's LaunchAgent.

Override the other paths with `OVOS_GUI_VENV` and `OVOS_VISAGE_APP`. Labels are
`com.oscillatelabs.<service>`, and logs go to the same folder as OVOS's own.

They are deliberately not part of the OVOS service set: `ovosctl stop` leaves
them up, and they reconnect when the messagebus returns. Control them as a
group with `ovosctl gui start|stop|restart|status|open`, or one at a time by
name (`ovosctl restart visage-app`, `ovosctl logs gui err`). Re-run `install`
after changing a path; a loaded launchd job keeps its old definition. If you
quit the app, it stays closed until `ovosctl gui start`.

## Menubar switch (SwiftBar)

```zsh
brew install --cask swiftbar
ln -sf "$(brew --prefix)/share/ovos-mac-control/ovos.5s.sh" "$(defaults read com.ameba.SwiftBar PluginDirectory)/ovos.5s.sh"
```

From a checkout, link `$PWD/swiftbar/ovos.5s.sh` instead.

Point SwiftBar at a plugin folder on first launch; the command above links into
whichever one you chose. The menu bar shows the OVOS logo on its own when
everything is up, with `n/5` beside it when partially up, and `off` when stopped.

The dropdown has start/stop for everything, plus a submenu per service with
start or stop, restart, and its logs. Each log opens in Console.app, which
updates live and is searchable, or tails in Terminal. The errors entries only
show when that service's `.err` file has something in it. Terminal entries use
SwiftBar's terminal setting, which supports Terminal.app and iTerm.

## Upgrades

`ovosctl upgrade` re-runs `ovos-installer`. It is **interactive and needs
sudo** — the installer prompts through its own TUI.

The upstream one-liner always clones `main` and passes no arguments through, so
`--branch` works by cloning that branch and running its `setup.sh` directly,
which is what the upstream `installer.sh` does after its own clone.

Services are left **stopped** when it finishes, either way — start them with
`ovosctl start` when you want to test.

Three things this wrapper handles that cost real debugging time:

- **A clean `PATH`** is passed to the installer. It builds its own venv with
  whatever `python3` resolves to, and a virtualenv's interpreter early on
  `PATH` makes that fail in `ensurepip` when run as root.
- **`OVOS_VENV_PYTHON` is pinned** to the version the current OVOS venv uses,
  read from its `pyvenv.cfg`. It must be a bare `major.minor` (`3.11`) — the
  value goes straight to an Ansible assertion of `^[0-9]+(\.[0-9]+)?$`, so a
  full interpreter path is rejected.
- **The checkout is cleared with `sudo` when needed.** Ansible runs as root and
  leaves root-owned files in `~/ovos-installer/.ansible`, which a plain `rm -rf`
  as the invoking user cannot remove.

Everything that can fail (sudo, clearing, cloning) happens *before* the
services are stopped, so a failed upgrade does not leave OVOS half-down.

## Notes

- Logs live in `~/.local/state/mycroft/logs` and are rotated at 10MB, keeping 3
  generations. Rotation happens on `start`, the one moment no service is
  mid-write. (These had grown to 260MB unrotated.)
- `ovos-core` unloads its skills before exiting and can take ~15s; `stop` waits
  for the process to actually be gone rather than trusting `bootout` to return.
- In zsh, never name a local variable `path` — it is tied to `PATH`, so a plain
  string assignment silently replaces the command search path.
