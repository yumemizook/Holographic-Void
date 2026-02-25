--- Holographic Void: ScreenOptionsTheme Background
-- Themed background for the theme options screen (ScreenOptionsServiceChild)

local t = Def.ActorFrame {}

-- OLED Black
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
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

-- Header accent line
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, 50)
			:zoomto(SCREEN_WIDTH * 0.5, 1)
			:diffuse(color("#5ABAFF")):diffusealpha(0.3)
	end
}

return t
