/*	
	Gabion Kernel 3 Include File
*/	

// DO NOT TOUCH ANYTHING UNLESS YOU ABSOLUTELY KNOW WHAT YOU'RE DOING
// I WILL NOT HELP YOU IF YOU BREAK YOUR PLUGIN

#pragma reqlib gabionkernel3

/*
	API Functions
*/

//----------------------------------------------------------------
// Component Functions
//----------------------------------------------------------------

// Called After Gabion Kernel Is Initiated
forward gabInit();

// Called Before Gabion Kernel Shuts Down
forward gabEnd();

//----------------------------------------------------------------
// SQL Functions
//----------------------------------------------------------------

// Get SQL Connection Handle
native Handle:sqlGetConn();

// Get SQL Prefix
native sqlPrefix();

// Simple Query
native sqlSimpleQuery(query[]);

// Simple Threaded Query
native sqlSimpleThread(query[]);

// Called When SQL Is Ready
forward gabSqlReady();

// Called Before SQL Is Disconnected
forward gabSqlShutdown();

//----------------------------------------------------------------
// Player Functions
//----------------------------------------------------------------

// Get Player's SNID
native gabPlayerId(id);

// Player Friendly SNID
native gabFriendlyId(id);

// Called Before Player Is Logged In
forward gabPlayerLoginPre(id);

// Called If Player Login Is Successful
forward gabPlayerLoginSuccess(id);

// Called If Player Login Is Failure
forward gabPlayerLoginFailure(id);

// Called Before Player Info Is Cleared
forward gabPlayerLogoutPre(id);

// Called After Player Info Is Cleared
forward gabPlayerLogoutPost(id);

//----------------------------------------------------------------
// Hud Functions
//----------------------------------------------------------------

// Print To Hud Row
native hudPrint(id, text[]);

// Hud Row Length
native hudLen();

// Called Before Hud Is Going To Print
forward gabHudPrint();

//----------------------------------------------------------------
// Admin Functions
//----------------------------------------------------------------

// Add Admin
native adminAdd(id);

// Remove Admin
native adminRemove(id);

// Set Admin's Flag
native adminSetFlag(id, name[], status);

// Add Admin Flag
native adminAddFlag(name[]);

// Check Admin Flag
native adminCheck(id, flag[]);

//----------------------------------------------------------------
// Misc Functions
//----------------------------------------------------------------

// Get Current Gabion Kernel Build
native gabVersion();

// Universe ID
native gabUniverse();

// Server ID
native gabServerId();