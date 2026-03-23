--- Holographic Void: ScreenInit Background
-- Modernized, sleek initialization screen with a holographic vibe.

local t = Def.ActorFrame {}

-- 1. Void Gradient Background
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
	end,
	OnCommand = function(self)
		self:diffusetopedge(color("#050510"))
		self:diffusebottomedge(color("#000000"))
		self:diffusealpha(0):linear(0.3):diffusealpha(1)
	end
}

-- 2. Ambient Grid / Lines (Holographic effect)
local gridFrame = Def.ActorFrame {
	InitCommand = function(self) self:Center() end,
}
for i = -4, 4 do
	-- Horizontal lines fade out from center
	gridFrame[#gridFrame + 1] = Def.Quad {
		InitCommand = function(self)
			self:y(i * 35):zoomto(SCREEN_WIDTH, 1)
		end,
		OnCommand = function(self)
			self:diffuse(HVColor.Accent):diffusealpha(0)
				:sleep(0.1 + math.abs(i) * 0.05)
				:linear(0.4):diffusealpha(0.08)
				:sleep(1.2 - math.abs(i) * 0.05)
				:linear(0.5):diffusealpha(0)
		end
	}
end
t[#t + 1] = gridFrame

-- 3. Center Glow / Light burst
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, 100)
		self:blend("BlendMode_Add")
		self:fadetop(1):fadebottom(1)
	end,
	OnCommand = function(self)
		self:diffuse(HVColor.Accent):diffusealpha(0)
			:linear(0.5):diffusealpha(0.20):zoomto(SCREEN_WIDTH, 40)
			:sleep(1.2)
			:linear(0.5):diffusealpha(0)
	end
}

-- 4. Text - Chromatic Aberration
local textGroup = Def.ActorFrame {
	InitCommand = function(self) self:Center():y(SCREEN_CENTER_Y - 15) end,
	-- Cyan layer (moves right to center)
	LoadFont("Common Large") .. {
		Text = "HOLOGRAPHIC VOID",
		InitCommand = function(self) self:zoom(0.6):x(-15):diffuse(color("#00FFFF")):blend("BlendMode_Add") end,
		OnCommand = function(self)
			self:diffusealpha(0)
				:decelerate(0.5):diffusealpha(0.8):x(-2)
				:sleep(1.2)
				:accelerate(0.5):diffusealpha(0):x(-10)
		end
	},
	-- Magenta layer (moves left to center)
	LoadFont("Common Large") .. {
		Text = "HOLOGRAPHIC VOID",
		InitCommand = function(self) self:zoom(0.6):x(15):diffuse(color("#FF00FF")):blend("BlendMode_Add") end,
		OnCommand = function(self)
			self:diffusealpha(0)
				:decelerate(0.5):diffusealpha(0.8):x(2)
				:sleep(1.2)
				:accelerate(0.5):diffusealpha(0):x(10)
		end
	},
	-- Main White layer
	LoadFont("Common Large") .. {
		Text = "HOLOGRAPHIC VOID",
		InitCommand = function(self) self:zoom(0.6):x(0) end,
		OnCommand = function(self)
			self:diffusealpha(0)
				:decelerate(0.5):diffusealpha(1)
				:sleep(1.2)
				:accelerate(0.5):diffusealpha(0)
		end
	}
}
t[#t + 1] = textGroup

-- 5. Version Subtitle
local themeVersion = "Unknown"
local themeName = THEME:GetCurThemeName()
local paths = {
	"Themes/" .. themeName .. "/ThemeInfo.ini",
	"ThemeInfo.ini"
}

-- Add GetCurrentThemeDirectory only if it exists
if THEME.GetCurrentThemeDirectory then
	table.insert(paths, 1, THEME:GetCurrentThemeDirectory() .. "ThemeInfo.ini")
end

for _, path in ipairs(paths) do
	local info = IniFile.ReadFile(path)
	if info and info["ThemeInfo"] and info["ThemeInfo"]["Version"] then
		themeVersion = info["ThemeInfo"]["Version"]
		break
	end
end

t[#t + 1] = LoadFont("Common Normal") .. {
	Text = "v" .. themeVersion,
	InitCommand = function(self) self:Center():y(SCREEN_CENTER_Y + 15):zoom(0.5) end,
	OnCommand = function(self)
		self:diffuse(color("0.6,0.6,0.6,1")):diffusealpha(0)
			:sleep(0.3):decelerate(0.4):diffusealpha(0.9):y(SCREEN_CENTER_Y + 7)
			:sleep(1.0):accelerate(0.5):diffusealpha(0):y(SCREEN_CENTER_Y + 15)
	end
}

-- 6. Modern Loading Bar / Scanning Line
t[#t + 1] = Def.Quad {
	InitCommand = function(self) 
		self:Center():y(SCREEN_CENTER_Y + 30):zoomto(0, 2)
	end,
	OnCommand = function(self)
		self:diffuse(HVColor.Accent):diffusealpha(0)
			:sleep(0.4):diffusealpha(0.9)
			:decelerate(0.8):zoomto(200, 2)
			:sleep(0.5)
			:accelerate(0.5):zoomto(0, 1):diffusealpha(0)
	end
}

return t
