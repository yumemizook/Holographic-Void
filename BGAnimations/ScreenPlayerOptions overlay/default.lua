local t = Def.ActorFrame {
	Name = "PlayerOptionsOverlay",
}

-- helper to get song bpm
local function getSongBPM()
	local song = GAMESTATE:GetCurrentSong()
	if not song then return 0 end
	local state = GAMESTATE:GetSongOptionsObject("ModsLevel_Current")
	local rate = state:MusicRate() or 1
	local bpms = song:GetDisplayBpms()
	if bpms[1] == bpms[2] then
		return bpms[1] * rate
	else
		-- for variable bpm, we can't easily show a single number, 
		-- but we can show the "max" or "common" or just the range.
		-- let's use the max for readability.
		return bpms[2] * rate
	end
end

-- Current Player Speed Display
t[#t + 1] = Def.ActorFrame {
	Name = "SpeedDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_LEFT + 60, SCREEN_CENTER_Y)
	end,

	-- Label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.4):diffuse(HVColor.TextDim):halign(0)
			self:settext("SPEED")
		end
	},

	-- Value
	LoadFont("Common Normal") .. {
		Name = "SpeedValue",
		InitCommand = function(self)
			self:y(24):zoom(0.8):diffuse(HVColor.Accent):halign(0)
		end,
		SetCommand = function(self)
			local ps = GAMESTATE:GetPlayerState()
			if not ps then return end
			local po = ps:GetPlayerOptions("ModsLevel_Preferred")
			if not po then return end

			local songBPM = getSongBPM()
			local displayStr = ""

			local cmod = po:CMod()
			if cmod and cmod > 0 then
				displayStr = string.format("C%.0f (%.0f)", cmod, cmod)
			else
				local xmod = po:ScrollSpeed()
				if xmod then
					local effectiveBPM = songBPM * xmod
					displayStr = string.format("%.2fx (%.0f)", xmod, effectiveBPM)
				else
					displayStr = "???"
				end
			end
			self:settext(displayStr)
		end,
		OnCommand = function(self)
			self:queuecommand("Set")
		end,
		PlayerOptionsChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		InitCommand = function(self)
			self:y(24):zoom(0.8):diffuse(HVColor.Accent):halign(0)
			self:SetUpdateFunction(function(self)
				self:playcommand("Set")
			end)
		end
	}
}

return t
