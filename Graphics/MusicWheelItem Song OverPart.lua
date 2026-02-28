--- Holographic Void: MusicWheelItem Song OverPart (highlight overlay)
-- Pulsing glow on the focused item.

local accentColor = HVColor.Accent

local t = Def.ActorFrame {}

-- Pulsing focus highlight overlay
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(280, 32)
			:diffuse(accentColor):diffusealpha(0)
	end,
	GainFocusCommand = function(self)
		self:stoptweening()
			:diffusealpha(0.06)
			:loop()
			:linear(0.8):diffusealpha(0.14)
			:linear(0.8):diffusealpha(0.06)
	end,
	LoseFocusCommand = function(self)
		self:stoptweening()
			:linear(0.12):diffusealpha(0)
	end
}

-- Left edge accent bar - pulsing on focus
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:x(-139):zoomto(2, 32)
			:diffuse(accentColor):diffusealpha(0)
	end,
	GainFocusCommand = function(self)
		self:stoptweening()
			:diffusealpha(0.4)
			:loop()
			:linear(0.8):diffusealpha(0.9)
			:linear(0.8):diffusealpha(0.4)
	end,
	LoseFocusCommand = function(self)
		self:stoptweening()
			:linear(0.12):diffusealpha(0)
	end
}

return t
