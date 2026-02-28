--- Holographic Void: Shared Background Particles
-- Loads animated background particles based on ThemePrefs.

local t = Def.ActorFrame {}
local numParticles = 40

local particleLayer = Def.ActorFrame {
	Name = "ParticleLayer",
	InitCommand = function(self)
		local showParticles = ThemePrefs.Get("HV_Particles") == "true" or ThemePrefs.Get("HV_Particles") == true
		self:visible(showParticles)
	end,
	ThemePrefChangedMessageCommand = function(self, params)
		if params and params.Name == "HV_Particles" then
			local showParticles = ThemePrefs.Get("HV_Particles") == "true" or ThemePrefs.Get("HV_Particles") == true
			self:visible(showParticles)
		end
	end
}

-- Generate particles into the table definition
for i = 1, numParticles do
	particleLayer[#particleLayer + 1] = Def.Quad {
		InitCommand = function(self)
			self:x(math.random(SCREEN_WIDTH)):y(math.random(SCREEN_HEIGHT))
				:zoom(math.random(1, 3))
				:diffuse(HVColor.Accent):diffusealpha(math.random(10, 40)/100)
		end,
		OnCommand = function(self)
			self:queuecommand("Move")
		end,
		MoveCommand = function(self)
			local dist = math.random(20, 50)
			local time = math.random(2, 5)
			self:linear(time):addx(dist * (math.random() > 0.5 and 1 or -1))
				:addy(dist * (math.random() > 0.5 and 1 or -1))
				:queuecommand("Move")
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if params and params.Name == "HV_AccentColor" then
				self:stoptweening():linear(0.2)
					:diffuse(HVColor.Accent):diffusealpha(math.random(10, 40)/100)
					:queuecommand("Move")
			end
		end
	}
end

t[#t + 1] = particleLayer

return t
