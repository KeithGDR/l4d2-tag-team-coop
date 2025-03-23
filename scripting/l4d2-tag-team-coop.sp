#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo = {
	name = "[ANY] Tag Team Coop",
	author = "KeithGDR",
	description = "A gamemode for Left 4 Dead 2 where players team up in order to win.",
	version = PLUGIN_VERSION,
	url = "https://keithgdr.github.io/"
};

public void OnPluginStart() {
	CreateConVar("ttc_version", PLUGIN_VERSION, "The version of the Tag Team Coop plugin.", FCVAR_NOTIFY);
}