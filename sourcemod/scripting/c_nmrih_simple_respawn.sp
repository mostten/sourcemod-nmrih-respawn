#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <adminmenu>

#define SPAWN_GRACE_MAX 99999

TopMenu g_hTopMenu;

ConVar g_hCvarsEnable;
bool g_bEnable = true;
bool g_bFromAdminMenu[MAXPLAYERS + 1];
bool g_bCanRespawn[MAXPLAYERS + 1];

ConVar sv_spawn_grace_objectivecount;
int sv_spawn_grace_objectivecount_default;

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
	if(IsValidClient(client))
		SetClientCanSpawn(client, false);
}

bool RespawnClient(int client){
	if(!IsClientCanSpawn(client)){
		int state = GetGameStateEntity();
		if(IsValidEntity(state)){
			SetVariantString("!activator");
			return AcceptEntityInput(state, "RespawnPlayer", client);
		}
	}
	return false;
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

bool RespawnAll(){
	int state = GetGameStateEntity();
	if(IsValidEntity(state))
		return AcceptEntityInput(state, "RespawnAllPlayers");
	return false;
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

bool IsValidClient(int client){
	return (0 < client <= MaxClients && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client) && !IsClientSourceTV(client));
}

int GetGameStateEntity(){
	int nmrih_game_state = -1;
	while((nmrih_game_state = FindEntityByClassname(nmrih_game_state, "nmrih_game_state")) != -1)
		return nmrih_game_state;
	nmrih_game_state = CreateEntityByName("nmrih_game_state");
	if(IsValidEntity(nmrih_game_state) && DispatchSpawn(nmrih_game_state))
		return nmrih_game_state;
	return -1;
}
