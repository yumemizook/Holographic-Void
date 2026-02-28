local t = Def.ActorFrame {
	Name = "ScoresOverlay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		if params.Tab == "SCORES" then
			self:visible(not self:GetVisible())
		else
			self:visible(false)
		end
	end,
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(400, 300):diffuse(color("0.1,0.1,0.1,0.95"))
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.5):diffuse(color("1,1,1,1")):settext("Scores Overlay Placeholder")
		end
	}
}
return t
