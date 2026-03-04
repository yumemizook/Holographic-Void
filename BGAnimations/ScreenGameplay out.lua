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

-- Clear-type specific celebratory effects
local function CelebrationBurst(color)
	local burst = Def.ActorFrame{}
	for i=1, 8 do
		burst[#burst+1] = Def.Quad{
			InitCommand = function(self)
				self:zoomto(2, 200):diffuse(color):diffusealpha(0):rotationz(i * 45)
			end,
			CelebrationCommand = function(self)
				self:stoptweening():diffusealpha(0):zoomto(2, 0)
				self:sleep(0.1):linear(0.4):zoomto(4, 400):diffusealpha(0.6):rotationz(i*45 + 90)
				self:linear(0.4):zoomto(0, 0):diffusealpha(0)
			end
		}
	end
	return burst
end

t[#t+1] = Def.ActorFrame{
	Name = "CelebrationContainer",
	InitCommand = function(self)
		self:Center()
	end,
	
	CelebrationBurst(color("#FFFFFF")),
	CelebrationBurst(HVColor.Accent or color("#00FF00")),

	Def.ActorFrame{
		Name = "FCTextFrame",
		InitCommand = function(self)
			self:diffusealpha(0):y(50)
		end,
		OffCommand = function(self)
			local pn = GAMESTATE:GetEnabledPlayers()[1]
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(pn)
			if pss then
				local steps = GAMESTATE:GetCurrentSteps()
				local clearLevel = getClearLevel(pn, steps, pss)
				
				-- MFC=1, WF=2, SDP=3, PFC=4, BF=5, SDG=6, FC=7
				-- Celebration for anything better than regular 'Clear' (12)
				if clearLevel <= 7 then
					local ctName = getClearType(pn, steps, pss)
					local ctText = getClearTypeText(ctName)
					local ctColor = getClearTypeColor(ctName)
					
					local txt = self:GetChild("CTText")
					txt:settext(ctText):diffuse(ctColor)

					-- Trigger burst for exceptional tiers
					if clearLevel <= 4 then
						self:GetParent():playcommand("Celebration")
					end
					
					self:stoptweening()
					self:diffusealpha(0):zoom(2)
					self:decelerate(0.4):diffusealpha(1):zoom(1)
					
					-- Optional: Flash the screen
					SCREENMAN:GetTopScreen():GetChild("Overlay"):GetChild("ComboDisplay"):playcommand("Flash")
					
					self:sleep(3)
					self:smooth(1):diffusealpha(0):zoom(0.8)
				end
			end
		end,
		LoadFont("Common Large")..{
			Name = "CTText",
			InitCommand = function(self)
				self:zoom(0.7):strokecolor(color("0,0,0,0.5"))
			end
		}
	}
}

return t
