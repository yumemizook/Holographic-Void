--- Holographic Void: Player judgment
-- Proper judgment sprite rendering.
-- Loads the custom judgment sprite from Assets/Judgments and displays
-- the appropriate frame for each TapNoteScore via JudgmentMessage.

local judgPath = "/Assets/Judgments/default 1x6 (Doubleres).png"
local fallbackPath = "/Themes/_fallback/Graphics/Judgment Normal 1x6.png"

local t = Def.ActorFrame {}

t[#t + 1] = Def.Sprite {
	Name = "JudgmentSprite",
	InitCommand = function(self)
		-- Load judgment spritesheet
		if FILEMAN:DoesFileExist(judgPath) then
			self:Load(judgPath)
		elseif FILEMAN:DoesFileExist(fallbackPath) then
			self:Load(fallbackPath)
		end
		self:SetAllStateDelays(9999)
		self:animate(false)
		self:pause()
		self:visible(false)
		self:zoom(0.5)
	end,
	JudgmentMessageCommand = function(self, params)
		if params and params.TapNoteScore then
			local tns = params.TapNoteScore
			local stateMap = {
				["TapNoteScore_W1"] = 0,
				["TapNoteScore_W2"] = 1,
				["TapNoteScore_W3"] = 2,
				["TapNoteScore_W4"] = 3,
				["TapNoteScore_W5"] = 4,
				["TapNoteScore_Miss"] = 5
			}
			local frame = stateMap[tns]
			if frame then
				self:visible(true)
				self:setstate(frame)
				self:stoptweening()
				self:diffusealpha(1):zoom(0.55)
				self:decelerate(0.05):zoom(0.5)
				self:sleep(0.6):linear(0.2):diffusealpha(0)
			end
		end
	end
}

return t
