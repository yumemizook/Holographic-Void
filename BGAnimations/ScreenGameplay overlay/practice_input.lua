-- Holographic Void: Practice Mode Input Handler
-- Using CodeMessageCommands for maximum reliability (from metrics.ini)

local function getSongPos()
	return GAMESTATE:GetSongPosition():GetMusicSeconds()
end

local function setSongPos(pos)
	local top = SCREENMAN:GetTopScreen()
	if top and top.SetSongPosition then
		top:SetSongPosition(math.max(0, pos))
	end
end

-- Practice State (Shared via HV global)
HV = HV or {}
HV.PracticeLoopStart = HV.PracticeLoopStart or 0
HV.PracticeLoopEnd = HV.PracticeLoopEnd or 0

local function isPractice()
	return GAMESTATE:IsPracticeMode()
end

return Def.ActorFrame {
	OnCommand = function(self)
		if isPractice() then
			-- Show OS Cursor
			PREFSMAN:SetPreference("ShowMouseCursor", true)
		end
		
		-- Loop logic update
		if self.SetUpdateFunction then
			self:SetUpdateFunction(function(self)
				self:playcommand("UpdateLoop")
			end)
		else
			self:SetUpdate(true)
			self:setupdatecommand("UpdateLoop")
		end
	end,
	
	UpdateLoopCommand = function(self)
		if isPractice() and HV.PracticeLoopEnd > 0 and HV.PracticeLoopEnd > HV.PracticeLoopStart then
			local cur = getSongPos()
			if cur >= HV.PracticeLoopEnd then
				setSongPos(HV.PracticeLoopStart)
			end
		end
	end,
	
	EndCommand = function(self)
		if isPractice() then
			PREFSMAN:SetPreference("ShowMouseCursor", false)
		end
	end,

	-- ============================================================
	-- Native Code Mappings (from metrics.ini)
	-- ============================================================
	CodeMessageCommand = function(self, params)
		if not isPractice() then return end
		local name = params.Name
		local top = SCREENMAN:GetTopScreen()
		if not top then return end

		if name == "PracRateUp" then
			changeMusicRate(0.05)
		elseif name == "PracRateDown" then
			changeMusicRate(-0.05)
		elseif name == "PracPause" then
			top:TogglePause()
		elseif name == "PracRestart" then
			setSongPos(HV.PracticeLoopStart > 0 and HV.PracticeLoopStart or 0)
		elseif name == "PracLoopStart" then
			HV.PracticeLoopStart = getSongPos()
			ms.ok(string.format("Loop Start: %.2fs", HV.PracticeLoopStart))
			MESSAGEMAN:Broadcast("PracticeLoopChanged")
		elseif name == "PracLoopEnd" then
			HV.PracticeLoopEnd = getSongPos()
			ms.ok(string.format("Loop End: %.2fs", HV.PracticeLoopEnd))
			MESSAGEMAN:Broadcast("PracticeLoopChanged")
		elseif name == "PracLoopClear" then
			HV.PracticeLoopStart = 0
			HV.PracticeLoopEnd = 0
			ms.ok("Loop Cleared")
			MESSAGEMAN:Broadcast("PracticeLoopChanged")
		elseif name == "PracClap" then
			local cur = PREFSMAN:GetPreference("CenterClap")
			PREFSMAN:SetPreference("CenterClap", not cur)
			ms.ok("Clap: " .. (not cur and "ON" or "OFF"))
		elseif name == "PracMetronome" then
			local ps = GAMESTATE:GetPlayerState(PLAYER_1)
			local po = ps:GetPlayerOptions("ModsLevel_Current")
			local cur = po:AssistTick()
			po:AssistTick(not cur)
			ms.ok("Metronome: " .. (not cur and "ON" or "OFF"))
		elseif name == "PracAutoplay" then
			local ps = GAMESTATE:GetPlayerState(PLAYER_1)
			local cur = ps:GetPlayerController() == "PlayerController_Autoplay"
			ps:SetPlayerController(cur and "PlayerController_Human" or "PlayerController_Autoplay")
			ms.ok("Autoplay: " .. (not cur and "ON" or "OFF"))
		end
	end
}
