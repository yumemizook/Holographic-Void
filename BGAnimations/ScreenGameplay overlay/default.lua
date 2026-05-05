local pn = GAMESTATE:GetEnabledPlayers()[1] or PLAYER_1
local lScreen = Var "LoadingScreen" or ""
local isSync = lScreen:find("Sync") ~= nil
local HV_PointsLost = 0
local HV_MaxPoints = 0
local HV_TotalMaxPoints = 1
local HV_PBThreshold = 0
local HV_JudgeScale = 1.0

-- Helper: get coords/sizes for current keymode (call inside command functions only)
local function getCoords()
	local keymode = tostring(GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()) .. "K"
	local coords = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).GameplayXYCoordinates[keymode]
	local sizes  = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).GameplaySizes[keymode]
	return coords, sizes
end

local t = Def.ActorFrame {
	Name = "GameplayOverlay",
	BeginCommand = function(self)
		-- Re-check sync mode via SCREENMAN now that it's safer
		local curScreen = SCREENMAN:GetTopScreen()
		if curScreen and curScreen:GetName():find("Sync") then
			isSync = true
		end

		HV.LastGameplayTime = os.time()
		HV.GameplaySessionValid = true

		-- Initialize total chart points for subtractive mode
		HV_TotalMaxPoints = (getMaxNotes(PLAYER_1) or 1) * 2
		HV_MaxPoints = 0
		HV_PointsLost = 0
		HV_JudgeScale = PREFSMAN:GetPreference("TimingWindowScale") or 1.0

		-- Initialize Auto-Fail Personal Best threshold if needed
		local condition = ThemePrefs.Get("HV_AutoFailCondition")
		if condition == "Personal Best" then
			local best = GetDisplayScore()
			if best then
				HV_PBThreshold = getJ4NormalizedPercentage(best)
			else
				-- Fallback to Wife Percent threshold if no PB exists
				HV_PBThreshold = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Wife")) or 93.00
			end
		end

		-- Wire up MovableValues keymode
		local km = tostring(GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()) .. "K"
		setMovableKeymode(km)
	end,
	OnCommand = function(self)
		-- Apply Mini mod (Receptor Size)
		local miniValue = tonumber(ThemePrefs.Get("HV_Mini")) or 100
		local miniPct = 100 - miniValue
		local modStr = miniPct .. "% mini"

		-- Apply Measure Lines (Beat Bars) mod
		local beatBarMod = HV.ShowMeasureLines() and "beatbars" or "nobeatbars"

		-- Apply mods to all enabled players
		for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
			local ps = GAMESTATE:GetPlayerState(pn)
			local po = ps:GetPlayerOptions("ModsLevel_Preferred")
			po:FromString(modStr)
			po:FromString(beatBarMod)
			-- Also apply to Current so it takes effect immediately on first load
			local co = ps:GetPlayerOptions("ModsLevel_Current")
			co:FromString(modStr)
			co:FromString(beatBarMod)

			-- Sync Mode overrides
			if isSync then
				po:CMod(400)
				po:Reverse(0)
				local co2 = ps:GetPlayerOptions("ModsLevel_Current")
				co2:CMod(400)
				co2:Reverse(0)
			end
		end

		-- Double check sync mods on OnCommand just in case
		if isSync then
			for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
				local ps = GAMESTATE:GetPlayerState(pn)
				ps:GetPlayerOptions("ModsLevel_Current"):CMod(400)
				ps:GetPlayerOptions("ModsLevel_Current"):Reverse(0)
			end
		end

		-- Input Callback for Ghost Tapping feedback
		local screen = SCREENMAN:GetTopScreen()
		if screen then
			screen:AddInputCallback(function(event)
				if event.type == "InputEventType_Release" then return end
				if event.type == "InputEventType_FirstPress" then
					local b = event.button
					if b == "Left" or b == "Down" or b == "Up" or b == "Right" or
					   b == "Key 1" or b == "Key 2" or b == "Key 3" or b == "Key 4" or
					   b == "Key 5" or b == "Key 6" or b == "Key 7" then
						MESSAGEMAN:Broadcast("GhostTap")
					end
				end
			end)
		end
	end,
	
	CurrentSongChangedMessageCommand = function(self)
		-- Re-apply sync mods on every loop start to prevent engine resets
		if isSync then
			for _, pn_loop in ipairs(GAMESTATE:GetEnabledPlayers()) do
				local ps = GAMESTATE:GetPlayerState(pn_loop)
				local po = ps:GetPlayerOptions("ModsLevel_Preferred")
				po:CMod(400)
				po:Reverse(0)
				local co = ps:GetPlayerOptions("ModsLevel_Current")
				co:CMod(400)
				co:Reverse(0)
			end
		end
	end,
	
	-- Shared PointsLost Accumulator (Wife3 Adherent)
	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		local s = params.TapNoteScore
		if params.HoldNoteScore or not s or s == "TapNoteScore_None" or s == "TapNoteScore_AvoidMine" or
		   s == "TapNoteScore_CheckpointHit" or s == "TapNoteScore_CheckpointMiss" then
			return
		end

		HV_MaxPoints = HV_MaxPoints + 2  -- increment as notes are scored

		if s == "TapNoteScore_HitMine" then
			HV_PointsLost = HV_PointsLost + 7.0
		elseif params.TapNoteOffset then
			local offset = math.abs(params.TapNoteOffset) * 1000
			local weight = wife3(offset, HV_JudgeScale, "Wife3")
			HV_PointsLost = HV_PointsLost + (2.0 - weight)
		elseif s == "TapNoteScore_Miss" then
			HV_PointsLost = HV_PointsLost + 7.5
		end

		MESSAGEMAN:Broadcast("HV_PointsUpdate")
	end,

	HoldNoteScoreMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if params.HoldNoteScore == "HoldNoteScore_LetGo" or params.HoldNoteScore == "HoldNoteScore_MissedHold" then
			HV_PointsLost = HV_PointsLost + 4.5
			MESSAGEMAN:Broadcast("HV_PointsUpdate")
		end
	end,
	
	RollNoteScoreMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if params.RollNoteScore == "RollNoteScore_LetGo" or params.RollNoteScore == "RollNoteScore_MissedRoll" then
			HV_PointsLost = HV_PointsLost + 4.5
			MESSAGEMAN:Broadcast("HV_PointsUpdate")
		end
	end
}

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")

local judgmentColors = {
	HVColor.GetJudgmentColor("W1"),
	HVColor.GetJudgmentColor("W2"),
	HVColor.GetJudgmentColor("W3"),
	HVColor.GetJudgmentColor("W4"),
	HVColor.GetJudgmentColor("W5"),
	HVColor.GetJudgmentColor("Miss")
}
local judgmentLabels = {
	THEME:GetString("TapNoteScore", "W1"),
	THEME:GetString("TapNoteScore", "W2"),
	THEME:GetString("TapNoteScore", "W3"),
	THEME:GetString("TapNoteScore", "W4"),
	THEME:GetString("TapNoteScore", "W5"),
	THEME:GetString("TapNoteScore", "Miss")
}

local judgmentTNS = {
	"TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3",
	"TapNoteScore_W4", "TapNoteScore_W5", "TapNoteScore_Miss"
}

-- ============================================================
-- FRAME UPDATER (for time-based elements: life bar, progress bar)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		self:SetUpdateFunction(function(self)
			MESSAGEMAN:Broadcast("PlayingUpdate")
		end)
	end,

	-- NoteMask for Sync Mode
	Def.Quad {
		Name = "SyncNoteMask",
		InitCommand = function(self)
			self:Center():zoomto(SCREEN_WIDTH * 0.4, SCREEN_HEIGHT)
				:diffuse(color("0,0,0,1")):diffusealpha(0)
				:visible(isSync)
		end,
		SyncTriggeredMessageCommand = function(self)
			self:linear(2):diffusealpha(1)
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:stoptweening():diffusealpha(0)
		end
	}
}

-- ============================================================
-- SONG PROGRESS BAR (TOP of screen)
-- ============================================================
local progressBarPosition = HV.GetProgressBarPosition()
local barW = SCREEN_WIDTH * 0.4
local barH = 6
local barY = progressBarPosition == "Top" and 12 or (progressBarPosition == "Bottom" and SCREEN_BOTTOM - 12 or 12)

local showProgressBar = progressBarPosition ~= "Off" and not HV.MinimalisticMode() and not isSync

t[#t + 1] = LoadActor("practice_input.lua")

if showProgressBar then
t[#t + 1] = Def.ActorFrame {
	Name = "ProgressBarContainer",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, barY)
	end,
	BeginCommand = function(self)
		self:SetUpdateFunction(function(self)
			self:playcommand("UpdateBars")
		end)
	end,
	Def.Quad {
		Name = "MouseHitbox",
		InitCommand = function(self)
			self:zoomto(barW + 20, barH + 20):diffusealpha(0)
		end,
		UpdateBarsCommand = function(self)
			if not GAMESTATE:IsPracticeMode() then return end
			if INPUTFILTER:IsBeingPressed("left mouse button") and isOver(self) then
				local song = GAMESTATE:GetCurrentSong()
				if song then
					local mx = INPUTFILTER:GetMouseX()
					local rx = mx - self:GetTrueX()
					local pct = (rx / barW) + 0.5
					local top = SCREENMAN:GetTopScreen()
					if top and top.SetSongPosition then
						top:SetSongPosition(math.max(0, math.min(song:MusicLengthSeconds(), song:MusicLengthSeconds() * pct)))
					end
				end
			end
		end
	},

	Def.Quad {
		Name = "ProgressBarBG",
		InitCommand = function(self)
			self:zoomto(barW, barH):diffuse(color("0,0,0,0.2"))
		end
	},

	Def.Quad {
		Name = "ProgressFill",
		InitCommand = function(self)
			self:halign(0):x(-barW / 2)
				:zoomto(0, barH):diffuse(accentColor):diffusealpha(0.7)
		end,
		UpdateBarsCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local len = song:MusicLengthSeconds()
				if len > 0 then
					local cur = GAMESTATE:GetSongPosition():GetMusicSeconds()
					local pct = math.max(0, math.min(cur / len, 1))
					self:zoomto(barW * pct, barH)
				end
			end
		end
	},

	Def.ActorFrame {
		Name = "LoopMarkers",
		InitCommand = function(self) self:visible(GAMESTATE:IsPracticeMode()) end,
		PracticeLoopChangedMessageCommand = function(self) self:queuecommand("Update") end,
		
		Def.Quad {
			Name = "StartMarker",
			InitCommand = function(self) self:zoomto(2, barH + 6):diffuse(color("#00FF00")):visible(false) end,
			UpdateCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if song and HV.PracticeLoopStart > 0 then
					local pct = HV.PracticeLoopStart / song:MusicLengthSeconds()
					self:visible(true):x(-barW/2 + (barW * pct))
				else
					self:visible(false)
				end
			end
		},
		Def.Quad {
			Name = "EndMarker",
			InitCommand = function(self) self:zoomto(2, barH + 6):diffuse(color("#FF0000")):visible(false) end,
			UpdateCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if song and HV.PracticeLoopEnd > 0 then
					local pct = HV.PracticeLoopEnd / song:MusicLengthSeconds()
					self:visible(true):x(-barW/2 + (barW * pct))
				else
					self:visible(false)
				end
			end
		}
	},

	LoadFont("Common Normal") .. {
		Name = "TimeRemaining",
		InitCommand = function(self)
			self:x(barW / 2 + 8):zoom(0.35):halign(0):diffuse(dimText)
		end,
		UpdateBarsCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local songLen = song:MusicLengthSeconds()
				local curTime = GAMESTATE:GetSongPosition():GetMusicSeconds()
				local remaining = math.max(0, songLen - curTime) / getCurRateValue()
				local mins = math.floor(remaining / 60)
				local secs = math.floor(remaining % 60)
				local ms = math.floor((remaining - math.floor(remaining)) * 100)
				self:settext(string.format("-%d:%02d.%02d", mins, secs, ms))
			end
		end
	},

	LoadFont("Common Normal") .. {
		Name = "TimeElapsed",
		InitCommand = function(self)
			self:x(-barW / 2 - 8):zoom(0.35):halign(1):diffuse(subText)
		end,
		UpdateBarsCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local curTime = math.max(0, GAMESTATE:GetSongPosition():GetMusicSeconds()) / getCurRateValue()
				local mins = math.floor(curTime / 60)
				local secs = math.floor(curTime % 60)
				local ms = math.floor((curTime - math.floor(curTime)) * 100)
				self:settext(string.format("%d:%02d.%02d", mins, secs, ms))
			end
		end
	}
}
end -- End progress bar visibility check

-- ============================================================
-- VERTICAL LIFE BAR (right edge) with % counter
-- ============================================================
local lifeBarW = 8
local lifeBarH = SCREEN_HEIGHT * 0.5

if not HV.MinimalisticMode() and not isSync then
t[#t + 1] = Def.ActorFrame {
	Name = "VerticalLifeBar",
	InitCommand = function(self)
		local coords, sizes = getCoords()
		self:xy(coords.LifeP1X, coords.LifeP1Y):visible(false)
	end,

	Def.Quad {
		InitCommand = function(self)
			self:zoomto(lifeBarW, lifeBarH):diffuse(color("0.1,0.1,0.1,0.8"))
		end
	},

	Def.Quad {
		Name = "LifeFill",
		InitCommand = function(self)
			self:valign(1):y(lifeBarH / 2)
				:zoomto(lifeBarW, 0)
				:diffuse(accentColor):diffusealpha(0.8)
		end,
		JudgmentMessageCommand = function(self)
			self:queuecommand("RefreshLife")
		end,
		PlayingUpdateMessageCommand = function(self)
			self:playcommand("RefreshLife")
		end,
		RefreshLifeCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			local lifeVal = 0
			if screen and screen:GetLifeMeter(pn) then
				lifeVal = screen:GetLifeMeter(pn):GetLife()
			else
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				lifeVal = pss:GetCurrentLife() or 0
			end
			
			if lifeVal then
				local fillH = lifeBarH * lifeVal
				self:zoomto(lifeBarW, fillH)

				local diff = GetLifeDifficulty()
				if diff <= 2 then
					self:diffuse(color("#A0CFAB"))
				elseif diff <= 4 then
					self:diffuse(color("#5ABAFF"))
				elseif diff == 5 then
					self:diffuse(color("#CFD198"))
				elseif diff == 6 then
					self:diffuse(color("#E0B080"))
				else
					self:diffuse(color("#CF9898"))
				end
				self:diffusealpha(0.8)
			end
		end
	},

	Def.Quad {
		InitCommand = function(self)
			self:zoomto(lifeBarW + 2, lifeBarH + 2)
				:diffuse(color("0.2,0.2,0.2,0.3"))
		end
	},

	LoadFont("Common Normal") .. {
		Name = "LifePct",
		InitCommand = function(self)
			self:xy(-lifeBarW - 4, -lifeBarH / 2 - 10):zoom(0.25):halign(1):diffuse(subText)
		end,
		BeginCommand = function(self)
			self:playcommand("RefreshLifePct")
		end,
		JudgmentMessageCommand = function(self)
			self:queuecommand("RefreshLifePct")
		end,
		PlayingUpdateMessageCommand = function(self)
			self:playcommand("RefreshLifePct")
		end,
		RefreshLifePctCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			local lifeVal = 0
			if screen and screen:GetLifeMeter(pn) then
				lifeVal = screen:GetLifeMeter(pn):GetLife()
			else
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				lifeVal = pss:GetCurrentLife() or 0
			end
			if lifeVal then
				self:settext(string.format("%.1f%%", lifeVal * 100))
			end
		end
	}
}
end -- End Vertical Life Bar

-- ============================================================
-- SCORE % (REAL-TIME)
-- ============================================================
local showCurrentWife = HV.ShowCurrentWife() and not HV.MinimalisticMode() and not isSync

if showCurrentWife then
t[#t + 1] = Def.ActorFrame {
	Name = "CenteredScore",
	InitCommand = function(self)
		local coords, sizes = getCoords()
		self:xy(coords.DisplayPercentX - 45, coords.DisplayPercentY):diffusealpha(0.8)
	end,

	LoadFont("Common Normal") .. {
		Name = "ScoreValue",
		InitCommand = function(self)
			local coords, sizes = getCoords()
			self:zoom(0.45 * (sizes.DisplayPercentZoom or 1)):diffuse(brightText):diffusealpha(0.7)
			local scoreMode = ThemePrefs.Get("HV_ScoreDisplayMode") or "Normal"
			if scoreMode == "Subtractive" then
				self:settext("100.0000%")
			else
				self:settext("0.0000%")
			end
		end,
		HV_PointsUpdateMessageCommand = function(self)
			self:playcommand("Update")
		end,
		UpdateCommand = function(self)
			local scoreMode = ThemePrefs.Get("HV_ScoreDisplayMode") or "Normal"
			local wifePct
			if scoreMode == "Subtractive" then
				if HV_TotalMaxPoints <= 0 then return end
				wifePct = ((HV_TotalMaxPoints - HV_PointsLost) / HV_TotalMaxPoints) * 100
			else
				if HV_MaxPoints <= 0 then return end
				wifePct = ((HV_MaxPoints - HV_PointsLost) / HV_MaxPoints) * 100
			end
			if not wifePct then return end
			self:settext(string.format("%.4f%%", wifePct))
			local tier = getEtternityGrade(wifePct)
			self:diffuse(HVColor.GetGradeColor(tier)):diffusealpha(0.7)
		end
	}
}
end

-- ============================================================
-- GOAL TRACKER
-- ============================================================
local showGoalTrackerText = HV.ShowGoalTrackerText() and not HV.MinimalisticMode() and not isSync
if showGoalTrackerText then
	local pacemakerMode = ThemePrefs.Get("HV_PacemakerTargetType")
	if not pacemakerMode or pacemakerMode == "" then pacemakerMode = "Target" end

	local targetGoalPref = ThemePrefs.Get("HV_PacemakerTargetGoal")
	local targetGoalPct = tonumber(targetGoalPref) or 93
	local targetGoal = targetGoalPct / 100

	GAMESTATE:GetPlayerState():SetTargetGoal(targetGoal)
	GAMESTATE:GetPlayerState():SetGoalTrackerUsesReplay(pacemakerMode == "PBReplay")

	t[#t + 1] = Def.ActorFrame {
		Name = "TextPacemaker",
		InitCommand = function(self)
			local coords, sizes = getCoords()
			self:xy(coords.TargetTrackerX, coords.TargetTrackerY -  85)
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0.5):zoom(0.35)
				self:settextf("%+5.2f (%5.2f%%)", 0, targetGoalPct)
				self:diffuse(color("#00ff00"))
			end,
			JudgmentMessageCommand = function(self, msg)
				self.msg = msg
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local msg = self.msg
				if not msg then return end
				local tDiff = msg.WifeDifferential
				local displayTarget = targetGoalPct

				if (pacemakerMode == "PB" or pacemakerMode == "PBReplay") and msg.WifePBGoal ~= nil then
					tDiff = msg.WifePBDifferential
					displayTarget = msg.WifePBGoal * 100
				end

				if tDiff and tDiff >= 0 then
					self:diffuse(color("#91ff91ff"))
				else
					self:diffuse(HVColor.Negative or color("#ff0000"))
				end
				self:settextf("%+5.2f (%5.2f%%)", tDiff or 0, displayTarget)
			end
		}
	}
end

-- ============================================================
-- NOTEFIELD MEAN DISPLAY
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "NotefieldMean",
	InitCommand = function(self)
		local coords, sizes = getCoords()
		self:xy(coords.DisplayMeanX - 45, coords.DisplayMeanY):diffusealpha(0)
		local statType = HV.GetNotefieldStat()
		local showStat = statType ~= "Off" and not HV.MinimalisticMode() and not isSync
		self:visible(showStat)
	end,
	OnCommand = function(self)
		self:linear(0.2):diffusealpha(0.8)
	end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			local coords, sizes = getCoords()
			self:zoom(0.35 * (sizes.DisplayMeanZoom or 1)):diffuse(mainText)
			local statType = HV.GetNotefieldStat()
			self.statType = statType
			self.currWifePoints = 0
			if statType == "J4" then
				self:settext("100.0000%")
			else
				self:settext("0.00ms")
			end
		end,
		JudgmentMessageCommand = function(self, msg)
			if self.statType == "J4" then
				if msg.TapNoteScore and msg.TapNoteScore ~= "TapNoteScore_AvoidMine" and msg.TapNoteScore ~= "TapNoteScore_CheckpointHit" then
					local ts = ms.JudgeScalers[4] or 1.0
					if msg.TapNoteOffset then
						self.currWifePoints = self.currWifePoints + wife3(math.abs(msg.TapNoteOffset) * 1000, ts, "Wife3")
					elseif msg.TapNoteScore == "TapNoteScore_Miss" then
						self.currWifePoints = self.currWifePoints - 5.5
					elseif msg.TapNoteScore == "TapNoteScore_HitMine" then
						self.currWifePoints = self.currWifePoints - 7.0
					end
				elseif msg.HoldNoteScore == "HoldNoteScore_LetGo" then
					self.currWifePoints = self.currWifePoints - 4.5
				end
			end
			self:queuecommand("Update")
		end,
		UpdateCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if not pss then return end

			if self.statType == "J4" then
				local notesPassed = pss:GetTapNoteScores("TapNoteScore_W1") +
								   pss:GetTapNoteScores("TapNoteScore_W2") +
								   pss:GetTapNoteScores("TapNoteScore_W3") +
								   pss:GetTapNoteScores("TapNoteScore_W4") +
								   pss:GetTapNoteScores("TapNoteScore_W5") +
								   pss:GetTapNoteScores("TapNoteScore_Miss")
				local maxPoints = notesPassed * 2
				if maxPoints > 0 then
					local j4 = math.min((self.currWifePoints / maxPoints) * 100, 100)
					self:settextf("%.4f%%", j4)
				else
					self:settext("100.0000%")
				end
			elseif self.statType == "StdDev" then
				local dvt = pss:GetOffsetVector()
				if dvt and #dvt > 0 then
					self:settextf("%.2fms", wifeSd(dvt))
				end
			else
				local dvt = pss:GetOffsetVector()
				if dvt and #dvt > 0 then
					self:settextf("%.2fms", wifeMean(dvt))
				end
			end
		end,
		PracticeModeResetMessageCommand = function(self) self.currWifePoints = 0; self:queuecommand("Update") end,
		PracticeModeReloadMessageCommand = function(self) self.currWifePoints = 0; self:queuecommand("Update") end
	}
}


-- ============================================================
-- CENTERED COMBO / MISS COMBO
-- ============================================================
local showCombo = HV.ShowCombo() and not HV.MinimalisticMode()

if showCombo then
t[#t + 1] = Def.ActorFrame {
	Name = "ComboDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 93)
		self.comboBreaks = 0
	end,

	LoadFont("_theFont 24px") .. {
		Name = "ComboNumber",
		InitCommand = function(self)
			self:zoom(0.75):diffuse(brightText):y(-4)
			self:settext("0"):shadowlength(1.5):shadowcolor(color("0,0,0,1"))
		end
	},

	Def.ActorFrame {
		Name = "ComboLabel",
		InitCommand = function(self)
			self:y(16)
		end,

		Def.Sprite {
			Name = "ComboGraphic",
			Texture = THEME:GetPathG("", "combo_label.png"),
			InitCommand = function(self)
				self:zoom(0.25):diffuse(subText):visible(true)
			end
		},

		LoadFont("Common Normal") .. {
			Name = "MissesText",
			InitCommand = function(self)
				self:zoom(0.22):diffuse(color("#FF5050")):visible(false)
				self:settext(THEME:GetString("ScreenGameplay", "Misses"))
			end
		}
	},

	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if not pss then return end

		if not params.HoldNoteScore and params.TapNoteScore then
			local tns = params.TapNoteScore
			if tns == "TapNoteScore_Miss" or tns == "TapNoteScore_W5" or tns == "TapNoteScore_W4" then
				self.comboBreaks = self.comboBreaks + 1
			elseif tns == "TapNoteScore_W1" or tns == "TapNoteScore_W2" or tns == "TapNoteScore_W3" then
				self.comboBreaks = 0
			end
		end

		if HV.ComboAnimation and HV.ComboAnimation() then
			if not params.HoldNoteScore then
				local tns = params.TapNoteScore
				if tns and tns ~= "TapNoteScore_None" and tns ~= "TapNoteScore_Miss" and tns ~= "TapNoteScore_HitMine" and tns ~= "TapNoteScore_AvoidMine" and tns ~= "TapNoteScore_CheckpointHit" and tns ~= "TapNoteScore_CheckpointMiss" then
					if pss:GetCurrentCombo() > 0 then
						self.lastHitTime = GetTimeSinceStart()
						self:stoptweening():zoom(1.3):linear(0.05):zoom(1.0)
					end
				end
			end
		end
		
		if pss:GetCurrentCombo() == 0 then
			local numActor = self:GetChild("ComboNumber")
			local labelContainer = self:GetChild("ComboLabel")
			local graphic = labelContainer:GetChild("ComboGraphic")
			local text = labelContainer:GetChild("MissesText")
			
			if self.comboBreaks >= 5 then
				numActor:settext(tostring(self.comboBreaks)):diffuse(color("#FF5050")):shadowlength(0)
				graphic:visible(false)
				text:visible(true):settext(THEME:GetString("ScreenGameplay", "Misses"))
			else
				numActor:settext("0"):diffuse(dimText):shadowlength(0)
				graphic:visible(true):diffusealpha(0.5)
				text:visible(false)
			end
		end
	end,

	ComboChangedMessageCommand = function(self, params)
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if not pss then return end

		local combo = pss:GetCurrentCombo()
		local numActor = self:GetChild("ComboNumber")
		local labelContainer = self:GetChild("ComboLabel")
		local graphic = labelContainer:GetChild("ComboGraphic")
		local text = labelContainer:GetChild("MissesText")

		if combo > 0 then
			local totalNotes = getMaxNotes(PLAYER_1) or 1
			local threshold = math.floor(totalNotes * 0.25)
			local ct = getDetailedClearType(pss)
			local ctColor = getClearTypeColor(ct)
			
			numActor:settext(tostring(combo)):diffuse(brightText)
			
			local isFC = (ct ~= "MF" and ct ~= "SDCB" and ct ~= "Clear" and ct ~= "Failed")
			
			if combo >= threshold and isFC then
				numActor:shadowcolor(ctColor)
				numActor:shadowlength(1.5)
			else
				numActor:shadowlength(0)
			end
			
			graphic:visible(true):diffusealpha(1)
			text:visible(false)
		elseif self.comboBreaks < 5 then
			numActor:settext("0"):diffuse(dimText):shadowlength(0)
			graphic:visible(true):diffusealpha(0.5)
			text:visible(false)
		end
	end,

	GhostTapMessageCommand = function(self)
		if HV.ComboAnimation and HV.ComboAnimation() then
			if self.lastHitTime and GetTimeSinceStart() - self.lastHitTime < 0.05 then return end
			self:stoptweening():zoom(1.08):linear(0.05):zoom(1.0)
		end
	end,

}
end -- End combo visibility check

-- ============================================================
-- COMBO BREAK LANE HIGHLIGHT
-- ============================================================
local showComboBreakHighlight = HV.ComboBreakHighlight() and not HV.MinimalisticMode() and not isSync

if showComboBreakHighlight then

local function makeCBLane(name, xOffset, laneW)
	local halfW   = laneW / 2
	local topY    = -SCREEN_HEIGHT * 0.3
	local bottomY = SCREEN_HEIGHT / 2

	return Def.ActorMultiVertex {
		Name = name,
		InitCommand = function(self)
			self:x(xOffset)
			self:SetVertices({
				{{-halfW, topY,    0}, {1, 1, 1, 0}},
				{{ halfW, topY,    0}, {1, 1, 1, 0}},
				{{ halfW, bottomY, 0}, {1, 1, 1, 1}},
				{{-halfW, bottomY, 0}, {1, 1, 1, 1}},
			})
			self:SetDrawState({Mode="DrawMode_Quads", First=1, Num=4})
			self:diffusealpha(0)
		end,
		FlashCommand = function(self, params)
			local c = params and params.color or color("#FF5050")
			self:stoptweening()
			self:diffuse(c)
			self:diffusealpha(0.35)
			self:linear(0.70)
			self:diffusealpha(0)
		end
	}
end

t[#t + 1] = Def.ActorFrame {
	Name = "ComboBreakHighlight",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
	end,

	makeCBLane("Lane1", -96, 64),
	makeCBLane("Lane2", -32, 64),
	makeCBLane("Lane3",  32, 64),
	makeCBLane("Lane4",  96, 64),

	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if not params.TapNoteScore then return end

		local isComboBreak = (params.TapNoteScore == "TapNoteScore_Miss" or
							  params.TapNoteScore == "TapNoteScore_W5" or
							  params.TapNoteScore == "TapNoteScore_W4")

		if isComboBreak and params.Notes then
			local jColor = color("#FF5050")
			if params.TapNoteScore == "TapNoteScore_W4" then jColor = judgmentColors[4]
			elseif params.TapNoteScore == "TapNoteScore_W5" then jColor = judgmentColors[5]
			elseif params.TapNoteScore == "TapNoteScore_Miss" then jColor = judgmentColors[6] end

			for i = 1, 4 do
				if params.Notes[i] ~= nil then
					local lane = self:GetChild("Lane" .. i)
					if lane then
						lane:playcommand("Flash", {color=jColor})
					end
				end
			end
		end
	end
}
end -- End combo break highlight

t[#t + 1] = Def.ActorFrame {
	Name = "IndicatorFrame",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, barY + 15):visible(GAMESTATE:IsPracticeMode())
	end,
	LoadFont("Common Normal") .. {
		Text = "** PRACTICE MODE **",
		InitCommand = function(self) self:zoom(0.35):diffuse(accentColor):diffusealpha(0.8) end
	}
}

t[#t + 1] = Def.ActorFrame {
	Name = "ChordDensityGraphContainer",
	InitCommand = function(self)
		self:xy(SCREEN_LEFT + 20, SCREEN_CENTER_Y)
		self:visible(not isSync and GAMESTATE:IsPracticeMode())
	end,
	LoadActor("../_chorddensitygraph.lua") .. {
		InitCommand = function(self)
			self:zoom(0.8)
		end
	}
}

t[#t + 1] = LoadActor("replayscrolling.lua")

-- ============================================================
-- ERROR BAR (TIMING BAR)
-- ============================================================
local ebH = 2
local maxOffset = 180 -- ms
local dotLife = 2.0  -- seconds

local ewmaValue = 0
local ewmaAlpha = 0.07
local ebMode = ThemePrefs.Get("HV_ErrorBarMode") or "Standard"
local showEWMA = (ebMode == "EWMAOnly" or ebMode == "Both")
local showStandard = (ebMode == "Standard" or ebMode == "Both")

t[#t + 1] = Def.ActorFrame {
	Name = "ErrorBar",
	InitCommand = function(self)
		local coords, sizes = getCoords()
		local ebMode = ThemePrefs.Get("HV_ErrorBarMode") or "Standard"
		self:xy(coords.ErrorBarX, coords.ErrorBarY - 267):visible(ebMode ~= "Off" and not isSync)
		self.ebW = sizes.ErrorBarWidth or 280
	end,

	Def.Quad {
		InitCommand = function(self)
			local ebW = self:GetParent().ebW or 280
			self:zoomto(ebW, ebH):visible(false)
		end
	},

	Def.Quad {
		Name = "CenterLine",
		InitCommand = function(self)
			self:zoomto(1, ebH + 8):diffuse(color("1,1,1,0.3"))
		end
	},
	
	LoadFont("Common Normal") .. {
		Text = "EARLY",
		InitCommand = function(self)
			local ebW = self:GetParent().ebW or 240
			self:x(-ebW/2 - 5):y(-12):zoom(0.25):halign(0):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(0.5):linear(0.2):diffusealpha(0.6):sleep(1.2):linear(0.2):diffusealpha(0)
		end
	},
	LoadFont("Common Normal") .. {
		Text = "LATE",
		InitCommand = function(self)
			local ebW = self:GetParent().ebW or 240
			self:x(ebW/2 + 5):y(-12):zoom(0.25):halign(1):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(0.5):linear(0.2):diffusealpha(0.6):sleep(1.2):linear(0.2):diffusealpha(0)
		end
	},

	Def.Quad {
		Name = "EWMAMarker",
		InitCommand = function(self)
			self:zoomto(2, ebH + 8):diffuse(accentColor):visible(showEWMA)
		end,
		UpdateEWMACommand = function(self, params)
			local ebW = self:GetParent().ebW or 240
			local offset = params.offset
			ewmaValue = (1 - ewmaAlpha) * ewmaValue + ewmaAlpha * offset
			self:x((ewmaValue / maxOffset) * (ebW / 2))
		end
	},

	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if not params.TapNoteScore then return end
		if params.HoldNoteScore then return end

		local offset = params.TapNoteOffset
		if not offset then return end

		if params.TapNoteScore == "TapNoteScore_Miss" then return end

		local visualOffset = offset * 1000
		local ebW = self.ebW or 240
		
		if showEWMA then
			self:GetChild("EWMAMarker"):playcommand("UpdateEWMA", {offset = visualOffset})
		end

		if not showStandard then return end
		if math.abs(visualOffset) > maxOffset then return end

		local ebColoring = ThemePrefs.Get("HV_ErrorBarColoringMode") or "Current"
		local jScale = 1
		if ebColoring == "Current" then
			jScale = PREFSMAN:GetPreference("TimingWindowScale")
		end

		local xPos = (visualOffset / maxOffset) * (ebW / 2)
		local jColor = offsetToJudgeColor(visualOffset, jScale)

		local pool = self:GetChild("Pool")
		if pool then
			self.poolIdx = (self.poolIdx or 0) % 50 + 1
			local dot = pool:GetChild("Dot"..self.poolIdx)
			if dot then
				dot:stoptweening():visible(true):x(xPos):diffuse(jColor):diffusealpha(0.8)
					:sleep(dotLife):linear(0.5):diffusealpha(0)
			end
		end
	end,

	(function()
		local poolDef = Def.ActorFrame { Name = "Pool" }
		for i=1, 50 do
			poolDef[#poolDef + 1] = Def.Quad {
				Name = "Dot"..i,
				InitCommand = function(s)
					s:zoomto(1, ebH + 6):visible(false)
				end
			}
		end
		return poolDef
	end)()
}

-- ============================================================
-- TWO-COLUMN JUDGMENT TALLY + PERFORMANCE METRICS
-- ============================================================
local colSpacing = 70
local showJudgeCounter = HV.ShowJudgeCounter()

if showJudgeCounter and not HV.MinimalisticMode() and not isSync then
t[#t + 1] = Def.ActorFrame {
	Name = "TallyAndMetrics",
	InitCommand = function(self)
		local coords, sizes = getCoords()
		self:xy(coords.JudgeCounterX - 45, coords.JudgeCounterY - 45):diffusealpha(0.8)
	end,

	Def.ActorFrame {
		Name = "Column1_Judgments",
		
		(function()
			local g = Def.ActorFrame{}
			for i, label in ipairs(judgmentLabels) do
				g[#g+1] = Def.ActorFrame {
					InitCommand = function(self)
						self:y((i - 1) * 13)
					end,

					LoadFont("Common Normal") .. {
						InitCommand = function(self)
							self:halign(0):valign(0):zoom(0.34):diffuse(judgmentColors[i]):diffusealpha(0.8)
							self:settext(label)
						end
					},

					LoadFont("Common Normal") .. {
						Name = "TallyCount_" .. label,
						InitCommand = function(self)
							self:halign(1):valign(0):x(60):zoom(0.34):diffuse(mainText):diffusealpha(0.8)
							self:settext("0")
						end,
						JudgmentMessageCommand = function(self)
							self:queuecommand("Update")
						end,
						UpdateCommand = function(self)
							local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
							if pss then
								self:settext(pss:GetTapNoteScores(judgmentTNS[i]))
							end
						end,
						PracticeModeResetMessageCommand = function(self) self:settext("0") end,
						PracticeModeReloadMessageCommand = function(self) self:settext("0") end
					}
				}
			end
			return g
		end)(),

		Def.ActorFrame {
			Name = "OKNGDisplay",
			InitCommand = function(self)
				self:y(#judgmentLabels * 16 + 4)
			end,

			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:halign(0):valign(0):y(-22):zoom(0.34):diffuse(HVColor.GetJudgmentColor("Held")):diffusealpha(0.8)
					self:settext(THEME:GetString("HoldNoteScore", "OK"))
				end
			},
			LoadFont("Common Normal") .. {
				Name = "OKCount",
				InitCommand = function(self)
					self:halign(1):valign(0):x(60):y(-22):zoom(0.34):diffuse(mainText):diffusealpha(0.8)
					self:settext("0")
				end,
				JudgmentMessageCommand = function(self)
					self:queuecommand("Update")
				end,
				UpdateCommand = function(self)
					local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
					if pss then
						local ok = pss:GetHoldNoteScores("HoldNoteScore_Held")
						self:settext(tostring(ok))
					end
				end,
				PracticeModeResetMessageCommand = function(self) self:settext("0") end,
				PracticeModeReloadMessageCommand = function(self) self:settext("0") end
			},

			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:halign(0):valign(0):y(-9.5):zoom(0.34):diffuse(HVColor.GetJudgmentColor("LetGo")):diffusealpha(0.8)
					self:settext(THEME:GetString("HoldNoteScore", "NG"))
				end
			},
			LoadFont("Common Normal") .. {
				Name = "NGCount",
				InitCommand = function(self)
					self:halign(1):valign(0):x(60):y(-9.5):zoom(0.34):diffuse(mainText):diffusealpha(0.8)
					self:settext("0")
				end,
				JudgmentMessageCommand = function(self)
					self:queuecommand("Update")
				end,
				UpdateCommand = function(self)
					local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
					if pss then
						local ng = pss:GetHoldNoteScores("HoldNoteScore_LetGo")
						self:settext(tostring(ng))
					end
				end,
				PracticeModeResetMessageCommand = function(self) self:settext("0") end,
				PracticeModeReloadMessageCommand = function(self) self:settext("0") end
			}
		}
	},

	Def.ActorFrame {
		Name = "Column2_Metrics",
		InitCommand = function(self)
			self:x(colSpacing)
			if HV.GetJudgmentTallyMode() == "Simple" then
				self:visible(false)
			end
		end,

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoom(0.34):diffuse(dimText)
				self:settext("J4")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "RescoreValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):zoom(0.34):diffuse(subText)
				self:settext("0.0000%")
				self.currWifePoints = 0
			end,
			JudgmentMessageCommand = function(self, msg)
				if msg.TapNoteScore and msg.TapNoteScore ~= "TapNoteScore_AvoidMine" and msg.TapNoteScore ~= "TapNoteScore_CheckpointHit" then
					local ts = ms.JudgeScalers[4] or 1.0
					if msg.TapNoteOffset then
						self.currWifePoints = self.currWifePoints + wife3(math.abs(msg.TapNoteOffset) * 1000, ts, "Wife3")
					elseif msg.TapNoteScore == "TapNoteScore_Miss" then
						self.currWifePoints = self.currWifePoints - 5.5
					elseif msg.TapNoteScore == "TapNoteScore_HitMine" then
						self.currWifePoints = self.currWifePoints - 7.0
					end
				elseif msg.HoldNoteScore == "HoldNoteScore_LetGo" then
					self.currWifePoints = self.currWifePoints - 4.5
				end
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local notesPassed = pss:GetTapNoteScores("TapNoteScore_W1") +
									   pss:GetTapNoteScores("TapNoteScore_W2") +
									   pss:GetTapNoteScores("TapNoteScore_W3") +
									   pss:GetTapNoteScores("TapNoteScore_W4") +
									   pss:GetTapNoteScores("TapNoteScore_W5") +
									   pss:GetTapNoteScores("TapNoteScore_Miss")
					local maxPoints = notesPassed * 2
					if maxPoints > 0 then
						local j4 = math.min((self.currWifePoints / maxPoints) * 100, 100)
						self:settext(string.format("%.4f%%", j4))
					else
						self:settext("100.0000%")
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self.currWifePoints = 0; self:settext("100.0000%") end,
			PracticeModeReloadMessageCommand = function(self) self.currWifePoints = 0; self:settext("100.0000%") end
		},

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):y(16):zoom(0.34):diffuse(dimText)
				self:settext("MA Ratio")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "MARatioValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):y(16):zoom(0.34):diffuse(subText)
				self:settext("0.00:1")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local w1 = pss:GetTapNoteScores("TapNoteScore_W1")
					local w2 = pss:GetTapNoteScores("TapNoteScore_W2")
					if w2 > 0 then
						self:settext(string.format("%.2f:1", w1 / w2))
					elseif w1 > 0 then
						self:settext("inf:1")
					else
						self:settext("0.00:1")
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0.00:1") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0.00:1") end
		},

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):y(32):zoom(0.34):diffuse(dimText)
				self:settext("PA Ratio")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "PARatioValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):y(32):zoom(0.34):diffuse(subText)
				self:settext("0.00:1")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local w2 = pss:GetTapNoteScores("TapNoteScore_W2")
					local w3 = pss:GetTapNoteScores("TapNoteScore_W3")
					if w3 > 0 then
						self:settext(string.format("%.2f:1", w2 / w3))
					elseif w2 > 0 then
						self:settext("inf:1")
					else
						self:settext("0.00:1")
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0.00:1") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0.00:1") end
		},

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):y(48):zoom(0.34):diffuse(dimText)
				self:settext("Longest")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "MaxComboValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):y(48):zoom(0.34):diffuse(subText)
				self:settext("0")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					self:settext(tostring(pss:MaxCombo()))
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0") end
		},

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):y(64):zoom(0.34):diffuse(dimText)
				self:settext("SD")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "SDValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):y(64):zoom(0.34):diffuse(subText)
				self:settext("0.00")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local dvt = pss:GetOffsetVector()
					if dvt and #dvt > 0 then
						self:settext(string.format("%.2f", wifeSd(dvt)))
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0.00") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0.00") end
		},

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):y(80):zoom(0.34):diffuse(dimText)
				self:settext("Max")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "LargestValue",
			InitCommand = function(self)
				self:halign(1):valign(0):x(65):y(80):zoom(0.34):diffuse(subText)
				self:settext("0.00")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local dvt = pss:GetOffsetVector()
					if dvt and #dvt > 0 then
						self:settext(string.format("%.2f", wifeMax(dvt)))
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0.00") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0.00") end
		}
	}
}
end

-- ============================================================
-- SONG TITLE (TOP of screen)
-- ============================================================
if not HV.MinimalisticMode() and not isSync then
t[#t + 1] = Def.ActorFrame {
	Name = "SongInfoHUD",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, barY + 22)
	end,
	OnCommand = function(self)
		self:diffusealpha(0.6)
	end,

	LoadFont("_open sans Bold 48px") .. {
		InitCommand = function(self)
			self:y(-5):zoom(0.25):diffuse(mainText):maxwidth(SCREEN_WIDTH * 0.6 / 0.25)
		end,
		BeginCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:settext(song:GetDisplayMainTitle())
			end
		end
	},

	LoadFont("_open sans Bold 48px") .. {
		InitCommand = function(self)
			self:y(14):zoom(0.15):diffuse(subText):maxwidth(SCREEN_WIDTH / 0.28)
		end,
		PlayingUpdateMessageCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local bps = GAMESTATE:GetSongPosition():GetCurBPS()
				local bpm = bps * 60 * getCurRateValue()
				local rate = getCurRateString()
				self:settextf("%d BPM    %s Rate", math.floor(bpm + 0.5), rate)
			end
		end
	}
}
end

-- ============================================================
-- LANE COVER
-- ============================================================
local suddenHeight = HV.GetLaneCoverSudden()
local hiddenHeight = HV.GetLaneCoverHidden()

if suddenHeight > 0 or hiddenHeight > 0 then
	local isReverse = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():UsingReverse()
	
	local function createCover(height, isTop)
		local h = SCREEN_HEIGHT * (height / 100)
		return Def.Quad {
			InitCommand = function(self)
				self:zoomto(SCREEN_WIDTH, h)
					:diffuse(color("0,0,0,1"))
				if isTop then
					self:valign(0):y(-SCREEN_HEIGHT / 2)
				else
					self:valign(1):y(SCREEN_HEIGHT / 2)
				end
			end
		}
	end

	local t_cover = Def.ActorFrame {
		Name = "LaneCoverLayer",
		InitCommand = function(self)
			self:Center()
			self:visible(not isSync)
		end,
	}

	if suddenHeight > 0 then
		t_cover[#t_cover + 1] = createCover(suddenHeight, not isReverse)
	end

	if hiddenHeight > 0 then
		t_cover[#t_cover + 1] = createCover(hiddenHeight, isReverse)
	end
	
	t[#t + 1] = t_cover
end

if not isSync then
	t[#t + 1] = LoadActor("scoretracking")
	t[#t + 1] = LoadActor("pacemaker")
	t[#t + 1] = Def.ActorFrame {
		Name = "AutofailDisplay",
		InitCommand = function(self)
			self:xy(10, SCREEN_CENTER_Y + 40)
			self:visible(false)
		end,
		BeginCommand = function(self)
			self:queuecommand("Refresh")
		end,
		ThemePrefChangedMessageCommand = function(self, params)
			if not params or not params.Name then return end
			if params.Name:find("HV_AutoFail") then
				self:queuecommand("Refresh")
			end
		end,
		HV_PointsUpdateMessageCommand = function(self)
			self:queuecommand("Refresh")
		end,
		RefreshCommand = function(self)
			local actionMode = ThemePrefs.Get("HV_AutoFailMode")
			if actionMode == "Off" or not actionMode then
				self:visible(false)
				return
			end
			if HV.MinimalisticMode() then
				self:visible(false)
				return
			end
			self:visible(true)
			local condition = ThemePrefs.Get("HV_AutoFailCondition")
			local iconWife = self:GetChild("IconWife")
			local iconPB = self:GetChild("IconPB")
			local iconTarget = self:GetChild("IconTarget")
			if iconWife then iconWife:visible(condition == "Wife Percent") end
			if iconPB then iconPB:visible(condition == "Personal Best") end
			if iconTarget then iconTarget:visible(condition == "Judgement Count") end
			local txt = self:GetChild("Value")
			if not txt then return end
			local display = ""
			local c = color("1,1,1,1")
			if condition == "Wife Percent" then
				local threshold = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Wife")) or 93.00
				display = string.format("%.4f%%", threshold)
				txt:xy(11, 20)
			elseif condition == "Personal Best" then
				if not HV_PBThreshold or HV_PBThreshold == 0 then
					local best = GetDisplayScore()
					if best then
						HV_PBThreshold = getJ4NormalizedPercentage(best)
					else
						HV_PBThreshold = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Wife")) or 93.00
					end
				end
				display = string.format("%.4f%%", HV_PBThreshold or 0)
				txt:xy(11, 20)
			elseif condition == "Judgement Count" then
				local limit = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Count")) or 10
				local judgePref = ThemePrefs.Get("HV_AutoFailJudgement") or "Miss"
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				local currentCount = 0
				if pss then
					local order = {"W2","W3","W4","W5","Miss"}
					local idx = 5
					for i=1, #order do
						if order[i] == judgePref then idx = i break end
					end
					for i=idx, #order do
						currentCount = currentCount + pss:GetTapNoteScores("TapNoteScore_" .. order[i])
					end
				end
				local remaining = math.max(0, limit - currentCount)
				display = tostring(remaining)
				c = HVColor.GetJudgmentColor(judgePref)
				txt:xy(24, 20)
			end
			txt:settext(display)
			txt:diffuse(c)
		end,
		Def.Sprite {
			Name = "IconWife",
			Texture = THEME:GetPathG("", "wife.png"),
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(0, 0):zoom(0.20):visible(false)
			end
		},
		Def.Sprite {
			Name = "IconPB",
			Texture = THEME:GetPathG("", "pb.png"),
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(0, 0):zoom(0.20):visible(false)
			end
		},
		Def.Sprite {
			Name = "IconTarget",
			Texture = THEME:GetPathG("", "target.png"),
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(0, 0):zoom(0.20):visible(false)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Value",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(11, 20):zoom(0.55)
				self:settext("")
			end
		}
	}
	t[#t + 1] = LoadActor("npscalc")
	t[#t + 1] = LoadActor("leaderboard")
	t[#t + 1] = LoadActor("avatar")
end
t[#t + 1] = LoadActor("intro")

-- ============================================================
-- NG INDICATOR (POPUP)
-- ============================================================
if HV.ShowNGIndicator() and not HV.MinimalisticMode() and not isSync then
	local isReverse = GAMESTATE:GetPlayerState(PLAYER_1):GetCurrentPlayerOptions():UsingReverse()
	local ngY = isReverse and (SCREEN_CENTER_Y + 164 - 40) or (SCREEN_CENTER_Y - 164 + 40)
	local colOffsets = {-96, -32, 32, 96}

	local ngFrame = Def.ActorFrame { Name = "NGIndicator" }
	for i = 1, 4 do
		ngFrame[#ngFrame + 1] = LoadFont("Common Normal") .. {
			Name = "NG_" .. i,
			InitCommand = function(self)
				self:xy(SCREEN_CENTER_X + colOffsets[i], ngY)
				self:zoom(1.2):diffuse(color("#FF4444")):diffusealpha(0):settext("NG")
			end,
			JudgmentMessageCommand = function(self, params)
				if params.HoldNoteScore == "HoldNoteScore_LetGo" then
					local laneMatch = false
					if params.Notes and params.Notes[i] ~= nil then
						laneMatch = true
					elseif params.FirstTrack == (i - 1) then
						laneMatch = true
					end
					if laneMatch then
						self:stoptweening():diffusealpha(1):zoom(1.2):linear(0.2):zoom(1.5):linear(0.2):zoom(1.2):sleep(0.5):linear(0.2):diffusealpha(0)
					end
				end
			end
		}
	end
	t[#t + 1] = ngFrame
end

-- ============================================================
-- SYNC MODE CHALLENGE (Note Fading)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "SyncChallengeOverlay",
	InitCommand = function(self) self:visible(isSync) end,
	(function()
		local noteCounter = 0
		local threshold = 10
		local triggered = false
		
		return Def.ActorFrame {
			LoadFont("Common Normal") .. {
				Name = "Message",
				InitCommand = function(self)
					self:Center():zoom(0.8):diffusealpha(0):settext("Keep tapping to the beat")
				end,
				PulseCommand = function(self)
					self:stoptweening():linear(0.5):zoom(0.85):linear(0.5):zoom(0.8):queuecommand("Pulse")
				end
			},
			JudgmentMessageCommand = function(self, params)
				if not isSync or triggered then return end
				if params.TapNoteScore then
					noteCounter = noteCounter + 1
					if noteCounter >= threshold then
						triggered = true
						MESSAGEMAN:Broadcast("SyncTriggered")
						local msg = self:GetChild("Message")
						msg:linear(1):diffusealpha(1):queuecommand("Pulse")
					end
				end
			end,
			CurrentSongChangedMessageCommand = function(self)
				noteCounter = 0
				triggered = false
				local msg = self:GetChild("Message")
				if msg then msg:stoptweening():diffusealpha(0) end
			end
		}
	end)()
}

-- ============================================================
-- END-OF-CHART CLEAR TYPE CELEBRATION
-- ============================================================
local function CelebrationBurst()
	local burst = Def.ActorFrame{
		CelebrationCommand = function(self, params)
			local count = 0
			local maxRays = params.numRays or 10
			local speed = params.speed or 0.6
			local burstColor = params.color or color("#FFFFFF")
			
			self:RunCommandsOnChildren(function(child)
				count = count + 1
				if count <= maxRays then
					child:playcommand("Burst", {
						numRays = maxRays, 
						speed = speed, 
						color = burstColor, 
						index = count
					})
				end
			end)
		end,
	}
	for i = 1, 24 do
		burst[#burst+1] = Def.Quad{
			InitCommand = function(self)
				self:zoomto(2, 200):diffusealpha(0)
			end,
			BurstCommand = function(self, params)
				self:stoptweening():diffusealpha(0):zoomto(2, 0)
				self:rotationz((params.index - 1) * (360 / params.numRays))
				
				if params.isHeartbreak then
					self:diffuse(color("#FF0000"))
				else
					self:diffuse(color("#FFFFFF"))
				end
				
				self:sleep(0.05):linear(params.speed * 0.4):zoomto(4, 400):diffusealpha(0.6):diffuse(params.color)
				self:linear(params.speed * 0.6):zoomto(0, 0):diffusealpha(0)
			end
		}
	end
	return burst
end

t[#t+1] = Def.ActorFrame{
	Name = "EndOfChartClearType",
	InitCommand = function(self)
		self:Center():visible(true)
	end,

	CelebrationBurst(),

	Def.ActorFrame{
		Name = "CTRiseFrame",
		InitCommand = function(self)
			self:diffusealpha(0):y(30)
		end,
		OffCommand = function(self)
			if isSync then return end
			
			self:sleep(0.05)
			
			local epn = pn or GAMESTATE:GetEnabledPlayers()[1] or PLAYER_1
			local epss = STATSMAN:GetCurStageStats():GetPlayerStageStats(epn)
			if not epss then return end
			local steps = GAMESTATE:GetCurrentSteps()
			if not steps then return end
			
			local clearLevel = getClearLevel(epn, steps, epss)

			if clearLevel > 7 and epss:FullComboOfScore("TapNoteScore_W3") then
				clearLevel = 7
			end

			if clearLevel <= 7 then
				local ctName = getClearType(epn, steps, epss)
				if clearLevel == 7 and (not ctName or ctName == "") then ctName = "FC" end
				
				local ctText = getClearTypeText(ctName)
				local ctColor = getClearTypeColor(ctName)

				local numRays = 10
				local burstSpeed = 0.6
				local isHeartbreak = false
				
				if clearLevel == 1 then
					numRays = 24
					burstSpeed = 0.4
				elseif clearLevel == 2 then
					numRays = 20
					burstSpeed = 0.45
					isHeartbreak = true
				elseif clearLevel <= 4 then
					numRays = 16
					burstSpeed = 0.5
				elseif clearLevel == 5 then
					numRays = 14
					burstSpeed = 0.55
					isHeartbreak = true
				end

				local txt = self:GetChild("CTText")
				txt:stoptweening():settext(ctText)
				
				if isHeartbreak then
					txt:diffuse(color("#FF0000"))
				else
					txt:diffuse(color("#FFFFFF"))
				end

				self:GetParent():RunCommandsOnChildren(function(c) 
					c:playcommand("Celebration", {
						numRays = numRays, 
						speed = burstSpeed, 
						color = ctColor, 
						isHeartbreak = isHeartbreak
					})
				end)

				self:stoptweening()
				self:y(30):diffusealpha(0):zoom(1.5)
				self:decelerate(0.5):y(0):diffusealpha(1):zoom(1)

				if clearLevel == 2 then
					for i=1, 4 do
						self:sleep(0.02):x(-3):sleep(0.02):x(3)
					end
					self:sleep(0.02):x(0)
				elseif clearLevel == 5 then
					self:bounce(0.2):effectmagnitude(0, -6, 0):effectclock("bgm"):effectperiod(0.1)
					self:sleep(0.4):stopeffect()
				end

				if isHeartbreak then
					txt:sleep(0.4):linear(0.2):diffuse(color("#FFFFFF")):linear(0.5):diffuse(ctColor)
				else
					txt:sleep(0.3):linear(0.5):diffuse(ctColor)
				end
				
				txt:sleep(0.2):linear(0.4):diffusealpha(0.8):linear(0.4):diffusealpha(1)
				self:sleep(3):smooth(1):diffusealpha(0):y(-10)
			end
		end,

		LoadFont("Common Large") .. {
			Name = "CTText",
			InitCommand = function(self)
				self:zoom(0.7):strokecolor(color("0,0,0,0.6"))
			end
		}
	}
}

-- ============================================================
-- AUTO-FAIL / RESTART MECHANIC
-- ============================================================
t[#t + 1] = Def.Actor {
	Name = "AutoFailController",
	InitCommand = function(self)
		self.hasTriggered = false
	end,
	HV_PointsUpdateMessageCommand = function(self)
		local actionMode = ThemePrefs.Get("HV_AutoFailMode")
		if actionMode == "Off" or not actionMode or self.hasTriggered then return end
		
		local condition = ThemePrefs.Get("HV_AutoFailCondition")
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if not pss then return end
		
		local triggered = false

		if condition == "Wife Percent" then
			local threshold = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Wife")) or 93.00
			local subtractiveWife = ((HV_TotalMaxPoints - HV_PointsLost) / HV_TotalMaxPoints) * 100
			if subtractiveWife < threshold then 
				triggered = true 
			end
		elseif condition == "Personal Best" then
			local subtractiveWife = ((HV_TotalMaxPoints - HV_PointsLost) / HV_TotalMaxPoints) * 100
			if subtractiveWife < HV_PBThreshold then
				triggered = true
			end
		elseif condition == "Judgement Count" then
			local limit = tonumber(ThemePrefs.Get("HV_AutoFailThreshold_Count")) or 10
			local judgePref = ThemePrefs.Get("HV_AutoFailJudgement") or "Miss"
			local order = {"W2","W3","W4","W5","Miss"}
			local idx = 5
			for i=1, #order do
				if order[i] == judgePref then idx = i break end
			end
			local currentCount = 0
			for i=idx, #order do
				currentCount = currentCount + pss:GetTapNoteScores("TapNoteScore_" .. order[i])
			end
			if currentCount > 0 and currentCount >= limit then 
				triggered = true 
			end
		end

		if triggered then
			self:playcommand("ActionTriggered")
		end
	end,
	ActionTriggeredCommand = function(self)
		if self.hasTriggered then return end
		self.hasTriggered = true

		local actionMode = ThemePrefs.Get("HV_AutoFailMode")
		local top = SCREENMAN:GetTopScreen()
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		
		if top and pss then
			if pss.FailPlayer then
				pss:FailPlayer()
			end
			
			if actionMode == "Fail" then
				top:PostScreenMessage("SM_BeginFailed", 0)
			elseif actionMode == "Restart" then
				SCREENMAN:SetNewScreen("ScreenGameplay")
			end
		end
	end
}

return t
