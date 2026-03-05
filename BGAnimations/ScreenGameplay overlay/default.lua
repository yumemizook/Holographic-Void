--- Holographic Void: ScreenGameplay Overlay
-- Overhauled HUD:
--   - Clean vertical life bar with % counter (per-note update)
--   - Per-note score%, combo, and 4-digit accuracy tracker
--   - Progress bar at TOP, song title at BOTTOM
--   - Compact judgment tally with OK/NG and real-time grade
--   - Centered combo (no duplicate judgment display, no animations)
--   - Toasty animation preserved

local t = Def.ActorFrame {
	Name = "GameplayOverlay",
	InitCommand = function(self)
		-- Apply Mini mod (Receptor Size)
		local miniValue = tonumber(ThemePrefs.Get("HV_Mini")) or 100
		-- Etterna's 'Mini' mod is 100% at mini=1.0, 0% at mini=0.0 (normal size).
		-- We use a simpler direct % conversion:
		local miniPct = 100 - miniValue
		local modStr = miniPct .. "% mini"
		
		-- Apply Measure Lines (Beat Bars) mod
		local showMeasure = (ThemePrefs.Get("HV_ShowMeasureLines") == "true" or ThemePrefs.Get("HV_ShowMeasureLines") == true)
		local beatBarMod = showMeasure and "beatbars" or "nobeatbars"
		
		for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
			local ps = GAMESTATE:GetPlayerState(pn)
			local po = ps:GetPlayerOptions("ModsLevel_Preferred")
			po:FromString(modStr)
			po:FromString(beatBarMod)
		end
	end,
	PracticeModeResetMessageCommand = function(self) self:playcommand("Init") end,
	PracticeModeReloadMessageCommand = function(self) self:playcommand("Init") end
}

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")

local judgmentColors = {
	color("#FFFFFF"), color("#E0E0A0"), color("#A0E0A0"),
	color("#A0C8E0"), color("#C8A0E0"), color("#E0A0A0")
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
-- Remove the global broadcaster as we'll use per-component high-freq updates for critical elements
-- (Keeping the ActorFrame for any future global needs but removing the broadcast)
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		self:SetUpdateFunction(function(self)
			-- Lifebar still uses this for now
			MESSAGEMAN:Broadcast("PlayingUpdate")
		end)
	end
}

-- ============================================================
-- SONG PROGRESS BAR (TOP of screen)
-- ============================================================
local barW = SCREEN_WIDTH * 0.4
local barH = 6
local barY = 12

t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, barY)
	end,
	BeginCommand = function(self)
		self:SetUpdateFunction(function(self)
			self:playcommand("UpdateBars")
		end)
	end,

	Def.Quad {
		InitCommand = function(self)
			self:zoomto(barW, barH):diffuse(color("0.15,0.15,0.15,1"))
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

	-- Remaining Time (incorporating music rate and ms)
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

	-- Elapsed Time (incorporating music rate and ms)
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
		end,
		PracticeModeResetMessageCommand = function(self) self:queuecommand("UpdateBars") end,
		PracticeModeReloadMessageCommand = function(self) self:queuecommand("UpdateBars") end
	}
}

-- Practice Mode Indicator
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "PracticeIndicator",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, barY + 15):zoom(0.35):diffuse(accentColor):diffusealpha(0.8)
		self:settext("** Practice Mode **"):visible(GAMESTATE:IsPracticeMode())
	end
}

-- ============================================================
-- VERTICAL LIFE BAR (right edge) with % counter
-- ============================================================
local lifeBarW = 8
local lifeBarH = SCREEN_HEIGHT * 0.5
local lifeBarX = SCREEN_CENTER_X + 220
local lifeBarY = SCREEN_CENTER_Y

t[#t + 1] = Def.ActorFrame {
	Name = "VerticalLifeBar",
	InitCommand = function(self)
		self:xy(lifeBarX, lifeBarY)
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
			self:playcommand("RefreshLife")
		end,
		PlayingUpdateMessageCommand = function(self)
			self:playcommand("RefreshLife")
		end,
		RefreshLifeCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local lifeVal = pss:GetCurrentLife()
				if lifeVal then
					local fillH = lifeBarH * lifeVal
					self:zoomto(lifeBarW, fillH)
					if lifeVal > 0.5 then
						self:diffuse(accentColor):diffusealpha(0.8)
					elseif lifeVal > 0.25 then
						self:diffuse(color("#FFD060")):diffusealpha(0.8)
					else
						self:diffuse(color("#FF5050")):diffusealpha(0.9)
					end
				end
			end
		end
	},

	Def.Quad {
		InitCommand = function(self)
			self:zoomto(lifeBarW + 2, lifeBarH + 2)
				:diffuse(color("0.2,0.2,0.2,0.3"))
		end
	},

	-- Life % counter
	LoadFont("Common Normal") .. {
		Name = "LifePct",
		InitCommand = function(self)
			self:y(-lifeBarH / 2 - 10):zoom(0.25):diffuse(subText)
		end,
		JudgmentMessageCommand = function(self)
			self:playcommand("RefreshLifePct")
		end,
		PlayingUpdateMessageCommand = function(self)
			self:playcommand("RefreshLifePct")
		end,
		RefreshLifePctCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local lifeVal = pss:GetCurrentLife()
				if lifeVal then
					self:settext(string.format("%.0f%%", lifeVal * 100))
				end
			end
		end,
		PracticeModeResetMessageCommand = function(self) self:playcommand("RefreshLifePct") end,
		PracticeModeReloadMessageCommand = function(self) self:playcommand("RefreshLifePct") end
	}
}

-- ============================================================
-- CENTERED SCORE % (REAL-TIME)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "CenteredScore",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 90):diffusealpha(0.8)
	end,

	LoadFont("Common Normal") .. {
		Name = "ScoreValue",
		InitCommand = function(self)
			self:zoom(0.45):diffuse(brightText):diffusealpha(0.7)
			self:settext("0.00%")
		end,
		JudgmentMessageCommand = function(self, params)
			local wifePct
			if params and params.WifePercent then
				wifePct = params.WifePercent
			else
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local totalTaps = pss:GetTotalTaps()
					local steps = GAMESTATE:GetCurrentSteps()
					local pn = PLAYER_1
					if totalTaps > 0 then
						-- Correct accuracy so far: points / (events * 2)
						wifePct = (pss:GetWifeScore() / (totalTaps * 2)) * 100
					else
						wifePct = 0
					end
				end
			end
			if not wifePct then return end
			self:settext(string.format("%.4f%%", wifePct))
			-- Color based on wife%
			local gradeStr = "F"
			if     wifePct >= 99.9935 then gradeStr = "AAAAA"
			elseif wifePct >= 99.955  then gradeStr = "AAAA"
			elseif wifePct >= 99.70   then gradeStr = "AAA"
			elseif wifePct >= 93.00   then gradeStr = "AA"
			elseif wifePct >= 80.00   then gradeStr = "A"
			elseif wifePct >= 70.00   then gradeStr = "B"
			elseif wifePct >= 60.00   then gradeStr = "C"
			elseif wifePct >= 0       then gradeStr = "D"
			end
			self:diffuse(HVColor.GetGradeColor(gradeStr)):diffusealpha(0.7)
		end,
		PracticeModeResetMessageCommand = function(self) self:settext("0.00%") end,
		PracticeModeReloadMessageCommand = function(self) self:queuecommand("Judgment") end
	}
}

-- ============================================================
-- TEXT PACEMAKER (TIL DEATH STYLE)
-- ============================================================
local showTextPacemaker = (ThemePrefs.Get("HV_ShowTextPacemaker") == "true" or ThemePrefs.Get("HV_ShowTextPacemaker") == true)
if showTextPacemaker then
	local pacemakerMode = ThemePrefs.Get("HV_PacemakerTargetType") or "Target"
	local targetGoalPct = tonumber(ThemePrefs.Get("HV_PacemakerTargetGoal")) or 93
	local targetGoal = targetGoalPct / 100

	-- Set the engine-side target goal and replay mode
	GAMESTATE:GetPlayerState():SetTargetGoal(targetGoal)
	GAMESTATE:GetPlayerState():SetGoalTrackerUsesReplay(pacemakerMode == "PBReplay")

	t[#t + 1] = Def.ActorFrame {
		Name = "TextPacemaker",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 115)
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0.5):zoom(0.35)
				self:settextf("%+5.2f (%5.2f%%)", 0, targetGoalPct)
				self:diffuse(color("#00ff00"))
			end,
			JudgmentMessageCommand = function(self, msg)
				local tDiff = msg.WifeDifferential
				local displayTarget = targetGoalPct

				-- In PB or PB Replay mode, use the PB goal/differential if available
				if (pacemakerMode == "PB" or pacemakerMode == "PBReplay") and msg.WifePBGoal ~= nil then
					tDiff = msg.WifePBDifferential
					displayTarget = msg.WifePBGoal * 100
				end

				if tDiff >= 0 then
					self:diffuse(color("#00ff00"))
				else
					self:diffuse(HVColor.Negative or color("#ff0000"))
				end
				self:settextf("%+5.2f (%5.2f%%)", tDiff, displayTarget)
			end,
			PracticeModeResetMessageCommand = function(self) self:settextf("%+5.2f (%5.2f%%)", 0, targetGoalPct) end,
			PracticeModeReloadMessageCommand = function(self) self:queuecommand("Judgment") end
		}
	}
end

-- ============================================================
-- NOTEFIELD MEAN DISPLAY (Dedicated Object)
-- ============================================================
local showMean = (ThemePrefs.Get("HV_ShowMean") == "true" or ThemePrefs.Get("HV_ShowMean") == true)
if showMean then
	t[#t + 1] = Def.ActorFrame {
		Name = "NotefieldMean",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + 70):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:linear(0.2):diffusealpha(0.8)
		end,

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.35):diffuse(mainText):settext("0.00ms")
			end,
			JudgmentMessageCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local dvt = pss:GetOffsetVector()
					if dvt and #dvt > 0 then
						self:settextf("%.2fms", wifeMean(dvt))
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0.00ms") end,
			PracticeModeReloadMessageCommand = function(self) self:queuecommand("Judgment") end
		}
	}
end

-- ============================================================
-- CENTERED COMBO / MISS STREAK (per-note update)
-- ============================================================
local missStreak = 0

t[#t + 1] = Def.ActorFrame {
	Name = "ComboDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 55)
	end,

	LoadFont("combo/_mochiy pop one 24px") .. {
		Name = "ComboNumber",
		InitCommand = function(self)
			self:zoom(0.65):diffuse(dimText):y(-4)
			self:settext("0")
		end
	},

	Def.ActorFrame {
		Name = "ComboLabel",
		InitCommand = function(self)
			self:y(16)
		end,

		-- Graphic for "Combo"
		Def.Sprite {
			Name = "ComboGraphic",
			Texture = THEME:GetPathG("", "combo_label.png"),
			InitCommand = function(self)
				self:zoom(0.25):diffuse(subText):visible(true)
			end
		},

		-- Text for "Misses" (fallback if no graphic, or for text-specific label)
		LoadFont("Common Normal") .. {
			Name = "MissesText",
			InitCommand = function(self)
				self:zoom(0.22):diffuse(color("#FF5050")):visible(false)
				self:settext(THEME:GetString("ScreenGameplay", "Misses"))
			end
		}
	},

	JudgmentMessageCommand = function(self, params)
		if params.TapNoteScore == "TapNoteScore_Miss" or params.TapNoteScore == "TapNoteScore_W5" then
			missStreak = missStreak + 1
		else
			missStreak = 0
		end
		
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if not pss then return end
		local combo = pss:GetCurrentCombo()
		if combo == 0 and missStreak >= 5 then
			local numActor = self:GetChild("ComboNumber")
			local labelContainer = self:GetChild("ComboLabel")
			local graphic = labelContainer:GetChild("ComboGraphic")
			local text = labelContainer:GetChild("MissesText")
			
			numActor:settext(tostring(missStreak)):diffuse(color("#FF5050"))
			graphic:visible(false)
			text:visible(true):settext(THEME:GetString("ScreenGameplay", "Misses"))
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
			numActor:settext(tostring(combo)):diffuse(brightText)
			graphic:visible(true):diffusealpha(1)
			text:visible(false)
		elseif missStreak < 5 then
			numActor:settext("0"):diffuse(dimText)
			graphic:visible(true):diffusealpha(0.5)
			text:visible(false)
		end
	end,
	PracticeModeResetMessageCommand = function(self)
		missStreak = 0
		local numActor = self:GetChild("ComboNumber")
		local labelContainer = self:GetChild("ComboLabel")
		numActor:settext("0"):diffuse(dimText)
		labelContainer:GetChild("ComboGraphic"):visible(true):diffusealpha(0.5)
		labelContainer:GetChild("MissesText"):visible(false)
	end,
	PracticeModeReloadMessageCommand = function(self) self:playcommand("PracticeModeReset") end
}

-- Practice CD Graph
t[#t + 1] = Def.ActorFrame {
	Name = "PracticeCDGraphContainer",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 80)
		self:visible(GAMESTATE:IsPracticeMode())
	end,
	LoadActor("../_chorddensitygraph.lua") .. {
		InitCommand = function(self)
			self:zoom(0.7)
		end
	}
}

-- AccuracyDisplay removed (redundant with pacemaker and NPS graph, overlapping with avatar)

-- ============================================================
-- ERROR BAR (TIMING BAR)
-- ============================================================
local ebW = 240
local ebH = 2
local ebCenterY = SCREEN_CENTER_Y + SCREEN_HEIGHT * 0.15 - 40
local maxOffset = 180 -- ms
local dotLife = 2.0  -- seconds

-- EWMA state
local ewmaValue = 0
local ewmaAlpha = 0.1
local showEWMA = (ThemePrefs.Get("HV_EWMAOffsetBar") == "true" or ThemePrefs.Get("HV_EWMAOffsetBar") == true)

t[#t + 1] = Def.ActorFrame {
	Name = "ErrorBar",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, ebCenterY):visible((ThemePrefs.Get("HV_ShowOffsetBar") == "true" or ThemePrefs.Get("HV_ShowOffsetBar") == true))
	end,

	-- Background line
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(ebW, ebH):visible(false)
		end
	},
	
	-- Early Indicator (Left)
	LoadFont("Common Normal") .. {
		Text = "EARLY",
		InitCommand = function(self)
			self:x(-ebW/2 - 5):y(-12):zoom(0.25):halign(0):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(0.5):linear(0.2):diffusealpha(0.6):sleep(1.2):linear(0.2):diffusealpha(0)
		end
	},
	-- Late Indicator (Right)
	LoadFont("Common Normal") .. {
		Text = "LATE",
		InitCommand = function(self)
			self:x(ebW/2 + 5):y(-12):zoom(0.25):halign(1):diffusealpha(0)
		end,
		OnCommand = function(self)
			self:sleep(0.5):linear(0.2):diffusealpha(0.6):sleep(1.2):linear(0.2):diffusealpha(0)
		end
	},

	-- EWMA Moving Average Marker
	Def.Quad {
		Name = "EWMAMarker",
		InitCommand = function(self)
			self:zoomto(2, ebH + 8):diffuse(accentColor):visible(showEWMA)
		end,
		UpdateEWMACommand = function(self, offset)
			ewmaValue = (1 - ewmaAlpha) * ewmaValue + ewmaAlpha * offset
			self:x((ewmaValue / maxOffset) * (ebW / 2))
		end
	},

	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if not params.TapNoteScore then return end
		if params.HoldNoteScore then return end -- Skip holds

		local offset = params.TapNoteOffset
		if not offset then return end

		-- Clamp for visualization
		local visualOffset = offset * 1000 -- to ms
		
		-- Update EWMA marker if enabled
		if showEWMA then
			self:GetChild("EWMAMarker"):playcommand("UpdateEWMA", visualOffset)
		end

		if math.abs(visualOffset) > maxOffset then return end

		local xPos = (visualOffset / maxOffset) * (ebW / 2)
		local jColor = offsetToJudgeColor(visualOffset)

		-- Pooling system: Cycle through child actors
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
-- COMPACT JUDGMENT TALLY + OK/NG + REAL-TIME GRADE
-- ============================================================
local tallyX = SCREEN_CENTER_X + 250
local tallyY = SCREEN_BOTTOM - 200

t[#t + 1] = Def.ActorFrame {
	Name = "JudgmentTally",
	InitCommand = function(self)
		self:xy(tallyX, tallyY):diffusealpha(0.8)
	end
}

for i, label in ipairs(judgmentLabels) do
	t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(tallyX, tallyY + (i - 1) * 16)
		end,

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoom(0.26):diffuse(judgmentColors[i]):diffusealpha(0.8)
				self:settext(label)
			end
		},

		LoadFont("Common Normal") .. {
			Name = "TallyCount_" .. label,
			InitCommand = function(self)
				self:halign(1):valign(0):x(60):zoom(0.26):diffuse(mainText):diffusealpha(0.8)
				self:settext("0")
			end,
			JudgmentMessageCommand = function(self)
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

-- OK / NG counters (below judgment tally)
local okngY = tallyY + #judgmentLabels * 16 + 4

t[#t + 1] = Def.ActorFrame {
	Name = "OKNGDisplay",
	InitCommand = function(self)
		self:xy(tallyX, okngY)
	end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.26):diffuse(color("#A0E0A0")):diffusealpha(0.8)
			self:settext(THEME:GetString("HoldNoteScore", "OK"))
		end
	},
	LoadFont("Common Normal") .. {
		Name = "OKCount",
		InitCommand = function(self)
			self:halign(1):valign(0):x(60):zoom(0.26):diffuse(mainText):diffusealpha(0.8)
			self:settext("0")
		end,
		JudgmentMessageCommand = function(self)
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
			self:halign(0):valign(0):y(16):zoom(0.26):diffuse(color("#E0A0A0")):diffusealpha(0.8)
			self:settext(THEME:GetString("HoldNoteScore", "NG"))
		end
	},
	LoadFont("Common Normal") .. {
		Name = "NGCount",
		InitCommand = function(self)
			self:halign(1):valign(0):x(60):y(16):zoom(0.26):diffuse(mainText):diffusealpha(0.8)
			self:settext("0")
		end,
		JudgmentMessageCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local ng = pss:GetHoldNoteScores("HoldNoteScore_LetGo")
				self:settext(tostring(ng))
			end
		end,
		PracticeModeResetMessageCommand = function(self) self:settext("0") end,
		PracticeModeReloadMessageCommand = function(self) self:settext("0") end
	},
	PracticeModeResetMessageCommand = function(self) self:playcommand("Init") end
}

-- Real-time Grade Display has been moved to the pacemaker panel.


-- ============================================================
-- JUDGE RESCORING & MEAN/SD
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "RescoreStats",
	InitCommand = function(self)
		self:xy(tallyX, okngY + 40)
	end,

	-- Rescored % (J4)
	LoadFont("Common Normal") .. {
		Name = "RescoreLabel",
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.26):diffuse(dimText)
			self:settext("J4")
		end
	},
	LoadFont("Common Normal") .. {
		Name = "RescoreValue",
		InitCommand = function(self)
			self:halign(1):valign(0):x(60):zoom(0.26):diffuse(subText)
			self:settext("0.00%")
		end,
		JudgmentMessageCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local rs = getRescoreElements(pss, pss) -- Use pss as proxy for score
				local j4 = getRescoredWife3Judge(1, 4, rs)
				self:settext(string.format("%.2f%%", j4))
			end
		end,
		PracticeModeResetMessageCommand = function(self) self:settext("0.00%") end,
		PracticeModeReloadMessageCommand = function(self) self:settext("0.00%") end
	},

	-- Mean / SD / Largest
	LoadFont("Common Normal") .. {
		Name = "MeanSDLabel",
		InitCommand = function(self)
			self:halign(0):valign(0):y(16):zoom(0.26):diffuse(dimText)
			self:settext("SD / Largest")
		end
	},
	LoadFont("Common Normal") .. {
		Name = "MeanSDValue",
		InitCommand = function(self)
			self:halign(1):valign(0):x(60):y(16):zoom(0.24):diffuse(subText)
			self:settext("0.0 / 0.0")
		end,
		JudgmentMessageCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local dvt = pss:GetOffsetVector()
				if dvt and #dvt > 0 then
					local sd = wifeSd(dvt)
					local max = wifeMax(dvt)
					self:settext(string.format("%.1f / %.1f", sd, max))
				end
			end
		end,
		PracticeModeResetMessageCommand = function(self) self:settext("0.0 / 0.0") end,
		PracticeModeReloadMessageCommand = function(self) self:settext("0.0 / 0.0") end
	}
}

-- ============================================================
-- SONG TITLE (BOTTOM of screen)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "SongInfoHUD",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 14)
	end,
	OnCommand = function(self)
		self:diffusealpha(0.6)
	end,
	
	-- BPM and Rate display added above song title
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(-18):zoom(0.35):diffuse(subText):maxwidth(SCREEN_WIDTH / 0.35)
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
	},

	LoadFont("Zpix Normal") .. {
		InitCommand = function(self)
			self:zoom(0.35):diffuse(mainText):maxwidth(SCREEN_WIDTH * 0.5 / 0.35)
		end,
		BeginCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:settext(song:GetDisplayMainTitle())
			end
		end
	}
}

-- ============================================================
-- TOASTY (fires at combo 250, 500, 750, 1000, ...)
-- ============================================================
local lastToastyCombo = 0

local function safeGetThemePath(type, folder, element)
	local possiblePaths = {
		"Themes/Holographic Void/" .. folder .. "/" .. element,
		"Themes/_fallback/" .. folder .. "/" .. element
	}
	for _, p in ipairs(possiblePaths) do
		local extensions = type == "G" and {".png", ".jpg", ".jpeg", ".gif", ".webm"} or {".ogg", ".wav", ".mp3"}
		for _, ext in ipairs(extensions) do
			if FILEMAN:DoesFileExist(p .. ext) then
				return p .. ext
			end
		end
	end
	return nil
end

local toastyImgPath = safeGetThemePath("G", "Graphics", "toasty") or safeGetThemePath("G", "Graphics", "Common toasty")
local toastySndPath = safeGetThemePath("S", "Sounds", "toasty") or safeGetThemePath("S", "Sounds", "Common toasty")

t[#t + 1] = Def.ActorFrame {
	Name = "Toasty",
	InitCommand = function(self)
		lastToastyCombo = 0
	end,

	Def.Sprite {
		Name = "ToastySprite",
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH + 100, SCREEN_CENTER_Y):diffusealpha(0)
			if toastyImgPath then
				self:Load(toastyImgPath)
			end
		end,
		StartTransitioningCommand = function(self)
			if not toastyImgPath then return end
			self:stoptweening()
			self:diffusealpha(1)
			self:decelerate(0.25):x(SCREEN_WIDTH - 100)
			self:sleep(1.75)
			self:accelerate(0.5):x(SCREEN_WIDTH + 100)
			self:linear(0):diffusealpha(0)
		end
	},

	Def.Sound {
		Name = "ToastySound",
		InitCommand = function(self)
			if toastySndPath then
				self:load(toastySndPath)
			end
		end,
		StartTransitioningCommand = function(self)
			if toastySndPath then self:play() end
		end
	},

	JudgmentMessageCommand = function(self)
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if pss then
			local combo = pss:GetCurrentCombo()
			if combo and combo >= 250 then
				local milestone = math.floor(combo / 250)
				local lastMilestone = math.floor(lastToastyCombo / 250)
				if milestone > lastMilestone then
					self:playcommand("StartTransitioning")
				end
			end
			if combo then
				lastToastyCombo = combo
			end
		end
	end
}

-- ============================================================
-- LANE COVER
-- ============================================================
local laneCoverPct = tonumber(ThemePrefs.Get("HV_LaneCover")) or 0
if laneCoverPct > 0 then
	t[#t + 1] = Def.ActorFrame {
		Name = "LaneCoverLayer",
		InitCommand = function(self)
			self:Center()
		end,

		-- Top Cover (Sudden)
		Def.Quad {
			InitCommand = function(self)
				local h = SCREEN_HEIGHT * (laneCoverPct / 100)
				self:valign(0):y(-SCREEN_HEIGHT / 2)
					:zoomto(SCREEN_WIDTH, h)
					:diffuse(color("0,0,0,1"))
			end
		}
	}
end

t[#t + 1] = LoadActor("scoretracking")
t[#t + 1] = LoadActor("pacemaker")
t[#t + 1] = LoadActor("npscalc")
t[#t + 1] = LoadActor("avatar")
t[#t + 1] = LoadActor("intro")

return t
