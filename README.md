# TF2 AFK Manager

A core AFK detection and tracking engine for Team Fortress 2 servers. It monitors player input (keyboard, mouse, observer changes) and exposes an API that other plugins can use to react to AFK players however they see fit.

Originally by Rothgar, with adjustments by JoinedSenses. This version focuses on pure detection — all action logic (kicking, arena removal, etc.) is delegated to extension plugins.

## What It Does

- Detects idle players based on keyboard/mouse input, chat activity, and spectator camera changes.
- Tracks how long each player has been idle.
- Fires forwards when a player goes AFK and when they become active again.
- Provides an admin immunity system with configurable flag requirements.
- Forces `mp_idledealmethod 0` so the engine's built-in idle handling doesn't interfere.

## ConVars

| ConVar | Default | Description |
|---|---|---|
| `sm_afk_enable` | `1` | Enable or disable the AFK Manager. |
| `sm_afk_check_interval` | `1.0` | How often (in seconds) to check each player's AFK status. Minimum `0.1`. |
| `sm_afk_admins_immune` | `1` | Admin immunity level. `0` = disabled, `1` = full immunity, `2` = kick immunity only. |
| `sm_afk_admins_flag` | `""` | Admin flag required for immunity. Blank = any admin flag qualifies. |

## API

See `scripting/include/afk_manager.inc` for the full API reference.

### Natives

| Native | Description |
|---|---|
| `AFKM_IsClientAFK(client)` | Returns `true` if the client is currently AFK. |
| `AFKM_GetClientAFKTime(client)` | Returns how many seconds the client has been idle, or `-1` if not tracked. |
| `AFKM_GetClientImmunity(client)` | Returns the client's current `AFKImmunity` level. |
| `AFKM_SetClientImmunity(client, type)` | Sets the client's `AFKImmunity` level. |
| `AFKM_GetSpectatorTeam()` | Returns the spectator team number. |

### Forwards

| Forward | Description |
|---|---|
| `AFKM_OnClientStartAFK(client)` | Fired when a client transitions from active to AFK. |
| `AFKM_OnClientEndAFK(client)` | Fired when a client transitions from AFK back to active. |
| `AFKM_OnInitializePlayer(client)` | Fired when a player is being initialized. Return `Plugin_Stop` to grant full immunity. |

### Immunity Levels

| Value | Enum | Meaning |
|---|---|---|
| 0 | `AFKImmunity_None` | No immunity. |
| 1 | `AFKImmunity_Move` | Immune to being moved. |
| 2 | `AFKImmunity_Kick` | Immune to being kicked. |
| 3 | `AFKImmunity_Full` | Fully immune — AFK timer is not even created. |

## Extension Plugins

These companion plugins consume the AFK Manager API to take action on idle players:

- **[TF2 AFK Kick](https://github.com/maxijabase/TF2-AFK-Kick)** — Kicks AFK players after a configurable time.
- **[MGE AFK Manager](https://github.com/maxijabase/MGE-AFK-Manager)** — Removes AFK players from MGE arenas.
