--- Holographic Void: MusicWheelItem SectionExpanded NormalPart
-- Group header row (expanded state).

local t = Def.ActorFrame {}

-- Background
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(280, 34):diffuse(color("0.10,0.10,0.10,1"))
	end,
	GainFocusCommand = function(self)
		self:stoptweening():linear(0.1)
			:diffuse(color("0.16,0.16,0.16,1"))
	end,
	LoseFocusCommand = function(self)
		self:stoptweening():linear(0.1)
			:diffuse(color("0.10,0.10,0.10,1"))
	end
}

-- Left accent bar (accent color for groups)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:x(-137):zoomto(4, 30):diffuse(color("#5ABAFF")):diffusealpha(0.5)
	end
}

-- Bottom border
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:y(17):zoomto(280, 1):diffuse(color("0.18,0.18,0.18,1"))
	end
}

return t
