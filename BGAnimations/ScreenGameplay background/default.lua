--- Holographic Void: ScreenGameplay Background
-- Minimal OLED black with subtle animated accent elements.
-- Keeps the notefield the focus while maintaining the theme identity.

local t = Def.ActorFrame {}

-- Full-screen OLED black
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Subtle top border accent (very dim, doesn't distract)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_TOP + 1)
			:zoomto(SCREEN_WIDTH, 1)
			:diffuse(color("#5ABAFF")):diffusealpha(0.08)
	end
}

-- Subtle bottom border accent
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 1)
			:zoomto(SCREEN_WIDTH, 1)
			:diffuse(color("#5ABAFF")):diffusealpha(0.08)
	end
}

return t
