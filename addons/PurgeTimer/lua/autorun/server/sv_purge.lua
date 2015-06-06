PURGE = {};

-- Networking
util.AddNetworkString("PurgeTimer");
util.AddNetworkString("PurgeEndTimer");

-- Global Variables
local bTakeDamage = false;
local iRounds = 0;
local bPurgeInProgress = false;
local bInPrepareDelayTime = false;

-- ConVars/Settings
local pt1 = CreateConVar("sv_purge_time", "12", _, "The amount of time the Purge lasts for in minutes.");
local pt2 = CreateConVar("sv_purge_setup_time", "45", _, "The amount of time until the Purge begins (setup time) in minutes.");
local pt3 = CreateConVar("sv_purge_announcement_time", "52", _, "The amount of time the announcement before the Purge begins takes (length of the file) in seconds");
local pt4 = CreateConVar("sv_purge_maxrounds", "16", _, "The maximum rounds (Purge beginning to end) until the map restarts to clear the precache table");
local pt5 = CreateConVar("sv_purge_debug", "0", _, "Debug the Purge Timer?");
local pt6 = CreateConVar("sv_purge_check", "1", _, "Check to ensure the Purge timer is set every 30 seconds?");

local settings = {};
settings.fPurgeTime = pt1:GetFloat();
settings.fPurgeSetupTime = pt2:GetFloat();
settings.fPurgeAnnouncementTime = pt3:GetFloat();
settings.iPurgeMaxRounds = pt4:GetInt();
settings.bDebug = pt5:GetBool();
settings.bCheck = pt6:GetBool();

-- Settings not with ConVars (feel free to edit)
settings.arrWhiteList = 
{
	"STEAM_0:0:36969327", 	-- [GFL] Roy (Christian Deacon)
	"STEAM_0:1:19665197", 	-- Cypher
	"STEAM_0:1:938085" 		-- X2D
};

cvars.AddChangeCallback("sv_purge_time", function (sCVarName, sOldv, sNewv)
	if (settings.bDebug) then
		print("[PT DEBUG]sv_purge_time set to " .. sNewv .. "\n");
	end
	
	settings.fPurgeTime = pt1:GetFloat();
end);

cvars.AddChangeCallback("sv_purge_setup_time", function (sCVarName, sOldv, sNewv)
	if (settings.bDebug) then
		print("[PT DEBUG]sv_purge_setup_time set to " .. sNewv .. "\n");
	end
	
	settings.fPurgeSetupTime = pt2:GetFloat();
end);

cvars.AddChangeCallback("sv_purge_announcement_time", function (sCVarName, sOldv, sNewv)
	if (settings.bDebug) then
		print("[PT DEBUG]sv_purge_announcement_time set to " .. sNewv .. "\n");
	end
	
	settings.fPurgeAnnouncementTime = pt3:GetFloat();
end);

cvars.AddChangeCallback("sv_purge_maxrounds", function (sCVarName, sOldv, sNewv)
	if (settings.bDebug) then
		print("[PT DEBUG]sv_purge_maxrounds set to " .. sNewv .. "\n");
	end
	
	settings.iPurgeMaxRounds = pt4:GetInt();
end);

cvars.AddChangeCallback("sv_purge_check", function (sCVarName, sOldv, sNewv)
	if (settings.bDebug) then
		print("[PT DEBUG]sv_purge_check set to " .. sNewv .. "\n");
	end
	
	settings.bCheck = pt6:GetBool();
end);

-- Verify User
local function VerifyUser (ply)
	local bAllow = false;
	for _,v in pairs (settings.arrWhiteList) do
		if ply:SteamID() == v then
			bAllow = true;
		end
	end
	
	return bAllow;
end
-- PURGE Functions
function PURGE.SetNight(bNight)
	if (settings.bDebug) then
		print("[PT DEBUG]Function PURGE.SetNight() :: Called.\n");
	end
	if(bNight) then
		if (settings.bDebug) then
			print("[PT DEBUG]Setting Night :: True.\n");
		end
		local lightenvs = ents.FindByClass("light_environment");
		for _, light in pairs(lightenvs) do
			if (IsValid(light)) then
				 light:Fire( 'FadeToPattern' , 'a' , 0 ); -- z = brightest.
			end
		end
	else
		if (settings.bDebug) then
			print("[PT DEBUG]Setting Night :: False.\n");
		end
		local lightenvs = ents.FindByClass("light_environment")
		for _, light in pairs(lightenvs) do
			if (IsValid(light)) then
				 light:Fire( 'FadeToPattern' , 'v' , 0 ); -- z = brightest.
			end
		end
	end
end

-- Local Functions
function PURGE.KillTimers()
	timer.Stop("Timer_SetPurgeTimer");
	timer.Stop("Timer_PurgeAnnouncement");
	timer.Stop("Timer_PurgeStart");
	timer.Stop("Timer_PurgeOver");
	timer.Stop("Manual_PurgeStart");
end

-- Local Timer Functions
function PURGE.SetTimer()
	if (settings.bDebug) then
		print("[PT DEBUG]Function SetPurgeTimer() :: Called.\n");
	end
	
	PURGE.SetNight(false);
	bTakeDamage = false;
	PURGE.Timer = CurTime() + (settings.fPurgeSetupTime * 60);
	
	net.Start("PurgeTimer");
	net.WriteUInt(PURGE.Timer,32);
	net.Broadcast();
	BroadcastLua([[chat.AddText(Color(200,72,72),"[ALERT] ",Color(255,255,255),"Begin to setup for the next Purge!")]]);
	bPurgeInProgress = false;
end

function PURGE.Announcement()
	if (settings.bDebug) then
		print("[PT DEBUG]Function PurgeAnnouncement() :: Called.\n");
	end

	for k, ply in pairs( player.GetAll() ) do
		ply:EmitSound("weapons/purge/purge.mp3");
	end
	
	if (settings.bDebug) then
		print("[PT DEBUG]Function PurgeAnnouncement() :: Ended.\n");
	end
end

function PURGE.Start()
	if (settings.bDebug) then
		print("[PT DEBUG]Function PurgeStart() :: Called.\n");
	end
	
	umsg.Start("PurgeStart");
	umsg.End();
	PURGE.SetNight(true);
	PURGE.Timer = nil;
	bTakeDamage = true;
	bPurgeInProgress = true;
	
	-- Let's make the purge end timer!
	PURGE.EndTimer = CurTime() + (settings.fPurgeTime * 60);
	net.Start("PurgeEndTimer");
	net.WriteUInt(PURGE.EndTimer,32);
	net.Broadcast();

	if (settings.bDebug) then
		print("[PT DEBUG]Function PurgeStart() :: Ended.\n");
	end
end

function PURGE.Over()
	if (settings.bDebug) then
		print("[PT DEBUG]Function PurgeOver() :: Called.\n");
	end
	
	umsg.Start("PurgeOver");
	umsg.End();
	
	for k, ply in pairs( player.GetAll() ) do
		ply:EmitSound("weapons/purge/purge_end.mp3");
	end
	
	PURGE.SetNight(false);
	PURGE.EndTimer = nil;
	bPurgeInProgress = false;
	
	iRounds = iRounds + 1;
	if (iRounds >= settings.iPurgeMaxRounds) then
		if (settings.bDebug) then
			print("[PT DEBUG]Maximum rounds :: Exceeded.\n");
		end
		-- Restart the map.
		for _,v in pairs(player.GetAll()) do
			v:ChatPrint("Restarting the map in 5 seconds! This is to clear the model precache!");
			v:ChatPrint("Restarting the map in 5 seconds! This is to clear the model precache!");
			v:ChatPrint("Restarting the map in 5 seconds! This is to clear the model precache!");
		end
		timer.Simple(5, function()
			RunConsoleCommand("changelevel", game.GetMap());
		end)
	end
	
	bInPrepareDelayTime = true;
	timer.Simple(1, function()
		PURGE.SetUpPurge();
		bInPrepareDelayTime = false;
	end)
end

function PURGE.SetUpPurge()
	if (settings.bDebug) then
		print("[PT DEBUG]Function SetUpPurge() :: Called.\n");
	end
	
	bPurgeInProgress = false;
	
	-- Stop all the timers just in-case.
	PURGE.KillTimers();
	
	-- Start the timers.
	timer.Create("Timer_SetPurgeTimer", 1, 1, PURGE.SetTimer);
	timer.Create("Timer_PurgeAnnouncement", (settings.fPurgeSetupTime * 60) - settings.fPurgeAnnouncementTime, 1, PURGE.Announcement);
	timer.Create("Timer_PurgeStart", settings.fPurgeSetupTime * 60, 1, PURGE.Start);
	timer.Create("Timer_PurgeOver", (settings.fPurgeSetupTime * 60) + (settings.fPurgeTime * 60), 1, PURGE.Over);
	
	if (settings.bDebug) then
		print("[PT DEBUG]Function SetUpPurge() :: Ended.\n");
	end
end

-- Hooks
hook.Add("InitPostEntity","SetupPurge",function()
	if (settings.bDebug) then
		print("[PT DEBUG]Hook SetupPurge :: Called.\n");
	end
	
	timer.Create("Timer_DelayPurgeStartup", 5.0, 1, function()
		PURGE.SetUpPurge();
	end);
end)

hook.Add("EntityTakeDamage", "SetVehicleDamage", function(target, damageinfo)
	local attacker = damageinfo:GetAttacker();
	if target:IsPlayer() and (attacker:IsVehicle() or (bit.band(damageinfo:GetDamageType(), DMG_VEHICLE) != 0)) and not bPurgeInProgress then
		-- Block vehicle damage when the Purge isn't active.
		damageinfo:ScaleDamage(0);
	end
end)

hook.Add("PlayerInitialSpawn","SendPurge", function (ply)
	if (settings.bDebug) then
		print("[PT DEBUG]Hook SendPurge :: Called.\n");
	end
	
	if(PURGE.Timer) then
		net.Start("PurgeTimer");
		net.WriteUInt(PURGE.Timer,32);
		net.Send(ply);
		
		if (settings.bDebug and ply) then
			print("[PT DEBUG]Sent PurgeTimer Network :: " .. ply:Nick() .. "\n");
		end
	elseif (PURGE.EndTimer) then
		net.Start("PurgeEndTimer");
		net.WriteUInt(PURGE.EndTimer,32);
		net.Send(ply);
	
		if (settings.bDebug and ply) then
			print("[PT DEBUG]Sent PurgeEndTimer Network :: " .. ply:Nick() .. "\n");
		end
	end
end)

concommand.Add("purge_start", function (ply)
	if not VerifyUser(ply) then
		ply:ChatPrint("[GFL]Only users on the whitelist can execute this command.");
		return;
	end
	
	if (settings.bDebug and ply) then
		print("[PT DEBUG]Concommand purge_start :: Called by " .. ply:Nick() .. " (" .. ply:SteamID() .. ").\n");
	end
	
	-- Check
	PURGE.KillTimers();
	
	if (settings.bDebug) then
		print("[PT DEBUG]Manually starting Purge.\n");
	end
	
	PURGE.Start();
	timer.Create("Timer_PurgeOver", settings.fPurgeTime * 60, 1, PURGE.Over);
end)

concommand.Add("purge_start2", function (ply)
	if not VerifyUser(ply) then
		ply:ChatPrint("[GFL]Only users on the whitelist can execute this command.")
		return
	end
	
	if (settings.bDebug and ply) then
		print("[PT DEBUG]Concommand purge_start2 :: Called by " .. ply:Nick() .. " (" .. ply:SteamID() .. ").\n");
	end
	
	-- Checks
	PURGE.KillTimers();
	
	PURGE.Announcement();
	timer.Create("Manual_PurgeStart", settings.fPurgeAnnouncementTime, 1, function()
		if (settings.bDebug) then
			print("[PT DEBUG]Manually starting Purge (announcement included).\n");
		end
		
		PURGE.Start();
		timer.Create("Timer_PurgeOver", settings.fPurgeTime * 60, 1, PURGE.Over);
	end);
end)


concommand.Add("purge_stop", function (ply)
	if not VerifyUser(ply) then
		ply:ChatPrint("[GFL]Only users on the whitelist can execute this command.");
		return;
	end
	
	if (settings.bDebug and ply) then
		print("[PT DEBUG]Concommand purge_stop :: Called by " .. ply:Nick() .. " (" .. ply:SteamID() .. ").\n");
	end
	
	PURGE.Over();
end)

concommand.Add("setup_purge", function (ply)
	if not VerifyUser(ply) then
		ply:ChatPrint("[GFL]Only users on the whitelist can execute this command.");
		return;
	end
	
	if (settings.bDebug and ply) then
		print("[PT DEBUG]Concommand setup_purge :: Called by " .. ply:Nick() .. " (" .. ply:SteamID() .. ").\n");
	end
	
	PURGE.SetUpPurge();
end)

concommand.Add("purge_status", function (ply)
	ply:ChatPrint("Timer_PurgeOver: " .. tostring(timer.Exists("Timer_PurgeOver")));
	ply:ChatPrint("Timer_PurgeStart: " .. tostring(timer.Exists("Timer_PurgeStart")));
	ply:ChatPrint("Manual_PurgeStart: " .. tostring(timer.Exists("Manual_PurgeStart")));
	ply:ChatPrint("Timer_PurgeAnnouncement: " .. tostring(timer.Exists("Timer_PurgeAnnouncement")));
end);

concommand.Add("purge_disable", function (ply)
	if not VerifyUser(ply) then
		ply:ChatPrint("[GFL]Only users on the whitelist can execute this command.");
		return;
	end
	
	PURGE.KillTimers();
	ply:ChatPrint("[PT]Purge is now disabled.");
	
	if (settings.bDebug and ply) then
		print("[PT DEBUG]Concommand purge_disable :: Called by " .. ply:Nick() .. " (" .. ply:SteamID() .. ").\n");
	end
end)

if settings.bCheck then
	timer.Create("Purge_Check", 30.0, 0, function()
		if not timer.Exists("Timer_PurgeOver") and not timer.Exists("Timer_PurgeStart") and not timer.Exists("Manual_PurgeStart") and not timer.Exists("Timer_PurgeAnnouncement") and not bInPrepareDelayTime then
			if (settings.bDebug) then
				print("[PT DEBUG]Check :: Found no Purge timers. Restarting game-mode.\n");
			end
			
			-- Nothing is happening. Therefore, we must reset the game-mode.
			PURGE.SetUpPurge();
		end
	end)
else
	if (timer.Exists("Purge_Check")) then
		timer.Stop("Purge_Check");
	end
end