#include <sourcemod>
#include <vector>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "instestplugin",
	author = "bjurd",
	description = "test plugin",
	version = "1.0.0",
	url = "https://github.com/bjurd/instestplugin"
};

enum struct CUserCmd
{
	int Client; // Definitely in real usercmd trust

	int TickCount;
	int CommandNumber;

	int Buttons;
	int Impulse;
	int RandomSeed;

	float ForwardMove;
	float SideMove;
	float UpMove;

	float ViewAngles[3];

	int Weapon;
	int Subtype;

	int MouseX;
	int MouseY;
}

#define DAMAGE_NO  0
#define DAMAGE_YES 2

int AFKTicks[MAXPLAYERS + 1];
CUserCmd StoredCommands[MAXPLAYERS + 1];
bool GodMode[MAXPLAYERS + 1];

ConVar instestplugin_activation_percent;
ConVar instestplugin_max_afk_time;
ConVar instestplugin_respect_viewangles;

public void OnPluginStart()
{
	instestplugin_activation_percent = CreateConVar(
		"instestplugin_activation_percent",
		"0",
		"Percentage of players on the server needed for anti-afk to be active. Range of 0-1.",
		FCVAR_ARCHIVE,
		true, 0.0,
		true, 1.0
	);

	instestplugin_max_afk_time = CreateConVar(
		"instestplugin_max_afk_time",
		"600",
		"How many seconds of AFK before annihilation",
		FCVAR_ARCHIVE,
		true, 0.0,
		false, 0.0
	);

	instestplugin_respect_viewangles = CreateConVar(
		"instestplugin_respect_viewangles",
		"1",
		"Whether or not view angle changes should count as not afk",
		FCVAR_ARCHIVE,
		true, 0.0,
		true, 1.0
	);

	RegAdminCmd("sm_god", Command_God, ADMFLAG_GENERIC, "im jesus");
	RegServerCmd("kickrand", Command_KickRand, "Get the fuc kout!!!!!!!!!!!!!");
	HookEvent("player_spawn", Event_PlayerSpawn);

	LogMessage("OIPOIIffffffffffffffffffffffffuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu");
}

public Action Command_KickRand(int Args)
{
	int Candidates[MAXPLAYERS];
	int Count = 0;

	for (int Client = 1; Client <= MaxClients; Client++)
	{
		if (IsClientInGame(Client) && !IsFakeClient(Client))
			Candidates[Count++] = Client;
	}

	if (Count == 0)
	{
		PrintToServer("[SM] No players to kick.");
		return Plugin_Handled;
	}

	int Client = Candidates[GetRandomInt(0, Count - 1)];
	PrintToServer("[SM] Kicking %N.", Client);
	KickClient(Client, "Get out of my way");
	return Plugin_Handled;
}

public Action Command_God(int Client, int Args)
{
	if (Client == 0)
	{
		ReplyToCommand(Client, "[SM] This command can only be used in-game.");
		return Plugin_Handled;
	}

	GodMode[Client] = !GodMode[Client];
	ApplyGodMode(Client);

	ReplyToCommand(Client, "[SM] God mode %s.", GodMode[Client] ? "enabled" : "disabled");
	return Plugin_Handled;
}

public void ApplyGodMode(int Client)
{
	if (!IsClientInGame(Client) || !IsPlayerAlive(Client))
		return;

	SetEntProp(Client, Prop_Data, "m_takedamage", GodMode[Client] ? DAMAGE_NO : DAMAGE_YES);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int Client = GetClientOfUserId(event.GetInt("userid"));
	if (Client > 0 && GodMode[Client])
	{
		// Spawn resets m_takedamage
		RequestFrame(Frame_ApplyGodMode, GetClientUserId(Client));
	}
}

public void Frame_ApplyGodMode(int UserId)
{
	int Client = GetClientOfUserId(UserId);
	if (Client > 0)
		ApplyGodMode(Client);
}

public void ResetAFK(int Client)
{
	AFKTicks[Client] = 0;
	StoredCommands[Client].Client = -1;
}

public void OnClientPutInServer(int Client)
{
	ResetAFK(Client);
}

public void OnClientDisconnect(int Client)
{
	ResetAFK(Client);
	GodMode[Client] = false;
}

public float NormalizeAngle(float Angle)
{
	if (Angle > 180.0)
		Angle -= 360.0;
	else if (Angle < -180.0)
		Angle += 360.0;

	return Angle;
}

public float AngleDiff(float A, float B)
{
	return NormalizeAngle(A - B);
}

public bool AngleEqual(float A, float B)
{
	#define ANGLE_EPSILON 0.01 // Retarded that you can't have default parameters
	return AngleDiff(A, B) < ANGLE_EPSILON;
}

public bool AnglesEqual(float A[3], float B[3]) // Amazing naming I know
{
	return AngleEqual(A[0], B[0]) && AngleEqual(A[1], B[1]) && AngleEqual(A[2], B[2]);
}

public bool IsAFKTick(CUserCmd Command)
{
	CUserCmd LastCommand;
	LastCommand = StoredCommands[Command.Client]; // Because a proper initializer is 2hard4sourcepawn

	if (LastCommand.Client != Command.Client)
		return false; // Either don't have one yet or some bullshit goin' on

	float Speed = (Command.ForwardMove * Command.ForwardMove) +
		(Command.SideMove * Command.SideMove) +
		(Command.UpMove * Command.UpMove);

	bool Moving = Speed > 0.0 || Command.Buttons != 0 || Command.Impulse != 0;
	bool Looking = Command.MouseX != 0 || Command.MouseY != 0;
	bool Switching = Command.Weapon != LastCommand.Weapon || Command.Subtype != LastCommand.Subtype;

	if (instestplugin_respect_viewangles.BoolValue)
	{
		// To defeat +right'ers
		Looking = Looking || !AnglesEqual(Command.ViewAngles, LastCommand.ViewAngles);
	}

	return !Moving && !Looking && !Switching;
}

public void AFKTick(int Client)
{
	AFKTicks[Client]++;

	float Time = AFKTicks[Client] * GetTickInterval();
	if (Time >= instestplugin_max_afk_time.FloatValue)
	{
		// Sayonara bitch!
		KickClient(Client, "You were AFK for %.2f second(s)", Time);
	}
}

public Action OnPlayerRunCmd(
	int Client,
	int& Buttons,
	int& Impulse,
	float Velocity[3],
	float Angles[3],
	int& Weapon,
	int& Subtype,
	int& CommandNumber,
	int& TickCount,
	int& RandomSeed,
	int Mouse[2]
)
{
	float Activation = instestplugin_activation_percent.FloatValue;
	if (Activation > 0.0)
	{
		int MaxPlayers = GetMaxHumanPlayers();
		int Players = GetClientCount(true);

		float Percentage = (float)(Players) / (float)(MaxPlayers);

		if (Percentage < Activation)
			return Plugin_Continue;
	}

	CUserCmd Command;
	Command.Client = Client;
	Command.TickCount = TickCount;
	Command.CommandNumber = CommandNumber;
	Command.Buttons = Buttons;
	Command.Impulse = Impulse;
	Command.RandomSeed = RandomSeed;
	Command.ForwardMove = Velocity[0];
	Command.SideMove = Velocity[1];
	Command.UpMove = Velocity[2];
	Command.ViewAngles = Angles;
	Command.Weapon = Weapon;
	Command.Subtype = Subtype;
	Command.MouseX = Mouse[0];
	Command.MouseY = Mouse[1];

	if (IsPlayerAlive(Client) && IsAFKTick(Command))
	{
		AFKTick(Client);
	}
	else
	{
		AFKTicks[Client] = 0;
	}

	StoredCommands[Client] = Command;

	return Plugin_Continue;
}
