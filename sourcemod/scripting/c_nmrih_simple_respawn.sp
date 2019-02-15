#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <adminmenu>
#include <dhooks>

#define SPAWN_GRACE_MAX 99999

TopMenu g_hTopMenu;

Handle g_dhook_allow_late_join_spawning;

ConVar g_hCvarsEnable;
bool g_bEnable = true;
bool g_bFromAdminMenu[MAXPLAYERS + 1];
bool g_bCanRespawn[MAXPLAYERS + 1];

ConVar sv_spawn_grace_objectivecount;
int sv_spawn_grace_objectivecount_default;

ConVar g_hCvarsSpawnTimeLimit;
float g_fSpawnTimeLimit;

public Plugin myinfo =
{
	name		= "NMRiH respawn player",
	author		= "Mostten",
	description	= "NMRiH respawn player",
	version		= "1.0",
	url			= "https://forums.alliedmods.net/showthread.php?p=2548908"
};

public void OnPluginStart(){
	LoadTranslations("nmrih.respawn.phrases");
	RegCmds();
	InitConvars();
	InitAdminMenu();
	HookEvents();
	LoadDHooks();
	return;
}

public void OnMapStart(){
	DHookGamerules(g_dhook_allow_late_join_spawning, true);
	return;
}

public void OnConfigsExecuted(){
	if(g_bEnable){
		sv_spawn_grace_objectivecount.IntValue = SPAWN_GRACE_MAX;
	}
	SetAllCanSpawn(false);
	return;
}

public void OnClientPostAdminCheck(int client){
	SetClientCanSpawn(client, false);
	return;
}

void HookEvents(){
	HookEvent("player_spawn", Event_PlayerSpawn);
	return;
}

void RegCmds(){
	RegAdminCmd("sm_rsp", Command_RespawnMenu, ADMFLAG_GENERIC, "NMRiH respawn menu");
	RegAdminCmd("sm_rspall", Command_RespawnAll, ADMFLAG_GENERIC, "NMRiH respawn all players");
	return;
}

void InitConvars(){
	sv_spawn_grace_objectivecount_default = (sv_spawn_grace_objectivecount = FindConVar("sv_spawn_grace_objectivecount")).IntValue;
	sv_spawn_grace_objectivecount.AddChangeHook(OnConVarChanged);
	sv_spawn_grace_objectivecount_default = sv_spawn_grace_objectivecount.IntValue;
	
	g_hCvarsEnable = CreateConVar("nmrih_simple_respawn_enable", g_bEnable?"1":"0", "Allow users to use the Respawn:1.Enable 0.Disable", 0, true, 0.0, true, 1.0);
	g_hCvarsEnable.AddChangeHook(OnConVarChanged);
	g_bEnable = g_hCvarsEnable.BoolValue;
	
	g_hCvarsSpawnTimeLimit = CreateConVar("nmrih_simple_respawn_time_limit", "1.0", "The next respawn time", 0, true, 0.0, true, 99999.0);
	g_hCvarsSpawnTimeLimit.AddChangeHook(OnConVarChanged);
	g_fSpawnTimeLimit = g_hCvarsSpawnTimeLimit.FloatValue;
	return;
}

void InitAdminMenu(){
	TopMenu topmenu;
	if(LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)){
		OnAdminMenuReady(topmenu);
	}
	return;
}

public void OnAdminMenuReady(Handle aTopMenu){
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
	if(topmenu == g_hTopMenu){
		return;
	}
	g_hTopMenu = topmenu;
	TopMenuObject player_commands = g_hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
	if(player_commands != INVALID_TOPMENUOBJECT){
		g_hTopMenu.AddItem("sm_rsp", AdminMenu_Respawn, player_commands, "sm_rsp", ADMFLAG_GENERIC);
	}
	return;
}

void LoadDHooks(){
	Handle gameconf = LoadGameConfigFile("respawn.nmrih.games");
	if(!gameconf){
		SetFailState("Failed to load respawn.nmrih.games.txt.");
		return;
	}
	int offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_ObjectiveGameRules::FPlayerCanRespawn");
	g_dhook_allow_late_join_spawning = DHookCreate(offset, HookType_GameRules, ReturnType_Bool, ThisPointer_Ignore, DHook_AllowLateJoinSpawning);
	DHookAddParam(g_dhook_allow_late_join_spawning, HookParamType_CBaseEntity);
	
	delete gameconf;
	return;
}

int GameConfGetOffsetOrFail(Handle gameconf, const char[] key){
	int offset = GameConfGetOffset(gameconf, key);
	if(offset == -1){
		delete gameconf;
		SetFailState("Failed to read gamedata offset of %s", key);
	}
	return offset;
}

public void AdminMenu_Respawn(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength){
	switch(action){
		case TopMenuAction_DisplayOption:{
			Format(buffer, maxlength, "%T", "Admin Menu Item", client);
		}
		case TopMenuAction_SelectOption:{
			TopMenuShowToClient(client, true);
		}
	}
	return;
}

public void OnConVarChanged(Handle hConVar, const char[] szOldValue, const char[] szNewValue){
	if(hConVar == g_hCvarsEnable){
		g_bEnable = view_as<bool>(StringToInt(szNewValue));
		if(!g_bEnable){
			sv_spawn_grace_objectivecount.IntValue = sv_spawn_grace_objectivecount_default;
		}
	}else if(hConVar == sv_spawn_grace_objectivecount){
		if(g_bEnable){
			sv_spawn_grace_objectivecount.IntValue = SPAWN_GRACE_MAX;
		}
	}else if(hConVar == g_hCvarsSpawnTimeLimit){
		g_fSpawnTimeLimit = StringToFloat(szNewValue);
	}
	return;
}

public Action Command_RespawnAll(int client, int args){
	if(g_bEnable){
		RespawnAll();
	}
	return Plugin_Handled;
}

public Action Command_RespawnMenu(int client, int args){
	if(g_bEnable && IsValidClient(client)){
		TopMenuShowToClient(client);
	}
	return Plugin_Handled;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool no_broadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(client)){
		if(IsClientCanSpawn(client)){
			int iTokens = GetClientTokens(client);
			SetClientTokens(client, (iTokens > 0)?--iTokens:0);
		}
		SetClientCanSpawn(client, false);
	}
	return;
}

void RespawnClient(int client){
	if(!IsClientCanSpawn(client)){
		SetClientCanSpawn(client, true);
		SetClientTokens(client, GetClientTokens(client) + 1);
		SetClientNextRespawnTime(client, GetGameTime() + g_fSpawnTimeLimit);
	}
	return;
}

bool IsClientCanSpawn(int client){
	return g_bCanRespawn[client];
}

void SetClientCanSpawn(int client, bool enable){
	g_bCanRespawn[client] = enable;
	return;
}

void SetAllCanSpawn(bool enable){
	for(int client = 1; client <= MaxClients; client++){
		SetClientCanSpawn(client, enable);
	}
	return;
}

void RespawnAll(){
	for(int client = 1; client <= MaxClients; client++){
		if(IsValidClient(client) && !IsPlayerAlive(client)){
			RespawnClient(client);
		}
	}
	return;
}

void TopMenuShowToClient(int client, bool fromAdminMenu = false){
	Menu hMenu = new Menu(MenuHandle_RespawnTop);
	if(hMenu){
		char item[32],name[32];
		Format(name, sizeof(name), "%T", "Menu Title", client);
		hMenu.SetTitle(name);
		for(int player = 1; player <= MaxClients; player++){
			if(IsValidClient(player) && !IsPlayerAlive(player)){
				Format(name, sizeof(name), "%N", player);
				Format(item, sizeof(item), "%d", player);
				hMenu.AddItem(item, name);
			}
		}
		Format(name, sizeof(name), "%T", "Menu Item Respawn All", client);
		hMenu.AddItem("-1", name);
		if(fromAdminMenu){
			g_bFromAdminMenu[client] = true;
			hMenu.ExitBackButton = true;
		}else{
			g_bFromAdminMenu[client] = false;
			hMenu.ExitButton = true;
		}
		hMenu.Display(client, MENU_TIME_FOREVER);
	}
	return;
}

public int MenuHandle_RespawnTop(Menu menu, MenuAction action, int client, int select){
	switch(action){
		case MenuAction_Select:{
			char szPlayer[32];
			menu.GetItem(select, szPlayer, sizeof(szPlayer));
			int player = StringToInt(szPlayer);
			if(IsValidClient(player) && !IsPlayerAlive(player)){
				RespawnClient(player);
			}else if(player == -1){
				RespawnAll();
			}
		}
		case MenuAction_Cancel:{
			if(g_hTopMenu && IsValidClient(client) && g_bFromAdminMenu[client]){
				g_hTopMenu.Display(client, TopMenuPosition_LastCategory);
			}
		}
		case MenuAction_End:{
			delete menu;
		}
	}
	return 0;
}

public MRESReturn DHook_AllowLateJoinSpawning(Handle return_handle, Handle params){
	MRESReturn result = MRES_Ignored;
	if(g_bEnable && !DHookIsNullParam(params, 1)){
		int client = DHookGetParam(params, 1);
		if(!DHookGetReturn(return_handle) && IsValidClient(client) && IsClientCanSpawn(client)){
			DHookSetReturn(return_handle, true);
			result = MRES_Override;
		}
	}
	return result;
}

int GetClientTokens(int client){
	return GetEntProp(client, Prop_Send, "m_iTokens");
}

void SetClientTokens(int client, int tokens){
	SetEntProp(client, Prop_Send, "m_iTokens", tokens);
	return;
}

void SetClientNextRespawnTime(int client, float time){
	SetEntPropFloat(client, Prop_Send, "_nextRespawnTime", time);
	return;
}

bool IsValidClient(int client){
	return (0 < client <= MaxClients && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client) && !IsClientSourceTV(client));
}