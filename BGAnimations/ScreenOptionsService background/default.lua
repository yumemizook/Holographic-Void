local t = Def.ActorFrame {}

-- Background Image
t[#t + 1] = LoadActor(THEME:GetPathG("", "background.jpg")) .. {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
	end
}

-- Grey Quad Overlay
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			:diffuse(color("0.08,0.08,0.08,0.8"))
	end
}

-- Particles
t[#t + 1] = LoadActor("../_particles.lua")

return t
