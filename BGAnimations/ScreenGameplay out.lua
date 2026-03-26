local t = Def.ActorFrame{
	InitCommand = function(self)
		self:diffusealpha(0)
	end,
	OffCommand = function(self)
		self:sleep(3)
		self:smooth(1)
		self:diffusealpha(1)
		self:sleep(1)
	end
}

t[#t+1] = Def.Quad{
	InitCommand = function(self)
		self:FullScreen():diffuse(HVColor.Background or color("#000000")):diffusealpha(1)
	end
}

t[#t+1] = Def.Quad{
	InitCommand = function(self)
		self:diffusealpha(0)
		self:Center()
		self:zoomto(SCREEN_WIDTH, 60)
		self:smooth(1)
		self:diffuse(color("0,0,0,0.8"))
	end,
	OffCommand = function(self)
		self:sleep(4)
		self:smooth(1)
		self:diffusealpha(0)
	end
}

t[#t+1] = LoadFont("Common Normal")..{
	InitCommand = function(self)
		self:settext("Stage Cleared")
		self:Center()
		self:zoom(0.6)
		self:diffusealpha(0)
		self:smooth(1)
		self:diffusealpha(0.8)
		self:diffuseshift()
		self:effectcolor1(color("#FFFFFF")):effectcolor2(HVColor.Accent or color("#00FF00"))
	end,
	OffCommand = function(self)
		self:sleep(4)
		self:smooth(1)
		self:diffusealpha(0)
	end
}

return t
