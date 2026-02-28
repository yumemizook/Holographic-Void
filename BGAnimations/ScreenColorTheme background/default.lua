--- Holographic Void: ScreenColorTheme Background
-- Simple OLED black with subtle grid lines.

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
for i = 1, 15 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy((SCREEN_WIDTH / 16) * i, SCREEN_CENTER_Y)
				:zoomto(1, SCREEN_HEIGHT):diffuse(color("1,1,1,0.02"))
		end
	}
end

return t
