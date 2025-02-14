# TF2 AFK Manager

An AFK management system for Team Fortress 2 servers.
Original plugin by Rothgar, adjustments by JoinedSenses.
This version includes forwards, natives, and further code cleanup.

## Features

- Automatically detects AFK players based on keyboard/mouse input and observer target changes
- Configurable kick system for AFK players
- Immunity system for admins and privileged players
- Warning messages before kicking AFK players
- API for other plugins to interact with AFK detection
- Forwards for custom handling of AFK events

## ConVars

- `sm_afk_enable` (Default: 1) - Enables/disables the AFK Manager
- `sm_afk_prefix_short` (Default: 0) - Use short prefix ("AFK" vs "AFK Manager") in messages
- `sm_afk_kick_min_players` (Default: 6) - Minimum players required for AFK kicks to be enabled
- `sm_afk_admins_immune` (Default: 1) - Admin immunity level (0=Disabled, 1=Full immunity, 2=Kick immunity)
- `sm_afk_admins_flag` - Admin flag required for immunity (blank = any flag)
- `sm_afk_kick_time` (Default: 120.0) - Time in seconds before kicking AFK players
- `sm_afk_kick_warn_time` (Default: 30.0) - Warning time before kick in seconds

## API

Check `scripting/include/afkmanager.inc`
