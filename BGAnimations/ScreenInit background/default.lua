--- Holographic Void: ScreenInit Background
-- Minimal OLED-black init screen with theme branding.
-- Shows theme name, version, and a subtle loading animation.

local t = Def.ActorFrame {}

-- Full-screen OLED black background
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
	end,
	OnCommand = function(self)
		self:diffuse(color("0,0,0,1"))
	end
}

-- Thin horizontal accent line (animates in)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(0, 1)
	end,
	OnCommand = function(self)
		self:diffuse(HVColor.Accent):diffusealpha(0.8)
			:linear(0.6):zoomto(SCREEN_WIDTH * 0.4, 1)
			:sleep(1.2)
			:linear(0.4):diffusealpha(0)
	end
}

-- Theme name
t[#t + 1] = LoadFont("Common Large") .. {
	Text = "HOLOGRAPHIC VOID",
	InitCommand = function(self)
		self:Center():y(SCREEN_CENTER_Y - 20):zoom(0.6)
	end,
	OnCommand = function(self)
		self:diffuse(color("1,1,1,1")):diffusealpha(0)
			:sleep(0.2):linear(0.5):diffusealpha(1)
			:sleep(1.0):linear(0.3):diffusealpha(0)
	end
}

-- Version subtitle
t[#t + 1] = LoadFont("Common Normal") .. {
	Text = "v0.1.0",
	InitCommand = function(self)
		self:Center():y(SCREEN_CENTER_Y + 8):zoom(0.6)
	end,
	OnCommand = function(self)
		self:diffuse(color("0.5,0.5,0.5,1")):diffusealpha(0)
			:sleep(0.4):linear(0.4):diffusealpha(0.6)
			:sleep(0.8):linear(0.3):diffusealpha(0)
	end
}

-- Loading dots animation (three dots pulsing)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:Center():y(SCREEN_CENTER_Y + 40)
	end,
	OnCommand = function(self)
		self:diffusealpha(0):sleep(0.8):linear(0.3):diffusealpha(1)
			:sleep(0.9):linear(0.3):diffusealpha(0)
	end,

	-- Dot 1
	Def.Quad {
		InitCommand = function(self)
			self:x(-12):zoomto(4, 4)
		end,
		OnCommand = function(self)
			self:diffuse(color("0.6,0.6,0.6,1"))
				:queuecommand("Pulse")
		end,
		PulseCommand = function(self)
			self:linear(0.3):diffusealpha(1)
				:linear(0.3):diffusealpha(0.3)
				:queuecommand("Pulse")
		end
	},
	-- Dot 2
	Def.Quad {
		InitCommand = function(self)
			self:x(0):zoomto(4, 4)
		end,
		OnCommand = function(self)
			self:diffuse(color("0.6,0.6,0.6,1")):diffusealpha(0.3)
				:sleep(0.15):queuecommand("Pulse")
		end,
		PulseCommand = function(self)
			self:linear(0.3):diffusealpha(1)
				:linear(0.3):diffusealpha(0.3)
				:queuecommand("Pulse")
		end
	},
	-- Dot 3
	Def.Quad {
		InitCommand = function(self)
			self:x(12):zoomto(4, 4)
		end,
		OnCommand = function(self)
			self:diffuse(color("0.6,0.6,0.6,1")):diffusealpha(0.3)
				:sleep(0.3):queuecommand("Pulse")
		end,
		PulseCommand = function(self)
			self:linear(0.3):diffusealpha(1)
				:linear(0.3):diffusealpha(0.3)
				:queuecommand("Pulse")
		end
	}
}

return t
