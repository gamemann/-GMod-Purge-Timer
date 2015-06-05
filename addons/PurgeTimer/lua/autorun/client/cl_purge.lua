local ttimer = nil
local etimer = nil

local bPurgeInProgress = false

surface.CreateFont( "FeastOfFleshA", {
	font = "Feast Of Flesh BB",
	size = 90,
	weight = 300,
	antialias = true,
})

surface.CreateFont( "FeastOfFleshB", {
	font = "Feast Of Flesh BB",
	size = 48,
	weight = 500,
	antialias = true,
})

net.Receive("PurgeTimer",function()
	ttimer = net.ReadUInt(32)
	bPurgeInProgress = false
end)

net.Receive("PurgeEndTimer",function()
	etimer = net.ReadUInt(32)
	bPurgeInProgress = true
end)

usermessage.Hook("PurgeStart", function(umsg)
	if (IsValid(station)) then station:Play() end
	chat.AddText(Color(200,72,72),"[ALERT] ",Color(255,255,255),"The Purge has begun! All crime is legal for 12 minutes! Good luck!")
	bPurgeInProgress = true
end)

usermessage.Hook("LightStyleSet", function(umsg)
	render.RedownloadAllLightmaps()
	timer.Simple(4,function()
		render.RedownloadAllLightmaps()
	end)
end)

usermessage.Hook("PurgeOver", function(umsg)
	chat.AddText(Color(200,72,72),"[ALERT] ",Color(255,255,255),"The Purge has ended! Congratulations to everybody that survived!")
	bPurgeInProgress = false
end)

hook.Add("HUDPaint","PurgePaint",function()
	if(ttimer) then
		local tleft = ttimer-CurTime()
		if(tleft <= 0 or bPurgeInProgress) then
			ttimer = nil
			return
		end
		if (ttimer) then
			draw.SimpleText("THE PURGE BEGINS IN:","FeastOfFleshB",ScrW()/2,30,Color(200,7,7,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
			draw.SimpleText(string.FormattedTime(tleft,"%02i:%02i"),"FeastOfFleshA",ScrW()/2,110,Color(200,7,7,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		end
	elseif (etimer) then
		local eleft = etimer-CurTime()
		if(eleft <= 0 or not bPurgeInProgress) then
			etimer = nil
			return
		end
		if (etimer) then
			draw.SimpleText("THE PURGE ENDS IN:","FeastOfFleshB",ScrW()/2,30,Color(122,0,0,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
			draw.SimpleText(string.FormattedTime(eleft,"%02i:%02i"),"FeastOfFleshA",ScrW()/2,110,Color(122,0,0,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
		end
	end
end)