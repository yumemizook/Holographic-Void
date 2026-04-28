local DOT_COUNT = 20
local dotHistory = {}

-- Create the Recent Judgment display dots statically first
local recentJudgmentDisplay = Def.ActorFrame {
	Name = "RecentJudgmentDisplay",
	InitCommand = function(self)
		if playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay then
			self:xy(MovableValues.RecentJudgmentDisplayX or -160, MovableValues.RecentJudgmentDisplayY or 50):zoom(MovableValues.RecentJudgmentDisplayZoom or 1)
		else
			self:xy(-160, 50):zoom(1)
		end
	end,
	OnCommand = function(self)
		setMovableActor({"DeviceButton_v", "DeviceButton_b"}, self, self:GetChild("Border"))
	end,
	UpdateRowsMessageCommand = function(self)
		self:visible(HV.RecentJudgmentDisplay() and not HV.MinimalisticMode())
	end
}

for i = 1, DOT_COUNT do
	recentJudgmentDisplay[#recentJudgmentDisplay + 1] = Def.Quad {
		Name = "Dot"..i,
		InitCommand = function(self)
			self:zoomto(6, 6):y((i-1) * 8):visible(false)
		end
	}
end

recentJudgmentDisplay[#recentJudgmentDisplay + 1] = MovableBorder(12, ((DOT_COUNT - 1) * 8) + 6, 1, 0, (((DOT_COUNT - 1) * 8) + 6) / 2)

local t = Def.ActorFrame {
	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if not params.TapNoteScore then return end
		if params.HoldNoteScore then return end -- Skip hold/roll end events
		
		local judgment = self:GetChild("PlayerJudgment")
		if not judgment then return end
		local tns = ToEnumShortString(params.TapNoteScore)
		local container = judgment:GetChild("JudgmentContainer")
		local sprite = container:GetChild("JudgmentSprite")
		if not sprite then return end
		
		-- Judgment index: W1=0, W2=1, W3=2, W4=3, W5=4, Miss=5
		local judgments = {W1=0, W2=1, W3=2, W4=3, W5=4, Miss=5}
		local jdgIdx = judgments[tns]
		if not jdgIdx then return end
		
		-- Recent Judgment Display Logic
		if HV.RecentJudgmentDisplay and HV.RecentJudgmentDisplay() and not HV.MinimalisticMode() then
			local dotFrame = self:GetChild("RecentJudgmentDisplay")
			if dotFrame then
				-- Push history
				for i = DOT_COUNT, 2, -1 do
					dotHistory[i] = dotHistory[i-1]
				end
				dotHistory[1] = HVColor.GetJudgmentColor(tns)
				
				-- Update dots
				for i = 1, DOT_COUNT do
					local dot = dotFrame:GetChild("Dot"..i)
					if dot then
						if dotHistory[i] then
							dot:stoptweening()
							dot:diffuse(dotHistory[i])
							-- Fade older dots: instant update
							dot:diffusealpha(math.max(0.1, 1 - (i-1)/DOT_COUNT))
							dot:visible(true)
						else
							dot:visible(false)
						end
					end
				end
			end
		end

		local numStates = sprite:GetNumStates()
		local state
		if numStates == 12 then
			-- 2x6 sprite: states are read L-R, T-B in a 2-column grid.
			local offset = params.TapNoteOffset
			local isLate = (offset and offset >= 0) and 1 or 0
			state = jdgIdx * 2 + isLate
		else
			-- Standard 1x6 sprite
			state = jdgIdx
		end

		local curTime = GetTimeSinceStart()
		local displayDuration = 0.5
		if HV.PrioritizeLowerJudgements and HV.PrioritizeLowerJudgements() then
			if curTime < judgment.lockedUntil and jdgIdx <= judgment.lockedIndex then
				return
			end

			local isLower = false
			if jdgIdx >= 3 then
				isLower = true
			else
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(params.Player or PLAYER_1)
				if pss then
					local w1 = pss:GetTapNoteScores("TapNoteScore_W1")
					local w2 = pss:GetTapNoteScores("TapNoteScore_W2")
					local w3 = pss:GetTapNoteScores("TapNoteScore_W3")
					
					if jdgIdx == 1 then
						if w1 > (w2 * 2.5) then isLower = true end
					elseif jdgIdx == 2 then
						if w2 > (w3 * 5.0) then isLower = true end
					end
				end
			end

			if isLower then
				displayDuration = 0.3
				judgment.lockedUntil = curTime + displayDuration
				judgment.lockedIndex = jdgIdx
			else
				judgment.lockedUntil = 0
				judgment.lockedIndex = -1
			end
		else
			judgment.lockedUntil = 0
			judgment.lockedIndex = -1
		end

		-- Apply state and show the judgment container
		judgment:visible(true)
		container:stoptweening():visible(true):diffusealpha(1)
		sprite:setstate(state)
		
		-- Apply Animation if enabled (only to the judgment container)
		if HV.JudgmentAnimation and HV.JudgmentAnimation() then
			container:zoom(0.81) -- Start slightly larger for the pulse
			container:linear(0.05):zoom(0.65)
			container:glow(color("1,1,1,0.5")):linear(0.05):glow(color("1,1,1,0"))
		else
			container:zoom(0.65)
		end
		
		container:sleep(displayDuration):linear(0.1):diffusealpha(0)
	end,
	Def.ActorFrame {
		Name = "PlayerJudgment",
		InitCommand = function(self)
			if playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay then
				self:xy(MovableValues.JudgeX or 0, MovableValues.JudgeY or 0):zoom(MovableValues.JudgeZoom or 1)
			end
			self:visible(false)
			self.lockedUntil = 0
			self.lockedIndex = -1
		end,
		OnCommand = function(self)
			setMovableActor({"DeviceButton_1", "DeviceButton_2"}, self, self:GetChild("Border"))
		end,

		Def.ActorFrame {
			Name = "JudgmentContainer",
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
		},
		MovableBorder(120, 40, 1, 0, 0)
	},
	recentJudgmentDisplay
}

return t
