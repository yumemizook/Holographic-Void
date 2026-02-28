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
		
		-- W1=0, W2=1, W3=2, W4=3, W5=4, Miss=5
		local states = {W1=0, W2=1, W3=2, W4=3, W5=4, Miss=5}
		local state = states[tns]
		if not state then return end
		
		self:stoptweening():visible(true):zoom(0.8):diffusealpha(1)
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

