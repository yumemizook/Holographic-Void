--- Holographic Void: ScreenEvaluation Background

local t = Def.ActorFrame {}

-- OLED Black
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Song Background Sprite
t[#t + 1] = Def.Sprite {
	Name = "SongBackground",
	InitCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		local showBG = HV.ShowSongBackground()
		if song and showBG and song:GetBackgroundPath() then
			self:visible(true):LoadBackground(song:GetBackgroundPath())
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			local brightness = HV.GetSongBackgroundBrightness()
			self:diffusealpha(brightness)
		else
			self:visible(false)
		end
	end
}

-- Subtle grid
for i = 1, 8 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i)
				:zoomto(SCREEN_WIDTH, 1):diffuse(color("1,1,1,0.02"))
		end
	}
end

-- Load Shared Background Particles
t[#t + 1] = LoadActor("../_particles.lua")

return t
