#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_TAG "[TTG]"
#define PLUGIN_TAG_COLOR "\x04"
#define PLUGIN_CHAT_COLOR "\x03"

#define TEAM_NONE -1
#define TEAM_RED 0
#define TEAM_BLUE 1

ConVar convar_Enabled;
ConVar convar_FriendlyFire;

int g_Team[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[ANY] Tag Team Coop",
	author = "KeithGDR",
	description = "A gamemode for Left 4 Dead 2 where players team up in order to win.",
	version = PLUGIN_VERSION,
	url = "https://keithgdr.github.io/"
};

public void OnPluginStart() {
	CreateConVar("ttc_version", PLUGIN_VERSION, "The version of the Tag Team Coop plugin.", FCVAR_NOTIFY);
	convar_Enabled = CreateConVar("sm_ttc_enabled", "1", "Is the Tag Team Coop gamemode enabled or disabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_FriendlyFire = CreateConVar("sm_ttc_friendly_fire", "1", "Are you allowed to damage your teammate at all?", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegAdminCmd("sm_assignteams", Command_AssignTeams, ADMFLAG_GENERIC, "Automatically assign teams to players.");

	HookEvent("round_freeze_end", Event_RoundFreezeEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}

	PrintAll("Tag Team Coop gamemode loaded.");
}

public void OnPluginEnd() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			L4D2_RemoveEntityGlow(i);
		}
	}

	PrintAll("Tag Team Coop gamemode unloaded.");
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect_Post(int client) {
	g_Team[client] = TEAM_NONE;
}

public Action Command_AssignTeams(int client, int args) {
	if (!convar_Enabled.BoolValue) {
		return Plugin_Continue;
	}

	AssignTeams();

	return Plugin_Handled;
}

public void Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast) {
	if (!convar_Enabled.BoolValue) {
		return;
	}

	AssignTeams();
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (g_Team[client] != TEAM_NONE) {
		L4D2_SetEntityGlow(client, L4D2Glow_Constant, 0, 0, g_Team[client] == TEAM_RED ? view_as<int>({255, 0, 0}) : view_as<int>({0, 0, 255}), false);
	}
}
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (g_Team[client] != TEAM_NONE) {
		L4D2_RemoveEntityGlow(client);
	}
}

void AssignTeams() {
	int[] players = new int[MaxClients + 1];
	int numPlayers = 0;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) < 2) {
			continue;
		}

		players[numPlayers] = i;
		numPlayers++;
	}

	if (numPlayers < 2) {
		PrintAll("Not enough players to assign teams.");
		return;
	}

	int numRed = numPlayers / 2;
	int numBlue = numPlayers - numRed;

	int[] red = new int[numRed];
	int[] blue = new int[numBlue];

	for (int i = 0; i < numRed; i++) {
		int randomIndex = GetRandomInt(0, numPlayers - 1);
		red[i] = players[randomIndex];

		players[randomIndex] = players[numPlayers - 1];
		numPlayers--;
	}

	for (int i = 0; i < numBlue; i++) {
		int randomIndex = GetRandomInt(0, numPlayers - 1);
		blue[i] = players[randomIndex];

		players[randomIndex] = players[numPlayers - 1];
		numPlayers--;
	}

	for (int i = 0; i < numRed; i++) {
		PrintAll("%N has been assigned team: RED", red[i]);
		L4D2_SetEntityGlow(red[i], L4D2Glow_Constant, 0, 0, view_as<int>({255, 0, 0}), false);
		g_Team[red[i]] = TEAM_RED;
	}

	for (int i = 0; i < numBlue; i++) {
		PrintAll("%N has been assigned team: BLUE", blue[i]);
		L4D2_SetEntityGlow(blue[i], L4D2Glow_Constant, 0, 0, view_as<int>({0, 0, 255}), false);
		g_Team[blue[i]] = TEAM_BLUE;
	}
}

void Print(int client, const char[] format, any ...) {
	char buffer[255];
	VFormat(buffer, sizeof(buffer), format, 3);

	if (client < 1) {
		PrintToServer("%s%s %s", PLUGIN_TAG_COLOR, PLUGIN_TAG, buffer);
	} else {
		PrintToChat(client, "%s%s %s%s", PLUGIN_TAG_COLOR, PLUGIN_TAG, PLUGIN_CHAT_COLOR, buffer);
	}
}

void PrintAll(const char[] format, any ...) {
	char buffer[255];
	VFormat(buffer, sizeof(buffer), format, 2);

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}

		Print(i, buffer);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
	if (!convar_Enabled.BoolValue) {
		return Plugin_Continue;
	}

	if (convar_FriendlyFire.BoolValue && g_Team[victim] != TEAM_NONE && g_Team[victim] == g_Team[attacker]) {
		damage = 0.0;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action L4D2_OnStartUseAction(any action, int client, int target) {
	if (action == L4D2UseAction_Defibing && target > 0 && target <= MaxClients && g_Team[client] != g_Team[target]) {
		Print(client, "You can't defib the enemy team.");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action L4D2_BackpackItem_StartAction(int client, int entity, any type) {
	int target = L4D_FindUseEntity(client);

	if (target < 1 || target > MaxClients) {
		return Plugin_Continue;
	}

	if (g_Team[client] != TEAM_NONE && g_Team[client] != g_Team[target]) {
		Print(client, "You can't heal the enemy team.");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}