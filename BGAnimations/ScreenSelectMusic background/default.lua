--- Holographic Void: ScreenSelectMusic Background
-- OLED black with subtle animated scan lines.

local t = Def.ActorFrame {}

-- Full-screen OLED black
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Song Background Sprite
t[#t + 1] = Def.Sprite {
	Name = "SongBackground",
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			:diffusealpha(0)
	end,
	OnCommand = function(self)
		self:playcommand("Set")
	end,
	CurrentSongChangedMessageCommand = function(self)
		self:playcommand("Set")
	end,
	SetCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		local showBG = HV.ShowSongBackground()
		if song and showBG and song:GetBackgroundPath() then
			self:visible(true):LoadBackground(song:GetBackgroundPath())
			self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			local brightness = HV.GetSongBackgroundBrightness()
			self:stoptweening():linear(0.2):diffusealpha(brightness)
		else
			self:stoptweening():linear(0.2):diffusealpha(0)
		end
	end
}

-- Subtle horizontal scan lines (every 3 pixels for a CRT effect)
for i = 0, math.floor(SCREEN_HEIGHT / 6) do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, i * 6)
				:zoomto(SCREEN_WIDTH, 1)
				:diffuse(color("1,1,1,0.015"))
		end
	}
end

-- Header accent line
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, 50)
			:zoomto(SCREEN_WIDTH * 0.5, 1)
			:diffuse(HVColor.Accent):diffusealpha(0.3)
	end
}

-- Load Shared Background Particles
t[#t + 1] = LoadActor("../_particles.lua")

return t
