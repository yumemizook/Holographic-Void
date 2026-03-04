local t = Def.ActorFrame {
	Name = "PlayerJudgment",
	InitCommand = function(self)
		self:visible(false)
	end,
	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if not params.TapNoteScore then return end
		
		local tns = ToEnumShortString(params.TapNoteScore)
		local sprite = self:GetChild("JudgmentSprite")
		if not sprite then return end
		
		-- Judgment index: W1=0, W2=1, W3=2, W4=3, W5=4, Miss=5
		local judgments = {W1=0, W2=1, W3=2, W4=3, W5=4, Miss=5}
		local jdgIdx = judgments[tns]
		if not jdgIdx then return end
		
		local numStates = sprite:GetNumStates()
		local state
		if numStates == 12 then
			-- 2x6 sprite: states are read L-R, T-B in a 2-column grid.
			-- Each row = one judgment, col 0 = early, col 1 = late.
			-- State = row * 2 + col
			local offset = params.TapNoteOffset
			local isLate = (offset and offset >= 0) and 1 or 0
			state = jdgIdx * 2 + isLate
		else
			-- Standard 1x6 sprite
			state = jdgIdx
		end

		self:stoptweening():visible(true):zoom(0.65):diffusealpha(1)
		sprite:setstate(state)
		
		self:glow(color("1,1,1,0.5")):linear(0.05):glow(color("1,1,1,0"))
		self:sleep(0.5):linear(0.1):diffusealpha(0)
	end,

	Def.Sprite {
		Name = "JudgmentSprite",
		InitCommand = function(self)
			local path = getAssetPath("judgment")
			if path and path ~= "" then
				self:Load(path)
				if self.pause then self:pause() end
				self:setstate(0)
			end
		end
	}
}

return t

