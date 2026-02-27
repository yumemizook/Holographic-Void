--- Holographic Void: ScreenGameplay Toasty
-- Loads the toasty assets (image + sound) from the Assets folder.
-- The engine triggers StartTransitioning when the toasty fires.

-- Try to use custom toasty from Assets folder
if FILEMAN:DoesFileExist(getAssetPath("toasty").."/default.lua") then
	local t = Def.ActorFrame {}
	t[#t+1] = LoadActor("../../../../" .. getAssetPath("toasty") .. "/default")
	return t
end

local t =
	Def.ActorFrame {
	Def.Sprite {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH + 100, SCREEN_CENTER_Y)
			self:Load(getToastyAssetPath("image"))
		end,
		StartTransitioningCommand = function(self)
			self:stoptweening():diffusealpha(1):decelerate(0.25):x(SCREEN_WIDTH - 100):sleep(1.75):accelerate(0.5):x(SCREEN_WIDTH + 100):linear(0):diffusealpha(0)
		end
	},
	Def.Sound {
		InitCommand = function(self)
			self:load(getToastyAssetPath("sound"))
		end,
		StartTransitioningCommand = function(self)
			self:play()
		end
	}
}

return t
