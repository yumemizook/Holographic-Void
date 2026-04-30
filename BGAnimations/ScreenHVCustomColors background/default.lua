--- Holographic Void: ScreenHVCustomColors Background
local t = Def.ActorFrame {}

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,0.9"))
	end
}

t[#t + 1] = LoadActor("../_particles.lua")

return t
