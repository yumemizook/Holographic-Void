--- Holographic Void: Shared Background Particles
-- Loads animated background particles based on ThemePrefs.

local t = Def.ActorFrame {}
local numParticles = 40

local function getIntensityAlpha(base)
	local intensity = tostring(ThemePrefs.Get("HV_BGAnimIntensity"))
	if intensity == "0" then return base * 0.3 end -- Static but visible
	if intensity == "1" then return base * 0.6 end
	return base
end

local function getIntensitySpeed(base)
	local intensity = tostring(ThemePrefs.Get("HV_BGAnimIntensity"))
	if intensity == "0" then return 0 end
	if intensity == "1" then return base * 0.4 end
	return base
end

local particleLayer = Def.ActorFrame {
	Name = "ParticleLayer",
	InitCommand = function(self)
		local showParticles = tostring(ThemePrefs.Get("HV_Particles")) == "true"
		self:visible(showParticles)
	end,
	ThemePrefChangedMessageCommand = function(self, params)
		if params and (params.Name == "HV_Particles" or params.Name == "HV_BGAnimIntensity") then
			local showParticles = tostring(ThemePrefs.Get("HV_Particles")) == "true"
			self:visible(showParticles)
			self:playcommand("Refresh")
		end
	end,
	OnCommand = function(self)
		self:playcommand("Refresh")
	end
}

-- Generate particles into the table definition
for i = 1, numParticles do
	particleLayer[#particleLayer + 1] = Def.Quad {
		InitCommand = function(self)
			self:x(math.random(SCREEN_WIDTH)):y(math.random(SCREEN_HEIGHT))
				:zoom(math.random(1, 3)):diffuse(HVColor.Accent)
		end,
		UpdateAlphaCommand = function(self)
			self:diffusealpha(getIntensityAlpha(math.random(10, 40)/100))
			if tostring(ThemePrefs.Get("HV_EnableGlow")) == "true" then
				self:glow(HVColor.Accent)
			else
				self:glow(color("0,0,0,0"))
			end
		end,
		OnCommand = function(self)
			self:playcommand("UpdateAlpha"):queuecommand("Move")
		end,
		RefreshCommand = function(self)
			self:stoptweening():playcommand("UpdateAlpha"):queuecommand("Move")
		end,
		MoveCommand = function(self)
			local dist = math.random(20, 50)
			local baseTime = math.random(2, 5)
			local speedScale = getIntensitySpeed(1)
			if speedScale <= 0 then return end
			
			local time = baseTime / speedScale
			self:linear(time):addx(dist * (math.random() > 0.5 and 1 or -1))
				:addy(dist * (math.random() > 0.5 and 1 or -1))
				:queuecommand("Move")
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" then
				self:diffuse(HVColor.Accent)
			end
		end
	}
end

t[#t + 1] = particleLayer

return t
