--- Holographic Void: ScreenTitleMenu scroll element
-- Each scroller item uses this actor. GainFocus/LoseFocus control
-- selected vs unselected appearance while keeping ALL items visible.
-- NOTE: GainFocusCommand fires BEFORE OnCommand, so visual state
-- (zoom, diffuse) must only be set in GainFocus/LoseFocus, not OnCommand.

local gc = Var("GameCommand")

return Def.ActorFrame {
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.6):diffuse(color("0.5,0.5,0.5,1")):uppercase(true):maxwidth(280 / 0.6):diffusealpha(0)
			self:playcommand("Refresh")
		end,
		RefreshCommand = function(self)
			self:settext((gc and gc.GetText and gc:GetText()) or "")
		end,
		GainFocusCommand = function(self)
			self:stoptweening():decelerate(0.15)
			self:zoom(0.7):diffuse(color("1,1,1,1")):maxwidth(280 / 0.7):diffusealpha(0)
			self:playcommand("Refresh")
		end,
		LoseFocusCommand = function(self)
			self:stoptweening():decelerate(0.15)
			self:zoom(0.6):diffuse(color("0.5,0.5,0.5,1")):maxwidth(280 / 0.6):diffusealpha(0)
			self:playcommand("Refresh")
		end
	}
}
