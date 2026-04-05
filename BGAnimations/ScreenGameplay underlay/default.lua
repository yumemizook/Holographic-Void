--- Holographic Void: ScreenGameplay Underlay (Lane Filter)
-- Localized dimming for the notefield area.

local t = Def.ActorFrame {}

-- Standard 4K column width (64px each * 4 columns = 256px)
local filterW = 256

t[#t + 1] = Def.Quad {
	Name = "LaneFilter",
	InitCommand = function(self)
		local filterVal = HV.GetScreenFilter()
		self:Center():zoomto(filterW, SCREEN_HEIGHT)
			:diffuse(color("0,0,0,1")):diffusealpha(filterVal)
	end,
	OnCommand = function(self)
		-- Ensure it stays visible if changed (though normally it's static during gameplay)
	end
}

return t
