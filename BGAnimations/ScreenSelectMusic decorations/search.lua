local t = Def.ActorFrame {
	Name = "SearchOverlay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	ToggleSearchOverlayMessageCommand = function(self)
		self:visible(not self:GetVisible())
	end,
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(400, 300):diffuse(color("0.1,0.1,0.1,0.95"))
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.5):diffuse(color("1,1,1,1")):settext("Search Overlay Placeholder. Press Enter to search.")
		end
	}
}
return t
