--- Holographic Void: ScreenSelectMusic Background
-- OLED black with subtle animated scan lines.

local t = Def.ActorFrame {}

-- Full-screen OLED black
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
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

return t
