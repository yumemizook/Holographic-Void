local t = Def.ActorFrame{}

t[#t+1] = Def.Quad{
	InitCommand=function(self)
		self:FullScreen():diffuse(HVColor.Background or color("#000000")):diffusealpha(1):smooth(0.3):diffusealpha(0)
	end
}

return t
