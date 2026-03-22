--- Holographic Void: ScreenSelectMusic Out Transition
-- Shows "Press Start again for Options" prompt when a song is selected,
-- and "Entering Options..." when Start is pressed a second time.
-- Engine broadcasts: ShowPressStartForOptionsCommand, ShowEnteringOptionsCommand,
-- HidePressStartForOptionsCommand to actors in this file.

local translated_info = {
	PressStart = THEME:GetString("ScreenSelectMusic", "PressStartForOptions"),
	EnteringOptions = THEME:GetString("ScreenSelectMusic", "EnteringOptions"),
}

local t = Def.ActorFrame {}

-- Black fade overlay
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
	end,
	OnCommand = function(self)
		self:diffuse(color("0,0,0,0")):sleep(0.1):linear(0.15):diffusealpha(1)
	end
}

-- Prompt container
t[#t + 1] = Def.ActorFrame {
	Name = "OptionsPrompt",
	InitCommand = function(self)
		self:Center():diffusealpha(0)
	end,
	ShowPressStartForOptionsCommand = function(self)
		self:stoptweening():zoom(0.92):diffusealpha(0)
			:decelerate(0.2):zoom(1):diffusealpha(1)
	end,
	ShowEnteringOptionsCommand = function(self)
		-- Container stays visible; text swap handled by children
	end,
	HidePressStartForOptionsCommand = function(self)
		self:stoptweening():decelerate(0.15):diffusealpha(0)
	end,

	-- Background card
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(420, 60):diffuse(color("0.04,0.04,0.04,0.95"))
		end,
	},

	-- Accent border (top)
	Def.Quad {
		InitCommand = function(self)
			self:valign(0):y(-30):zoomto(420, 2)
				:diffuse(HVColor.Accent):diffusealpha(0.6)
		end,
	},

	-- Accent border (bottom)
	Def.Quad {
		InitCommand = function(self)
			self:valign(1):y(30):zoomto(420, 1)
				:diffuse(HVColor.Accent):diffusealpha(0.2)
		end,
	},

	-- "Press Start again for Options" text
	LoadFont("Common Normal") .. {
		Name = "PressStartText",
		InitCommand = function(self)
			self:zoom(0.55):diffuse(color("0.9,0.9,0.9,1")):diffusealpha(0)
		end,
		ShowPressStartForOptionsCommand = function(self)
			self:settext(translated_info["PressStart"])
				:stoptweening():diffusealpha(0):zoom(0.45)
				:decelerate(0.2):zoom(0.55):diffusealpha(1)
		end,
		ShowEnteringOptionsCommand = function(self)
			self:stoptweening():settext(translated_info["EnteringOptions"])
				:diffuse(HVColor.Accent):diffusealpha(1)
		end,
		HidePressStartForOptionsCommand = function(self)
			self:stoptweening():decelerate(0.15):diffusealpha(0)
		end,
	},
}

return t
