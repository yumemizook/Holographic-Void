--- Holographic Void: OptionRow Frame
-- Monochromatic option row styling for the options screens.

local t = Def.ActorFrame {}

-- Row background (subtle)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(SCREEN_WIDTH * 0.5, 28)
			:diffuse(color("0.05,0.05,0.05,0.5"))
	end,
	GainFocusCommand = function(self)
		self:stoptweening():linear(0.1)
			:diffuse(color("0.1,0.1,0.1,0.7"))
	end,
	LoseFocusCommand = function(self)
		self:stoptweening():linear(0.1)
			:diffuse(color("0.05,0.05,0.05,0.5"))
	end
}

-- Bottom separator
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:y(14):zoomto(SCREEN_WIDTH * 0.5, 1)
			:diffuse(color("0.12,0.12,0.12,1"))
	end
}

return t
