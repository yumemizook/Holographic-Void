--- Holographic Void: ScreenGameplay Background
-- Minimal OLED black with subtle animated accent elements.
-- Keeps the notefield the focus while maintaining the theme identity.

local t = Def.ActorFrame {}

-- Full-screen filter/background
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		local filterVal = tonumber(ThemePrefs.Get("HV_ScreenFilter")) or 0
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			:diffuse(color("0,0,0,1")):diffusealpha(math.max(1, filterVal))
		-- Note: In this theme, the background is always black, 
		-- so the filter essentially controls the "blackness" vs "nothing".
		-- Since we don't have song backgrounds enabled yet, this is mostly a placeholder
		-- for when song backgrounds are added.
	end
}

-- Subtle top border accent (very dim, doesn't distract)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_TOP + 1)
			:zoomto(SCREEN_WIDTH, 1)
			:diffuse(HVColor.Accent):diffusealpha(0.08)
	end
}

-- Subtle bottom border accent
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 1)
			:zoomto(SCREEN_WIDTH, 1)
			:diffuse(HVColor.Accent):diffusealpha(0.08)
	end
}

return t
