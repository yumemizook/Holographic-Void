--- Holographic Void: MusicWheelItem Song NormalPart
-- Monochromatic song row with sharp-edged card background.

local t = Def.ActorFrame {}

-- Card background
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(280, 32):diffuse(color("0.08,0.08,0.08,1"))
	end,
	SetMessageCommand = function(self)
		self:stoptweening():linear(0.1)
	end,
	GainFocusCommand = function(self)
		self:stoptweening():linear(0.1)
			:diffuse(color("0.14,0.14,0.14,1"))
	end,
	LoseFocusCommand = function(self)
		self:stoptweening():linear(0.1)
			:diffuse(color("0.08,0.08,0.08,1"))
	end
}

-- Left accent bar (difficulty color — set by the engine/theme)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:x(-137):zoomto(3, 28)
			:diffuse(color("0.3,0.3,0.3,1"))
	end,
	SetGradeCommand = function(self, params)
		-- difficulty color can be applied here
	end
}

-- Bottom border line
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:y(16):zoomto(280, 1)
			:diffuse(color("0.12,0.12,0.12,1"))
	end
}

return t
