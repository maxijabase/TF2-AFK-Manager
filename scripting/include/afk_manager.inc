#if defined _afkmanager_included
#endinput
#endif
#define _afkmanager_included

/**
 * Specifies AFK immunity types.
 */
enum AFKImmunity
{
  AFKImmunity_None = 0, 
  AFKImmunity_Move = 1, 
  AFKImmunity_Kick = 2, 
  AFKImmunity_Full = 3, 
};

/**
 * Sets the AFK immunity type of the client index.
 *
 * @param client  The client index of the player whose immunity type is being set.
 * @param type    The client AFK immunity type.
 * @error         The client index is invalid or AFK immunity type is invalid.
 */
native void AFKM_SetClientImmunity(int client, AFKImmunity type);

/**
 * Gets the AFK immunity type of the client index.
 *
 * @param client  The client index of the player being checked.
 * @return        The client's current AFKImmunity value.
 * @error         The client index is invalid.
 */
native AFKImmunity AFKM_GetClientImmunity(int client);

/**
 * Gets the current AFK spectator team number.
 *
 * @noparam
 * @return        The spectator team number.
 * @noerror
 */
native int AFKM_GetSpectatorTeam();

/**
 * Gets the current AFK status of the client index.
 * Returns true if the player has been idle long enough to be flagged AFK.
 *
 * @param client  The client index of the player being checked.
 * @return        True if client is AFK, false otherwise.
 * @error         The client index is invalid.
 */
native bool AFKM_IsClientAFK(int client);

/**
 * Gets the current AFK time in seconds of the client index. If the client
 * has an invalid AFK time -1 will be returned.
 *
 * Examples of clients who would have invalid AFK time values:
 *    Admins with full immunity.
 *    Disconnected clients.
 *    Bots, Fake Clients or Source TV.
 *
 * @param client  The client index of the player being checked.
 * @return        The client's AFK time in seconds, or -1 if not tracked.
 * @error         The client index is invalid.
 */
native int AFKM_GetClientAFKTime(int client);

/**
 * Called when an AFK InitializePlayer() fires.
 *
 * @param client  The client index of the client in the event.
 * @return        Plugin_Stop to stop creating AFK Timer (Full Immunity), any other value for default behavior.
 */
forward Action AFKM_OnInitializePlayer(int client);

/**
 * Called when a client transitions from active to AFK.
 * Fires once per idle transition, within ~1 second of the player going idle.
 *
 * @param client  The client index of the player who went AFK.
 * @noreturn
 */
forward void AFKM_OnClientStartAFK(int client);

/**
 * Called when a client transitions from AFK back to active.
 * Fires once per active transition, as soon as input is detected.
 *
 * @param client  The client index of the player who is no longer AFK.
 * @noreturn
 */
forward void AFKM_OnClientEndAFK(int client);

public SharedPlugin __pl_afkmanager = 
{
  name = "afkmanager", 
  file = "afkmanager.smx", 
  #if defined REQUIRE_PLUGIN
  required = 1
  #else
  required = 0
  #endif
};

#if !defined REQUIRE_PLUGIN
public __pl_afkmanager_SetNTVOptional()
{
  MarkNativeAsOptional("AFKM_SetClientImmunity");
  MarkNativeAsOptional("AFKM_GetClientImmunity");
  MarkNativeAsOptional("AFKM_GetSpectatorTeam");
  MarkNativeAsOptional("AFKM_IsClientAFK");
  MarkNativeAsOptional("AFKM_GetClientAFKTime");
}
#endif
