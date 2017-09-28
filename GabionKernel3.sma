/*
* Gabion Kernel 3
* ---
* The new one.
*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <sqlx>

// Version Info
#define BUILD "0010"
#define FRIENDLY_BUILD "Dev"

// SNet Account Session Auth Types
#define AUTH_DISABLED 0
#define AUTH_STEAMID 1
#define AUTH_IP 2

#define AUTH_DB_DISABLED ""
#define AUTH_DB_STEAMID "steam"
#define AUTH_DB_IP "ip"

// SNet Account Types
#define ACCOUNT_PLAYER 0
#define ACCOUNT_ROOT 1
#define ACCOUNT_SERVER 2

// Hud Constants
#define HUDLEN 512

// TO DO:
// Command line
// Simple Query (testing)

new dumbInt;
new dumbStr[2];

// General Variables
new serverId;							// Unique Server ID
new universeId;							// Universe ID
new cv_silentMode;						// Silent Mode Cvar

// MySQL Variables
new Handle:sqlConn;						// MySQL Connection
new Handle:sqlInfo;						// MySQL Connection Info
new Handle:sqlResult;					// MySQL Query Result
new sqlPrefix[16];						// MySQL Table Prefix
new fw_sqlConnect;						// MySQL Connected Forward
new fw_sqlDisconnect;					// MySQL Disconnecting Forward
new cv_sqlAddress;						// MySQL Address Cvar
new cv_sqlUsername;						// MySQL Username Cvar
new cv_sqlPassword;						// MySQL Password Cvar
new cv_sqlSchema;						// MySQL Schema Cvar

// Hud Variables
new hudText[32][HUDLEN];				// Hud Text - [playerID] (String)
new hudHeader[80];						// Hud Header
new Float:hudLoop;						// Hud Draw Loop Time (Float)
new cv_hudShow;							// Hud Toggle Cvar Pointer
new cv_hudRate;							// Hud Refresh Rate Cvar Pointer
new cv_hudRed;							// Hud Color Red Cvar Pointer
new cv_hudGreen;						// Hud Color Green Cvar Pointer
new cv_hudBlue;							// Hud Color Blue Cvar Pointer
new fw_hudPrint;						// Hud Print Forward

// Component Variables
new fw_init;							// Gabion Kernel Init Forward
new fw_end;								// Gabion Kernel Shutdown Forward

// Player Variables
new playerId[33];						// Player DB ID - [playerID] (Integer)
new playerType[33];						// Player Account Type - [playerID] (Integer)
new cv_playerUniverse;					// Player Universe Cvar Pointer
new cv_playerAuth;						// Player Auth Type Cvar Pointer
new cv_playerAutoReg;					// Player Auto Register Cvar Pointer
new fw_playerLoginPre;					// Player Login Forward (Pre)
new fw_playerLoginFailure;				// Player Login Forward (Failure)
new fw_playerLoginSuccess;				// Player Login Forward (Success)
new fw_playerLogoutPre;					// Player Logout Forward (Pre)
new fw_playerLogoutPost;				// Player Logout Forward (Post)

public plugin_init()
{
	register_plugin("Gabion Kernel 3", BUILD, "Gabion Studios");
	
	// Register Commands
	register_concmd("gabion","cmdMain", ADMIN_ALL, "Access the Gabion Kernel command line.");
	//register_clcmd("say", "cmdSay", ADMIN_IMMUNITY);
	
	// Register Cvars
	cv_sqlAddress = register_cvar("gab_sqladdress", "localhost", FCVAR_PROTECTED);
	cv_sqlUsername = register_cvar("gab_sqluser", "root", FCVAR_PROTECTED);
	cv_sqlPassword = register_cvar("gab_sqlpass", "pass", FCVAR_PROTECTED);
	cv_sqlSchema = register_cvar("gab_sqlschema", "schmonet", FCVAR_PROTECTED);
	
	register_cvar("gab_sqlprefix", "gab_", FCVAR_PROTECTED);
	
	cv_hudShow = register_cvar("gab_showhud", "1", FCVAR_SERVER);
	cv_hudRate = register_cvar("gab_hudrate", "2.0", FCVAR_SERVER);
	cv_hudRed = register_cvar("gab_hudred", "150", FCVAR_SERVER);
	cv_hudGreen = register_cvar("gab_hudgreen", "175", FCVAR_SERVER);
	cv_hudBlue = register_cvar("gab_hudblue", "255", FCVAR_SERVER);
	
	register_cvar("gab_serverid", "0", FCVAR_PROTECTED);
	
	cv_silentMode = register_cvar("gab_silentmode", "0");
	cv_playerUniverse = register_cvar("gab_universeid", "0");
	cv_playerAuth = register_cvar("gab_authtype", "1");
	cv_playerAutoReg = register_cvar("gab_autoreg", "1");
	
	// Register Forwards
	register_forward(FM_PlayerPreThink,"hookPreThink");
	register_forward(FM_ClientPutInServer,"hookJoin");
	register_forward(FM_ClientDisconnect,"hookLeave");
	
	// Create Forwards
	fw_sqlConnect = CreateMultiForward("gabSqlReady",ET_IGNORE);
	fw_sqlDisconnect = CreateMultiForward("gabSqlShutdown",ET_IGNORE);
	fw_hudPrint = CreateMultiForward("gabHudPrint",ET_IGNORE);
	fw_init = CreateMultiForward("gabInit",ET_IGNORE);
	fw_end = CreateMultiForward("gabEnd",ET_IGNORE);
	fw_playerLoginPre = CreateMultiForward("gabPlayerLoginPre",ET_IGNORE,FP_CELL);
	fw_playerLoginFailure = CreateMultiForward("gabPlayerLoginFailure",ET_IGNORE,FP_CELL);
	fw_playerLoginSuccess = CreateMultiForward("gabPlayerLoginSuccess",ET_IGNORE,FP_CELL);
	fw_playerLogoutPre = CreateMultiForward("gabPlayerLogoutPre",ET_IGNORE,FP_CELL);
	fw_playerLogoutPost = CreateMultiForward("gabPlayerLogoutPost",ET_IGNORE,FP_CELL);
	
	// Setup Hud
	formatex(hudHeader, 79, "Gabion Kernel 3 (%s)^nhttp://gabionstudios.com^n-------", FRIENDLY_BUILD);
	
	server_print("This server is running Gabion Kernel 3 (Build %s)", BUILD);
}

public plugin_end()
{
	sqlDisconnect();
	
	ExecuteForward(fw_end, dumbInt);
}

public plugin_cfg()
{
	server_cmd("exec addons/amxmodx/configs/gabionkernel/kernel3.cfg");
	
	universeId = get_pcvar_num(cv_playerUniverse);
	
	if(get_cvar_num("sv_lan") == 1 && get_pcvar_num(cv_playerAuth) == AUTH_STEAMID)
	{
		server_print("[GabionKernel] WARNING!  sv_lan is ON and player auth is set to STEAMID!  Players may not automatically login!");
	}
	
	ExecuteForward(fw_init,dumbInt);
	
	set_task(1.0, "sqlConnect");
}

public plugin_natives()
{
	register_library("gabionkernel3");
	
	// SQL Functions
	register_native("sqlGetConn","nGetConn",1);
	register_native("sqlPrefix","nSqlPrefix",1);
	register_native("sqlSimpleQuery","nSqlSimpleQuery",1);
	register_native("sqlSimpleQueryT","nSqlSimpleQueryT",1);
	
	// Player Functions
	register_native("gabPlayerId","nGabPlayerId",1);
	register_native("gabFriendlyId","playerFriendlyId",1);
	register_native("gabPlayerType", "nGabPlayerType",1);
	
	// Hud Functions
	register_native("hudPrint","nHudPrint",1);
	register_native("hudLen","nHudLen",1);
	
	// Admin Functions
	register_native("adminAdd", "nAddAdmin" ,1);
	register_native("adminRemove", "nRemoveAdmin" ,1);
	register_native("adminSetFlag", "nSetAdminFlag" ,1);
	register_native("adminAddFlag", "nAddAdminFlag" ,1);
	register_native("adminCheck", "nCheckAdminFlag" ,1);
	
	// Misc Functions
	register_native("gabVersion", "nGabVersion" ,1);
	register_native("gabUniverse", "nGabUniverse" ,1);
	register_native("gabServerId", "nGabServerId" ,1);
}

/*
*  Engine Hooks
*/

public hookPreThink(id)
{
	// Inefficient way, should find another.
	if((get_gametime() - hudLoop) >= get_pcvar_float(cv_hudRate) && get_pcvar_num(cv_hudShow) != 0)
	{
		hudLoop = get_gametime();
		hudDraw();
	}
	
	return PLUGIN_CONTINUE;
}

public hookJoin(id)
{
	playerId[id] = 0;
	playerType[id] = 0;
	
	playerAutoLogin(id);
	
	return PLUGIN_CONTINUE;
}

public hookLeave(id)
{
	playerLogout(id);
	
	playerId[id] = 0;
	playerType[id] = 0;
	
	return PLUGIN_CONTINUE;
}

/*
*  MySQL Functionality
*/

public sqlConnect() {
	new address[64], username[32], password[32], schema[32], error[128];
	
	get_pcvar_string(cv_sqlAddress, address, 63);
	get_pcvar_string(cv_sqlUsername, username, 31);
	get_pcvar_string(cv_sqlPassword, password, 31);
	get_pcvar_string(cv_sqlSchema, schema, 31);
	serverId = get_cvar_num("gab_serverid");
	
	if(serverId < 1)
	{
		server_print("[GabionKernel] WARNING!  This server does NOT have a proper server id!  Please check your config file!");
	}
	
	sqlInfo = SQL_MakeDbTuple(address, username, password, schema, 0);
	
	sqlConn = SQL_Connect(sqlInfo, dumbInt, error, 127);
	
	if(sqlConn == Empty_Handle)
	{
		if(get_pcvar_num(cv_silentMode) < 1)
		{
			server_print("[GabionKernel] SQL Connection Failure.  Reattempting in 2 seconds...");
			server_print("Error: %s", error);
		}
		
		set_task(2.0,"sqlConnect");
	}
	else
	{
		new query[128], servername[32];
		
		get_cvar_string("gab_sqlprefix",sqlPrefix,15);
		
		server_print("[GabionKernel] SQL Connection Successful.");
		
		// Set up the basics.
		SQL_SimpleQueryFmt(sqlConn, dumbStr, 0, dumbInt, "CREATE TABLE IF NOT EXISTS `%saccounts` (`id` INTEGER NOT NULL,`username` VARCHAR(32) NOT NULL DEFAULT ^"^",`password` VARCHAR(32) NOT NULL DEFAULT ^"^",`type` INTEGER UNSIGNED NOT NULL DEFAULT 0,`universe` INTEGER UNSIGNED NOT NULL DEFAULT 0,PRIMARY KEY (`id`)) ENGINE = InnoDB;", sqlPrefix);
		SQL_SimpleQueryFmt(sqlConn, dumbStr, 0, dumbInt, "CREATE TABLE IF NOT EXISTS `%saccounts_auths` (`id` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,`snid` INTEGER UNSIGNED NOT NULL DEFAULT 0,`type` VARCHAR(16) NOT NULL DEFAULT ^"^",`data` VARCHAR(64) NOT NULL DEFAULT ^"^",PRIMARY KEY (`id`)) ENGINE = InnoDB;", sqlPrefix);
		SQL_SimpleQueryFmt(sqlConn, dumbStr, 0, dumbInt, "CREATE TABLE IF NOT EXISTS `%sadmins` (`id` INTEGER UNSIGNED NOT NULL, `server` INTEGER UNSIGNED NOT NULL DEFAULT 0, `root` BOOLEAN NOT NULL DEFAULT 0) ENGINE = InnoDB;", sqlPrefix);
		
		formatex(query, 127, "SELECT username FROM snet_accounts WHERE id=%i AND type=2;", serverId);
		
		if(sqlExecute(query))
		{
			SQL_ReadResult(sqlResult, 0, servername, 31);
			
			playerId[0] = serverId;
			
			server_print("[GabionKernel] Server has been logged in as %s (#%i)!", servername, serverId);
			
			SQL_FreeHandle(sqlResult);
		}
		else
		{
			playerId[0] = 0;
			serverId = 0;
			server_print("[GabionKernel] WARNING!  This server does NOT have a proper server id!  Please check your config file!");
		}
		
		for(new x = 1; x < 33; x++)
		{
			if(is_user_connected(x))
			{
				hookJoin(x);
			}
		}
		
		ExecuteForward(fw_sqlConnect, dumbInt)
	}
	
	return PLUGIN_HANDLED;
}

public sqlDisconnect()
{
	ExecuteForward(fw_sqlDisconnect, dumbInt);
	
	for(new x = 1; x < 33; x++)
	{
		if(playerId[x] > 0)
		{
			hookLeave(x);
		}
	}
	
	SQL_FreeHandle(sqlConn);
	SQL_FreeHandle(sqlInfo);
	
	return;
}

public sqlExecute(query[]) {
	new success = true;
	sqlResult = SQL_PrepareQuery(sqlConn, query);
	SQL_Execute(sqlResult);
	
	if(SQL_NumResults(sqlResult) < 1) {
		SQL_FreeHandle(sqlResult);
		success = false;
	}
	
	return success;
}

public Handle:nGetConn()
{
	return sqlConn;
}

public nSqlPrefix()
{
	return sqlPrefix;
}

public nSqlSimpleQuery(query[])
{
	param_convert(1);
	
	return sqlExecute(query);
}

public nSqlSimpleQueryT(query[])
{
	param_convert(1);
	
	SQL_ThreadQuery(sqlInfo, "dumbHandler", query, dumbStr);
	
	return;
}

public dumbHandler()
{
	return;
}

/*
*  Player Accounts
*/

public playerFlushLogin(id)
{
	if(id == 0)
	{
		for(new x=1; x < 33; x++)
		{
			if(is_user_connected(x))
			{
				if(playerId[x] > 0)
				{
					playerLogout(x);
				}
				
				playerAutoLogin(x);
			}
		}
	}
	else
	{
		if(playerId[id] > 0)
		{
			playerLogout(id);
		}
		
		playerAutoLogin(id);
	}
	
	return;
}

public playerAutoLogin(id)
{
	new success, authid[32], authtype, query[256], name[32];
	
	success = false;
	authtype = get_pcvar_num(cv_playerAuth);
	
	switch(authtype)
	{
		case AUTH_STEAMID:
		{
			get_user_authid(id, authid, 31);
			
			SQL_QuoteString(sqlConn,authid,31,authid);
			
			formatex(query, 255, "SELECT id,type FROM snet_accounts WHERE id=(SELECT snid FROM snet_accounts_auths WHERE type = ^"%s^" AND data = ^"%s^" LIMIT 1) AND universe=%i AND type<2 LIMIT 1;", AUTH_DB_STEAMID, authid, universeId);
		}
		
		case AUTH_IP:
		{
			get_user_ip(id, authid, 31, 1);
			
			SQL_QuoteString(sqlConn,authid,31,authid);
			
			formatex(query, 255, "SELECT id,type FROM snet_accounts WHERE id=(SELECT snid FROM snet_accounts_auths WHERE type = ^"%s^" AND data = ^"%s^" LIMIT 1) AND universe=%i AND type<2 LIMIT 1;", AUTH_DB_IP, authid, universeId);
		}
		
		default:
		{
			authtype = AUTH_DISABLED;
		}
	}	
	
	if(authtype != AUTH_DISABLED)
	{
		ExecuteForward(fw_playerLoginPre, dumbInt, id);
		
		get_user_name(id, name, 31);
		
		if(sqlExecute(query))
		{
			success = true;
			playerId[id] = SQL_ReadResult(sqlResult, 0);
			playerType[id] = SQL_ReadResult(sqlResult, 1);
			
			server_print("[GabionKernel] %s (%s) has logged in as %s!", name, authid, playerFriendlyId(id));
			
			SQL_FreeHandle(sqlResult);
		}
		else
		{
			success = playerAutoRegister(id);
		}
		
		if(success)
		{
			ExecuteForward(fw_playerLoginSuccess, dumbInt, id);
		}
		else
		{
			server_print("[GabionKernel] %s (%s) has failed to automatically login!", name, authid);
			
			ExecuteForward(fw_playerLoginFailure, dumbInt, id);
		}
	}
	
	return success;
}

public playerManualLogin(id, username[], userLen, password[], passLen)
{
	new success, query[256];

	ExecuteForward(fw_playerLoginPre, dumbInt, id);
	
	SQL_QuoteString(sqlConn, username, userLen, username);
	SQL_QuoteString(sqlConn, password, passLen, password);
		
	formatex(query, 255, "SELECT id,type FROM snet_accounts WHERE username=^"%s^" AND password=^"%s^" AND universe=%i AND type<2 LIMIT 1;", username, password, universeId);
	
	if(sqlExecute(query))
	{
		success = true;
		
		playerId[id] = SQL_ReadResult(sqlResult, 0);
		playerType[id] = SQL_ReadResult(sqlResult, 1);
		
		SQL_FreeHandle(sqlResult);
	}
	
	if(success)
	{
		ExecuteForward(fw_playerLoginSuccess, dumbInt, id);
	}
	else
	{
		ExecuteForward(fw_playerLoginFailure, dumbInt, id);
	}
	
	return success;
}

public playerAutoRegister(id)
{
	new success;
	new authid[32];
	new authtype;
	new accountId;
	
	authtype = get_pcvar_num(cv_playerAuth);
	
	success = false;
	
	if(get_pcvar_num(cv_playerAutoReg) > 0)
	{
		switch(authtype)
		{
			case AUTH_STEAMID:
			{
				get_user_authid(id, authid, 31);
			}
			
			case AUTH_IP:
			{
				get_user_ip(id, authid, 31, 1);
			}
			
			default:
			{
				authtype = AUTH_DISABLED;
			}
		}
		
		if(authtype != AUTH_DISABLED)
		{
			accountId = playerAddAccount(authid, authtype);
			
			if(accountId > -1)
			{
				new name[32];
				
				get_user_name(id, name, 31);
				
				playerId[id] = accountId;
				playerType[id] = ACCOUNT_PLAYER;
				
				server_print("[GabionKernel] %s (%s) has registered as %s!", name, authid, playerFriendlyId(id));
				
				success = true;
			}
		}
	}
	
	return success;
}

public playerAddAccount(authid[32], authtype)
{
	new query[256];
	new accountId;
	new loops;
	
	accountId = -1;
	loops = 0;
	
	SQL_QuoteString(sqlConn,authid,31,authid);
	
	while(accountId == -1 && loops < 10)
	{
		formatex(query, 255, "SELECT MAX(id)+1 FROM snet_accounts");
		
		sqlExecute(query);
		
		accountId = SQL_ReadResult(sqlResult, 0);
		
		accountId = (accountId > 0) ? accountId : 1;
		
		SQL_FreeHandle(sqlResult);
		
		formatex(query, 255, "INSERT INTO snet_accounts (id,username,type,universe) VALUES (%i,^"%i_%i^",%i,%i);", accountId, serverId, accountId, ACCOUNT_PLAYER, universeId);
		
		sqlResult = SQL_PrepareQuery(sqlConn, query);
		
		if(SQL_Execute(sqlResult))
		{
			switch(authtype)
			{
				case AUTH_STEAMID:
				{
					formatex(query, 255, "INSERT INTO snet_accounts_auths (snid,type,data) VALUES (%i,^"%s^",^"%s^");", accountId, AUTH_DB_STEAMID, authid);
				
					sqlExecute(query);
				}
				
				case AUTH_IP:
				{
					formatex(query, 255, "INSERT INTO snet_accounts_auths (snid,type,data) VALUES (%i,^"%s^",^"%s^");", accountId, AUTH_DB_IP, authid);
					
					sqlExecute(query);
				}
			}
		}
		else
		{
			accountId = -1;
		}
		
		loops++;
	}
	
	return accountId;
}

public playerLogout(id)
{
	ExecuteForward(fw_playerLogoutPre, dumbInt, id);
	
	ExecuteForward(fw_playerLogoutPost, dumbInt, id);
	
	return;
}

public playerFriendlyId(id)
{
	new friendlyId[32];
	
	if(playerId[id] > 0)
	{
		formatex(friendlyId, 31, "SNID_%i:%i:%i", universeId, playerType[id], playerId[id]);
	}
	else
	{
		formatex(friendlyId, 31, "UNKNOWN");
	}
	
	return friendlyId;
}

public nGabPlayerId(id) {
	return playerId[id];
}

public nGabPlayerType(id) {
	return playerType[id];
}

/*
*  Heads Up Display
*/
public nHudPrint(id, text[]) {
	param_convert(2);
	
	format(hudText[id-1], HUDLEN-1, "%s^n%s", hudText[id-1], text);
	
	return true;
}

public nHudLen() {
	return HUDLEN-1;
}

public hudDraw() {
	new id;
	
	for(id=0;id < 32;id++) {
		hudText[id] = "";
	}
	
	ExecuteForward(fw_hudPrint, dumbInt);
	
	for(id=1;id < 33;id++) {
		if(is_user_connected(id) && !is_user_bot(id))
		{
			set_hudmessage(get_pcvar_num(cv_hudRed), get_pcvar_num(cv_hudGreen), get_pcvar_num(cv_hudBlue), 0.005, 0.005, 0, 0.0, 8.0, 0.0, 0.0, 2);
			show_hudmessage(id,"%s%s",hudHeader,hudText[id-1]);
		}
	}	
	
	return PLUGIN_CONTINUE;
}

/*
*  Admin System
*/
public nAddAdmin(id) {
	if(!sqlConn || serverId == 0)
		return PLUGIN_HANDLED;
	
	new query[128];
	
	formatex(query,127,"SELECT id FROM %sadmins WHERE id = %i AND server = %i;",sqlPrefix,playerId[id],serverId);
	
	if(!sqlExecute(query)) {
		formatex(query,127,"INSERT INTO %sadmins (id,server) VALUES (%i,%i);",sqlPrefix,playerId[id],serverId);
		
		SQL_SimpleQuery(sqlConn, query);
	}
	else
	{
		SQL_FreeHandle(sqlResult);
	}
	
	return PLUGIN_HANDLED;
}

public nRemoveAdmin(id) {
	if(!sqlConn || serverId == 0)
		return PLUGIN_HANDLED;
	
	new query[128];
	
	formatex(query,127,"DELETE FROM %sadmins WHERE id = %i AND server = %i;",sqlPrefix,playerId[id],serverId);
	
	SQL_SimpleQuery(sqlConn, query);

	return PLUGIN_HANDLED;
}

public nSetAdminFlag(id, name[], setting) {
	if(!sqlConn || serverId == 0)
		return PLUGIN_HANDLED;
	
	param_convert(2);
	
	new query[128], flag[32];
	
	SQL_QuoteString(sqlConn,flag,31,name);
	
	if(strfind(flag,"'",1) == -1 && strfind(flag,"^"",1) == -1 && strfind(flag,";",1) == -1)
	{
		switch(setting) {
			case 0: {
				formatex(query,127,"UPDATE %sadmins SET %s = 0 WHERE id = %i AND server = %i;",sqlPrefix,flag,playerId[id],serverId);
				SQL_SimpleQuery(sqlConn, query);
			}
			
			case 1: {
				formatex(query,127,"UPDATE %sadmins (%s) %s = 1 WHERE id = %i AND server = %i;",sqlPrefix,flag,playerId[id],serverId);
				SQL_SimpleQuery(sqlConn, query);
			}
		}
	}
	
	return PLUGIN_HANDLED;
}

public nAddAdminFlag(name[]) {
	if(!sqlConn)
		return PLUGIN_HANDLED;
	
	param_convert(1);
	
	new flag[32], query[128];
	
	if(strfind(flag,"'",1) == -1 && strfind(flag,"^"",1) == -1 && strfind(flag,";",1) == -1)
	{
		SQL_QuoteString(sqlConn,flag,31,name);
		
		formatex(query,127,"DESCRIBE %sadmins '%s'",sqlPrefix,flag);
		
		if(!sqlExecute(query)) {
			formatex(query,127,"ALTER TABLE `%sadmins` ADD COLUMN `%s` BOOLEAN NOT NULL DEFAULT 0;",sqlPrefix,flag);
			
			SQL_SimpleQuery(sqlConn, query);
			
			if(get_pcvar_num(cv_silentMode) < 1)
			{
				server_print("[GabionKernel] Flag %s was added to the admins table.",flag);
			}
		}
		else
		{
			SQL_FreeHandle(sqlResult);
		}
	}
	
	return PLUGIN_HANDLED;
}

public nCheckAdminFlag(id, flag[]) {
	if(id == 0 || playerType[id] == ACCOUNT_ROOT)
		return true;
	
	if(!sqlConn || serverId == 0)
		return false;
	
	param_convert(2);
	
	new query[128], flagName[32], success;
	
	success = false;
	
	SQL_QuoteString(sqlConn,flagName,31,flag);
	
	formatex(query,127,"SELECT id FROM %sadmins WHERE flags LIKE ^"%s^" id = %i AND server = %i OR root = 1 AND id = %i AND server = %i;",sqlPrefix,flag,playerId[id],serverId,playerId[id],serverId);
	
	if(sqlExecute(query)) {
		SQL_FreeHandle(sqlResult);
		success = true;
	}
	
	return success;
}

/*
*  Commands
*/
public cmdMain(id)
{
	new command[24];
	new args[32];
	
	read_argv(1, command, 23);
	
	if(equali(command, "list"))
	{
		cmdList(id, 0);
	}
	else
	{
		if(id == 0)
		{
			server_print("Gabion Kernel Commands^n---^nCommand^t^tDescription^n^nlist^t^tDisplays player info");
		}
		else
		{
			client_print(id, print_console, "Gabion Kernel Commands^n---^nCommand^t^tDescription^n^nlist [page]^t^tDisplays player info");
		}
	}
	
	//read_argv(2, args, 31);
	
	return PLUGIN_HANDLED;
}

public cmdSay(id)
{
	
	return PLUGIN_CONTINUE;
}

public cmdList(id, page)
{
	page = (page > 4) ? 4 : page;
	page = (page < 1) ? 1 : page;
	
	new message[512];
	new currentPlayer = (page - 1) * 10 + 1;
	new maxPlayers = currentPlayer + 10;
	
	new name[32];
	
	formatex(message, 511, "SNet Player Info (Page %i)^n---^nName - SNID^n", page);
	
	while(maxPlayers > currentPlayer && currentPlayer <= 32)
	{
		if(is_user_connected(currentPlayer))
		{
			get_user_name(currentPlayer, name, 31);
			
			format(message, 511, "%s^n%s - %s", message, name, playerFriendlyId(currentPlayer));
		}
		
		currentPlayer++;
	}
	
	if(id == 0)
	{
		server_print(message);
	}
	else
	{
		client_print(id, print_console, message);
	}
	
	return;
}

/*
*  Misc
*/
public nGabVersion()
{
	return str_to_num(BUILD);
}

public nGabUniverse()
{
	return universeId;
}

public nGabServerId()
{
	return serverId;
}