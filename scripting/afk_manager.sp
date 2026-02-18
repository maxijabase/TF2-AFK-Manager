#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <autoexecconfig>
#include "include/afk_manager"

#define PLUGIN_VERSION "6.0"

float g_fCheckInterval;

enum {
  OBS_MODE_NONE, 
  OBS_MODE_DEATHCAM, 
  OBS_MODE_FREEZECAM
}

AFKImmunity g_iPlayerImmunity[MAXPLAYERS + 1];

int g_iPlayerUserID[MAXPLAYERS + 1];
int g_iAFKTime[MAXPLAYERS + 1] = { -1, ... };
int iButtons[MAXPLAYERS + 1];
int g_iPlayerTeam[MAXPLAYERS + 1];
int iObserverMode[MAXPLAYERS + 1] = { -1, ... };
int iObserverTarget[MAXPLAYERS + 1] = { -1, ... };
int g_iMapEndTime = -1;
int g_iAdminsImmune = -1;
int g_iSpec_Team = 1;

bool bPlayerAFK[MAXPLAYERS + 1] = { true, ... };
bool g_bClientAFK[MAXPLAYERS + 1];
bool g_bEnabled;

Handle g_hAFKTimer[MAXPLAYERS + 1];

ConVar hCvarIdleDealMethod;
ConVar hCvarEnabled;
ConVar hCvarCheckInterval;
ConVar hCvarAdminsImmune;
ConVar hCvarAdminsFlag;

GlobalForward g_OnInitializePlayer;
GlobalForward g_OnClientStartAFK;
GlobalForward g_OnClientEndAFK;

public Plugin myinfo = {
  name = "[TF2] AFK Manager", 
  author = "ampere, original by Rothgar", 
  description = "Detects and tracks AFK players.", 
  version = PLUGIN_VERSION, 
  url = "http://github.com/maxijabase"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  RegPluginLibrary("afkmanager");
  
  CreateNative("AFKM_SetClientImmunity", Native_SetClientImmunity);
  CreateNative("AFKM_GetClientImmunity", Native_GetClientImmunity);
  CreateNative("AFKM_GetSpectatorTeam", Native_GetSpectatorTeam);
  CreateNative("AFKM_IsClientAFK", Native_IsClientAFK);
  CreateNative("AFKM_GetClientAFKTime", Native_GetClientAFKTime);
  
  g_OnInitializePlayer = new GlobalForward("AFKM_OnInitializePlayer", ET_Event, Param_Cell);
  g_OnClientStartAFK = new GlobalForward("AFKM_OnClientStartAFK", ET_Ignore, Param_Cell);
  g_OnClientEndAFK = new GlobalForward("AFKM_OnClientEndAFK", ET_Ignore, Param_Cell);
  
  return APLRes_Success;
}

public void OnPluginStart() {
  AutoExecConfig_SetCreateFile(true);
  AutoExecConfig_SetFile("afk_manager");
  
  AutoExecConfig_CreateConVar("sm_afk_version", PLUGIN_VERSION, "Current version of the AFK Manager", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
  hCvarEnabled = AutoExecConfig_CreateConVar("sm_afk_enable", "1", "Is the AFK Manager enabled or disabled? [0 = FALSE, 1 = TRUE, DEFAULT: 1]", FCVAR_NONE, true, 0.0, true, 1.0);
  hCvarCheckInterval = AutoExecConfig_CreateConVar("sm_afk_check_interval", "1.0", "How often (in seconds) to check each player's AFK status. [DEFAULT: 1.0]", FCVAR_NONE, true, 0.1);
  hCvarAdminsImmune = AutoExecConfig_CreateConVar("sm_afk_admins_immune", "1", "Should admins be immune to the AFK Manager? [0 = DISABLED, 1 = COMPLETE IMMUNITY, 2 = KICK IMMUNITY]", FCVAR_NONE, true, 0.0, true, 2.0);
  hCvarAdminsFlag = AutoExecConfig_CreateConVar("sm_afk_admins_flag", "", "Admin Flag for immunity? Leave blank for any flag.");
  hCvarIdleDealMethod = FindConVar("mp_idledealmethod");
  
  AutoExecConfig_CleanFile();
  AutoExecConfig_ExecuteFile();
  
  hCvarEnabled.AddChangeHook(CvarChange_Status);
  hCvarCheckInterval.AddChangeHook(CvarChange_Status);
  hCvarIdleDealMethod.AddChangeHook(CvarChange_Status);
  hCvarAdminsImmune.AddChangeHook(CvarChange_Status);
  
  g_fCheckInterval = hCvarCheckInterval.FloatValue;
  g_iAdminsImmune = hCvarAdminsImmune.IntValue;
  
  hCvarIdleDealMethod.SetInt(0);
  
  HookEvent("player_disconnect", Event_PlayerDisconnectPost);
  HookEvent("player_team", Event_PlayerTeam);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_death", Event_PlayerDeathPost);
}

public void OnMapStart() {
  if (!g_bEnabled) {
    return;
  }
  if (g_iMapEndTime == -1) {
    return;
  }
  int iMapChangeTime = GetTime() - g_iMapEndTime;
  for (int i = 1; i <= MaxClients; i++) {
    if (g_iAFKTime[i] != -1) {
      g_iAFKTime[i] = g_iAFKTime[i] + iMapChangeTime;
    }
  }
  g_iMapEndTime = -1;
}

public void OnMapEnd() {
  if (!g_bEnabled) {
    return;
  }
  g_iMapEndTime = GetTime();
}

public void OnClientPostAdminCheck(int client) {
  if (!g_bEnabled) {
    return;
  }
  InitializePlayer(client);
}

public void OnClientDisconnect(int client) {
  UnInitializePlayer(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
  if (!g_bEnabled || !IsClientConnected(client) || IsFakeClient(client) || g_hAFKTimer[client] == null) {
    return Plugin_Continue;
  }

  if (cmdnum <= 0) {
    return Plugin_Handled;
  }

  if (mouse[0] != 0 || mouse[1] != 0) {
    iButtons[client] = buttons;
    MarkClientActive(client);
    return Plugin_Continue;
  }

  if (iButtons[client] == buttons) {
    return Plugin_Continue;
  }

  if (IsClientObserver(client)) {
    if (iObserverMode[client] == -1) {
      iButtons[client] = buttons;
      return Plugin_Continue;
    }
    else if (iObserverMode[client] != 4) {
      iObserverMode[client] = GetEntProp(client, Prop_Send, "m_iObserverMode");
    }
    if ((iObserverMode[client] == 4 && iButtons[client] == buttons) || iButtons[client] == buttons) {
      return Plugin_Continue;
    }
  }
  
  iButtons[client] = buttons;
  MarkClientActive(client);
  return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
  if (g_bEnabled && g_hAFKTimer[client] != null) {
    MarkClientActive(client);
  }
  return Plugin_Continue;
}

public Action Event_PlayerDisconnectPost(Event event, const char[] name, bool dontBroadcast) {
  if (!g_bEnabled) {
    return Plugin_Continue;
  }
  int userID = event.GetInt("userid");
  int client = GetClientOfUserId(userID);
  
  if (0 < client <= MaxClients) {
    UnInitializePlayer(client);
  }
  else {
    for (int i = 1; i <= MaxClients; i++) {
      if (g_iPlayerUserID[i] == userID) {
        UnInitializePlayer(i);
      }
    }
  }
  return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
  if (!g_bEnabled) {
    return Plugin_Continue;
  }
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (client > 0 && IsValidClient(client) && g_hAFKTimer[client] != null) {
    g_iPlayerTeam[client] = event.GetInt("team");
    if (g_iPlayerTeam[client] != g_iSpec_Team) {
      ResetObserver(client);
      MarkClientActive(client);
    }
  }
  return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  if (!g_bEnabled) {
    return Plugin_Continue;
  }
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (client > 0 && IsValidClient(client) && g_hAFKTimer[client] != null) {
    if (g_iPlayerTeam[client] == 0) {
      return Plugin_Continue;
    }
    if (!IsClientObserver(client) && IsPlayerAlive(client) && GetClientHealth(client) > 0) {
      ResetObserver(client);
    }
  }
  return Plugin_Continue;
}

public Action Event_PlayerDeathPost(Event event, const char[] name, bool dontBroadcast) {
  if (!g_bEnabled) {
    return Plugin_Continue;
  }
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (client > 0 && IsValidClient(client) && g_hAFKTimer[client] != null) {
    if (IsClientObserver(client)) {
      iObserverMode[client] = GetEntProp(client, Prop_Send, "m_iObserverMode");
      iObserverTarget[client] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
    }
  }
  return Plugin_Continue;
}

Action Timer_CheckPlayer(Handle timer, int client) {
  if (g_hAFKTimer[client] != timer) {
    return Plugin_Stop;
  }

  if (!g_bEnabled) {
    g_hAFKTimer[client] = null;
    return Plugin_Stop;
  }

  if (!IsClientInGame(client) || (GetEntityFlags(client) & FL_FROZEN)) {
    g_iAFKTime[client]++;
    return Plugin_Continue;
  }

  if (IsClientObserver(client)) {
    int m_iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

    if (iObserverMode[client] == -1) {
      iObserverMode[client] = m_iObserverMode;
      return Plugin_Continue;
    }

    if (iObserverMode[client] != m_iObserverMode) {
      if (iObserverMode[client] == OBS_MODE_DEATHCAM) {
        iObserverMode[client] = m_iObserverMode;
        if (iObserverMode[client] != 7) {
          iObserverTarget[client] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        }
        return Plugin_Continue;
      }
      else if (iObserverMode[client] == OBS_MODE_FREEZECAM) {
        iObserverMode[client] = m_iObserverMode;
        if (iObserverMode[client] != 7) {
          iObserverTarget[client] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        }
        return Plugin_Continue;
      }

      iObserverMode[client] = m_iObserverMode;
      if (iObserverMode[client] != 7) {
        int m_hObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        if (iObserverTarget[client] == client || !IsValidClient(m_hObserverTarget)) {
          iObserverTarget[client] = m_hObserverTarget;
          return Plugin_Continue;
        }
        iObserverTarget[client] = m_hObserverTarget;
      }
      MarkClientActive(client);
      return Plugin_Continue;
    }

    if (iObserverMode[client] != 7) {
      int m_hObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
      if (iObserverTarget[client] != m_hObserverTarget) {
        if (!(!IsValidClient(iObserverTarget[client]) || iObserverTarget[client] == client || !IsPlayerAlive(iObserverTarget[client]))) {
          iObserverTarget[client] = m_hObserverTarget;
          MarkClientActive(client);
          return Plugin_Continue;
        }
        iObserverTarget[client] = m_hObserverTarget;
      }
    }
  }

  if (!bPlayerAFK[client]) {
    bPlayerAFK[client] = true;
    return Plugin_Continue;
  }

  if (!g_bClientAFK[client]) {
    g_bClientAFK[client] = true;
    Forward_OnClientStartAFK(client);
  }

  return Plugin_Continue;
}

void MarkClientActive(int client) {
  bPlayerAFK[client] = false;
  g_iAFKTime[client] = GetTime();
  if (g_bClientAFK[client]) {
    g_bClientAFK[client] = false;
    Forward_OnClientEndAFK(client);
  }
}

void SetPlayerImmunity(int client, int type, bool AFKImmunityType = false) {
  if (AFKImmunityType && (AFKImmunity_None <= view_as<AFKImmunity>(type) <= AFKImmunity_Full)) {
    g_iPlayerImmunity[client] = view_as<AFKImmunity>(type);
    if (g_iPlayerImmunity[client] == AFKImmunity_Full) {
      ResetAFKTimer(client);
    }
    else {
      InitializeAFK(client);
    }
  }
  else if (!AFKImmunityType && (0 <= type <= 2)) {
    switch (type) {
      case 1: {
        g_iPlayerImmunity[client] = AFKImmunity_Full;
        ResetAFKTimer(client);
        return;
      }
      case 2: {
        g_iPlayerImmunity[client] = AFKImmunity_Kick;
      }
      default: {
        g_iPlayerImmunity[client] = AFKImmunity_None;
      }
    }
    InitializeAFK(client);
  }
}

void ResetAFKTimer(int index) {
  g_hAFKTimer[index] = null;
  ResetPlayer(index);
}

void ResetObserver(int index) {
  iObserverMode[index] = -1;
  iObserverTarget[index] = -1;
}

void ResetPlayer(int index) {
  bPlayerAFK[index] = true;
  g_bClientAFK[index] = false;
  g_iPlayerUserID[index] = -1;
  g_iAFKTime[index] = -1;
  g_iPlayerTeam[index] = -1;
  ResetObserver(index);
}

void InitializeAFK(int index) {
  if (g_hAFKTimer[index] == null) {
    g_iAFKTime[index] = GetTime();
    g_iPlayerTeam[index] = GetClientTeam(index);
    g_hAFKTimer[index] = CreateTimer(g_fCheckInterval, Timer_CheckPlayer, index, TIMER_REPEAT);
  }
}

void InitializePlayer(int index) {
  if (!IsValidClient(index)) {
    return;
  }

  if (Forward_OnInitializePlayer(index) != Plugin_Continue) {
    return;
  }

  int iClientUserID = GetClientUserId(index);
  if (iClientUserID != g_iPlayerUserID[index]) {
    ResetAFKTimer(index);
    g_iPlayerUserID[index] = iClientUserID;
  }
  if (g_iAdminsImmune > 0 && g_iPlayerImmunity[index] == AFKImmunity_None && CheckAdminImmunity(index)) {
    SetPlayerImmunity(index, g_iAdminsImmune);
  }
  if (g_iPlayerImmunity[index] != AFKImmunity_Full) {
    InitializeAFK(index);
  }
}

void UnInitializePlayer(int index) {
  ResetAFKTimer(index);
  g_iPlayerImmunity[index] = AFKImmunity_None;
}

void CvarChange_Status(ConVar cvar, const char[] oldvalue, const char[] newvalue) {
  if (StrEqual(oldvalue, newvalue)) {
    return;
  }
  if (cvar == hCvarEnabled) {
    hCvarEnabled.BoolValue ? EnablePlugin() : DisablePlugin();
  }
  else if (cvar == hCvarCheckInterval) {
    g_fCheckInterval = StringToFloat(newvalue);
    for (int i = 1; i <= MaxClients; i++) {
      if (g_hAFKTimer[i] != null) {
        g_hAFKTimer[i] = null;
        g_hAFKTimer[i] = CreateTimer(g_fCheckInterval, Timer_CheckPlayer, i, TIMER_REPEAT);
      }
    }
  }
  else if (cvar == hCvarAdminsImmune) {
    g_iAdminsImmune = StringToInt(newvalue);
    for (int i = 1; i <= MaxClients; i++) {
      if (IsValidClient(i) && CheckAdminImmunity(i)) {
        SetPlayerImmunity(i, g_iAdminsImmune);
      }
    }
  }
  else if (cvar == hCvarIdleDealMethod && StringToInt(newvalue) != 0) {
    cvar.SetInt(0);
  }
}

void EnablePlugin() {
  g_bEnabled = true;
  for (int i = 1; i <= MaxClients; i++) {
    InitializePlayer(i);
  }
}

void DisablePlugin() {
  g_bEnabled = false;
  for (int i = 1; i <= MaxClients; i++) {
    UnInitializePlayer(i);
  }
}

bool IsValidClient(int client) {
  return (IsClientInGame(client) && (0 < client <= MaxClients) && !IsFakeClient(client));
}

bool CheckAdminImmunity(int client) {
  int iUserFlagBits = GetUserFlagBits(client);
  if (iUserFlagBits > 0) {
    char sFlags[32];
    hCvarAdminsFlag.GetString(sFlags, sizeof(sFlags));
    return (StrEqual(sFlags, "") || (iUserFlagBits & (ReadFlagString(sFlags) | ADMFLAG_ROOT) > 0));
  }
  return false;
}

any Native_SetClientImmunity(Handle plugin, int numParams) {
  int iClient = GetNativeCell(1);
  AFKImmunity iImmunityType = GetNativeCell(2);
  
  if (iClient < 1 || iClient > MaxClients) {
    ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", iClient);
  }
  
  if (iImmunityType < AFKImmunity_None || iImmunityType > AFKImmunity_Full) {
    ThrowNativeError(SP_ERROR_NATIVE, "Invalid Immunity Type (%d)", iImmunityType);
  }
  
  SetPlayerImmunity(iClient, view_as<int>(iImmunityType), true);
  return true;
}

any Native_GetClientImmunity(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  
  if (client < 1 || client > MaxClients) {
    ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
  }
  
  return g_iPlayerImmunity[client];
}

any Native_GetSpectatorTeam(Handle plugin, int numParams) {
  return g_iSpec_Team;
}

any Native_IsClientAFK(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  
  if (client < 1 || client > MaxClients) {
    ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
  }
  
  return g_bClientAFK[client];
}

any Native_GetClientAFKTime(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  
  if (client < 1 || client > MaxClients) {
    ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
  }
  
  if (g_iAFKTime[client] == -1) {
    return g_iAFKTime[client];
  }
  
  return (GetTime() - g_iAFKTime[client]);
}

Action Forward_OnInitializePlayer(int client)
{
  Action result = Plugin_Continue;

  Call_StartForward(g_OnInitializePlayer);
  Call_PushCell(client);
  Call_Finish(result);

  return result;
}

void Forward_OnClientStartAFK(int client)
{
  Call_StartForward(g_OnClientStartAFK);
  Call_PushCell(client);
  Call_Finish();
}

void Forward_OnClientEndAFK(int client)
{
  Call_StartForward(g_OnClientEndAFK);
  Call_PushCell(client);
  Call_Finish();
}
