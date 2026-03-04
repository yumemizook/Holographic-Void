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

-- Clear-type specific Full Combo animation
t[#t+1] = Def.ActorFrame{
	InitCommand = function(self)
		self:Center()
		self:diffusealpha(0)
		self:y(SCREEN_CENTER_Y + 50)
	end,
	OffCommand = function(self)
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(PLAYER_1)
		if pss then
			local steps = GAMESTATE:GetCurrentSteps(PLAYER_1)
			-- getClearType logic is standard in Etterna fallback
			local clearType = getClearType(PLAYER_1, steps, pss)
			
			if clearType ~= 1 and clearType ~= 2 and clearType ~= 3 then -- anything better than a standard Clear/SDG/FC
				local ctText = getClearTypeText(clearType)
				local ctColor = getClearTypeColor(clearType)
				
				self:GetChild("CTText"):settext(ctText):diffuse(ctColor)
				
				self:stoptweening()
				self:diffusealpha(0)
				self:zoom(1.5)
				self:decelerate(0.5)
				self:diffusealpha(1)
				self:zoom(1)
				self:sleep(2.5)
				self:smooth(1)
				self:diffusealpha(0)
			end
		end
	end,
	LoadFont("Common Large")..{
		Name = "CTText",
		InitCommand = function(self)
			self:zoom(0.5)
		end
	}
}

return t
