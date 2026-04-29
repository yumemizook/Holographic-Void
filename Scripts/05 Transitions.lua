--- Holographic Void: Screen Transitions
-- @module 05_Transitions.lua
-- Provides smooth linear screen transitions used by all screens.

-- Global transition helper: creates a fade-in/fade-out overlay
function HV.ScreenTransitionIn()
	return Def.Quad {
		Name = "TransitionIn",
		InitCommand = function(self)
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
				:diffuse(color("0,0,0,1")):diffusealpha(1)
		end,
		OnCommand = function(self)
			self:linear(0.25):diffusealpha(0)
		end
	}
end

function HV.ScreenTransitionOut()
	return Def.Quad {
		Name = "TransitionOut",
		InitCommand = function(self)
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
				:diffuse(color("0,0,0,1")):diffusealpha(0)
		end,
		OffCommand = function(self)
			self:linear(0.2):diffusealpha(1)
		end
	}
end

-- Circular "Iris" transitions
function HV.CircleTransitionIn()
	return Def.ActorFrame {
		Def.Sprite {
			Texture = THEME:GetPathG("", "_thick circle"),
			InitCommand = function(self)
				-- Ensure circle covers the whole screen at zoom=10
				-- 100px * 10 = 1000px, might need more for 1080p (diagonal ~2200)
				-- Let's use zoom=24 to be safe for 4K too.
				self:Center():diffuse(color("0,0,0,1")):zoom(24)
			end,
			OnCommand = function(self)
				self:decelerate(0.25):zoom(0)
			end
		}
	}
end

function HV.CircleTransitionOut()
	return Def.ActorFrame {
		Def.Sprite {
			Texture = THEME:GetPathG("", "_thick circle"),
			InitCommand = function(self)
				self:Center():diffuse(color("0,0,0,1")):zoom(0)
			end,
			OffCommand = function(self)
				self:accelerate(0.25):zoom(24)
			end
		}
	}
end

-- Accent line slide transition (horizontal wipe)
function HV.AccentWipeIn()
	return Def.Quad {
		Name = "AccentWipe",
		InitCommand = function(self)
			self:Center():zoomto(SCREEN_WIDTH + 4, 3)
				:diffuse(HVColor.Accent):diffusealpha(0.6)
		end,
		OnCommand = function(self)
			self:x(SCREEN_LEFT - SCREEN_WIDTH)
			self:linear(0.3):x(SCREEN_CENTER_X)
			self:sleep(0.05)
			self:linear(0.25):diffusealpha(0)
		end
	}
end

-- Slide-in from right (for panels)
function HV.SlideInRight(actor, targetX, duration)
	duration = duration or 0.3
	return function(self)
		self:x(SCREEN_RIGHT + 100)
		self:linear(duration):x(targetX)
	end
end

-- Fade-up animation (for text elements)
function HV.FadeUp(delay, duration)
	delay = delay or 0
	duration = duration or 0.3
	return function(self)
		self:diffusealpha(0):y(self:GetY() + 8)
		self:sleep(delay)
		self:linear(duration):diffusealpha(1):y(self:GetY() - 8)
	end
end

-- Subtle pulse on beat (for accent elements)
function HV.PulseGlow()
	return function(self)
		self:diffusealpha(0.8)
		self:linear(0.4):diffusealpha(0.4)
		self:linear(0.4):diffusealpha(0.8)
		self:queuecommand("Pulse")
	end
end

Trace("Holographic Void: 05 Transitions.lua loaded.")
