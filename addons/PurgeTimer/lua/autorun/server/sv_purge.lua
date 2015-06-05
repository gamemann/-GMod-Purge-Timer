PURGE = {}

-- Networking
util.AddNetworkString("PurgeTimer")
util.AddNetworkString("PurgeEndTimer")

-- Global Variables
local bTakeDamage = false
local iRounds = 0
local bPurgeInProgress = false

-- ConVars/Settings
local pt1 = CreateConVar("sv_purge_time", "12", _, "The amount of time the Purge lasts for in minutes.");
local pt2 = CreateConVar("sv_purge_setup_time", "45", _, "The amount of time until the Purge begins (setup time) in minutes.");
local pt3 = CreateConVar("sv_purge_announcement_time", "52", _, "The amount of time the announcement before the Purge begins takes (length of the file) in seconds");
local pt4 = CreateConVar("sv_purge_maxrounds", "16", _, "The maximum rounds (Purge beginning to end) until the map restarts to clear the precache table");

local settings = {}
settings.fPurgeTime = pt1:GetFloat();
settings.fPurgeSetupTime = pt2:GetFloat();
settings.fPurgeAnnouncementTime = pt3:GetFloat();
settings.iPurgeMaxRounds = pt4:GetInt();

-- Settings not with ConVars (feel free to edit)
settings.arrWhiteList = 
{
	"STEAM_0:0:36969327", 	-- [GFL] Roy (Christian Deacon)
	"STEAM_0:1:19665197", 	-- Cypher
	"STEAM_0:1:938085" 		-- X2D
};

cvars.AddChangeCallback("sv_purge_time", function (sCVarName, sOldv, sNewv)
	settings.fPurgeTime = pt1:GetFloat();
end)

cvars.AddChangeCallback("sv_purge_setup_time", function (sCVarName, sOldv, sNewv)
	settings.fPurgeSetupTime = pt2:GetFloat();
end)

cvars.AddChangeCallback("sv_purge_announcement_time", function (sCVarName, sOldv, sNewv)
	settings.fPurgeAnnouncementTime = pt3:GetFloat();
end)

cvars.AddChangeCallback("sv_purge_maxrounds", function (sCVarName, sOldv, sNewv)
	settings.iPurgeMaxRounds = pt4:GetInt();
end)

-- Verify Users
local function VerifyUser (ply)
	local bAllow = false;
	for _,v in pairs (settings.arrWhiteList) do
		if ply:SteamID() == v then
			bAllow = true;
		end
	end
	
	return bAllow;
end

-- Timers
local function SetPurgeTimer()
	PURGE.SetNight(false)
	bTakeDamage = false
	PURGE.Timer = CurTime()+settings.fPurgeSetupTime*60
	net.Start("PurgeTimer")
	net.WriteUInt(PURGE.Timer,32)
	net.Broadcast()
	BroadcastLua([[chat.AddText(Color(200,72,72),"[ALERT] ",Color(255,255,255),"The Purge starts in 45 minutes!")]])
	bPurgeInProgress = false
end

local function PurgeStart()
	umsg.Start("PurgeStart")
	umsg.End()
	PURGE.SetNight(true)
	PURGE.Timer = nil
	bTakeDamage = true
	bPurgeInProgress = true
	
	-- Let's make the purge end timer!
	PURGE.EndTimer = CurTime()+settings.fPurgeTime*60
	net.Start("PurgeEndTimer")
	net.WriteUInt(PURGE.EndTimer,32)
	net.Broadcast()
end

local function PurgeAnnouncement()
	-- Play the announcement!
	for k, ply in pairs( player.GetAll() ) do
		ply:EmitSound("weapons/purge/purge.mp3")
	end
end

local function PurgeOver()
	umsg.Start("PurgeOver")
	umsg.End()
	for k, ply in pairs( player.GetAll() ) do
		ply:EmitSound("weapons/purge/purge_end.mp3")
	end
	PURGE.SetNight(false)
	PURGE.EndTimer = nil
	bPurgeInProgress = false
	-- Add the rounds up
	iRounds = iRounds + 1
	if (iRounds >= settings.iPurgeMaxRounds) then
		-- Change the map.
		for _,v in pairs(player.GetAll()) do
			v:ChatPrint("Restarting the map in 5 seconds! This is to clear the model precache!")
			v:ChatPrint("Restarting the map in 5 seconds! This is to clear the model precache!")
			v:ChatPrint("Restarting the map in 5 seconds! This is to clear the model precache!")
		end
		timer.Simple(5, function()
			RunConsoleCommand("changelevel", game.GetMap())
		end)
	end
	
	-- Stop all the timers just in-case.
	timer.Stop("Timer_SetPurgeTimer");
	timer.Stop("Timer_PurgeStart");
	timer.Stop("Timer_PurgeAnnouncement");
	timer.Stop("Timer_PurgeOver");
	timer.Stop("Manual_PurgeStart");
	bPurgeInProgress = false
	
	-- Start the timers.
	timer.Create("Timer_SetPurgeTimer", 1, 1, SetPurgeTimer)
	timer.Create("Timer_PurgeStart", settings.fPurgeSetupTime * 60, 1, PurgeStart)
	timer.Create("Timer_PurgeAnnouncement", settings.fPurgeSetupTime * 60 - settings.fPurgeAnnouncementTime, 1, PurgeAnnouncement)
	timer.Create("Timer_PurgeOver", settings.fPurgeSetupTime * 60 + settings.fPurgeTime * 60, 1, PurgeOver) -- 720 = 12 minutes
end

-- Global functions used for rounds.
local function GB_SetUpPurge()
	-- Stop all the timers just in-case.
	timer.Stop("Timer_SetPurgeTimer");
	timer.Stop("Timer_PurgeStart");
	timer.Stop("Timer_PurgeAnnouncement");
	timer.Stop("Timer_PurgeOver");
	timer.Stop("Manual_PurgeStart");
	bPurgeInProgress = false
	
	-- Start the timers.
	timer.Create("Timer_SetPurgeTimer", 1, 1, SetPurgeTimer)
	timer.Create("Timer_PurgeStart", settings.fPurgeSetupTime * 60, 1, PurgeStart)
	timer.Create("Timer_PurgeAnnouncement", settings.fPurgeSetupTime * 60 - settings.fPurgeAnnouncementTime, 1, PurgeAnnouncement)
	timer.Create("Timer_PurgeOver", settings.fPurgeSetupTime * 60 + settings.fPurgeTime * 60, 1, PurgeOver) -- 720 = 12 minutes
end

hook.Add("InitPostEntity","SetupPurge",function()
	GB_SetUpPurge()
end)

hook.Add("EntitybTakeDamage", "vehicledamage", function(target, damageinfo)
	local attacker = damageinfo:GetAttacker()
	if target:IsPlayer() and (attacker:IsVehicle() or (bit.band(damageinfo:GetDamageType(), DMG_VEHICLE) != 0)) and not bPurgeInProgress then
		-- So block vehicle damage when Purge isn't going on!
		damageinfo:ScaleDamage(0)
	end
end)

hook.Add("PlayerInitialSpawn","SendPurge",function(ply)
	if(PURGE.Timer) then
		net.Start("PurgeTimer")
		net.WriteUInt(PURGE.Timer,32)
		net.Send(ply)
	elseif (PURGE.EndTimer) then
		net.Start("PurgeEndTimer")
		net.WriteUInt(PURGE.EndTimer,32)
		net.Send(ply)
	end
end)

function PURGE.SetNight(night)
	if(night) then
		-- Set the lighting
		local lightenvs = ents.FindByClass("light_environment")
		for _, light in pairs(lightenvs) do
			if (IsValid(light)) then
				 light:Fire( 'FadeToPattern' , 'a' , 0 ) // Makes the light fully dark, z is fully bright.
			end
		end
	else
		-- Set the lighting
		local lightenvs = ents.FindByClass("light_environment")
		for _, light in pairs(lightenvs) do
			if (IsValid(light)) then
				 light:Fire( 'FadeToPattern' , 'v' , 0 ) // Makes the light fully dark, z is fully bright.
			end
		end
	end
end

-- Manual Commands
concommand.Add("start_purge", function (ply)
	if not VerifyUser(ply) then
		ply:ChatPrint("[GFL]Only users on the whitelist can execute this command.")
		return
	end
	
	-- Start the Purge!
	
	-- Checks
	timer.Stop("Timer_PurgeStart")
	timer.Stop("Timer_PurgeOver")
	timer.Stop("Timer_PurgeAnnouncement")
	
	PurgeStart()
	timer.Create("Timer_PurgeOver", settings.fPurgeTime * 60, 1, PurgeOver) -- 720 = 12 minutes
	
end)

local function Manual_PurgeStart()
	-- Start the Purge!
	
	-- Checks
	timer.Stop("Timer_PurgeStart")
	timer.Stop("Timer_PurgeOver")
	timer.Stop("Timer_PurgeAnnouncement")
	
	PurgeStart()
	timer.Create("Timer_PurgeOver", settings.fPurgeTime * 60, 1, PurgeOver) -- 720 = 12 minutes
end

concommand.Add("start_purge2", function (ply)
	if not VerifyUser(ply) then
		ply:ChatPrint("[GFL]Only users on the whitelist can execute this command.")
		return
	end
	
	-- Checks
	timer.Stop("Timer_PurgeStart")
	timer.Stop("Timer_PurgeOver")
	timer.Stop("Timer_PurgeAnnouncement")
	
	-- Start the purge with the announcement!
	PurgeAnnouncement()
	timer.Create("Manual_PurgeStart", settings.fPurgeAnnouncementTime, 1, Manual_PurgeStart)
end)


concommand.Add("stop_purge", function (ply)
	if not VerifyUser(ply) then
		ply:ChatPrint("[GFL]Only users on the whitelist can execute this command.")
		return
	end
	
	-- End the Purge!
	PurgeOver()
end)

concommand.Add("setup_purge", function (ply)
	if not VerifyUser(ply) then
		ply:ChatPrint("[GFL]Only users on the whitelist can execute this command.")
		return
	end
	
	GB_SetUpPurge()
end)