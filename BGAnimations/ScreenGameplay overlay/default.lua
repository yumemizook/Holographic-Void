local pn = GAMESTATE:GetEnabledPlayers()[1] or PLAYER_1
local lScreen = Var "LoadingScreen" or ""
local isSync = lScreen:find("Sync") ~= nil

local t = Def.ActorFrame {
	Name = "GameplayOverlay",
	BeginCommand = function(self)
		-- Re-check sync mode via SCREENMAN now that it's safer
		local curScreen = SCREENMAN:GetTopScreen()
		if curScreen and curScreen:GetName():find("Sync") then
			isSync = true
		end
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

			-- Sync Mode overrides
			if isSync then
				po:CMod(400)
				po:Reverse(0) -- Upscroll
				-- Apply to Current level as well
				local co = ps:GetPlayerOptions("ModsLevel_Current")
				co:CMod(400)
				co:Reverse(0)
			end
		end
		
		HV.LastGameplayTime = os.time()
		HV.GameplaySessionValid = true
	end,
	OnCommand = function(self)
		-- Double check mods on OnCommand just in case
		if isSync then
			for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
				local ps = GAMESTATE:GetPlayerState(pn)
				ps:GetPlayerOptions("ModsLevel_Current"):CMod(400)
				ps:GetPlayerOptions("ModsLevel_Current"):Reverse(0)
			end
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
			-- Lifebar still uses this for now
			MESSAGEMAN:Broadcast("PlayingUpdate")
		end)
	end,

	-- NoteMask for Sync Mode (placed here to be below judgments/combo)
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
	-- Interactive Seek (Practice Mode Only)
	Def.Quad {
		Name = "MouseHitbox",
		InitCommand = function(self)
			self:zoomto(barW + 20, barH + 20):diffusealpha(0)
		end,
		UpdateBarsCommand = function(self)
			if not GAMESTATE:IsPracticeMode() then return end
			
			-- Direct polling for smoother dragging and bypass input callback issues
			if INPUTFILTER:IsBeingPressed("left mouse button") and isOver(self) then
				local song = GAMESTATE:GetCurrentSong()
				if song then
					local mx = INPUTFILTER:GetMouseX()
					-- Use IsOver's absolute coordinates or calculate manually
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

	-- Loop Markers
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

	}
}
end -- End progress bar visibility check

-- ============================================================
-- VERTICAL LIFE BAR (right edge) with % counter
-- ============================================================
local lifeBarW = 8
local lifeBarH = SCREEN_HEIGHT * 0.5
local lifeBarX = SCREEN_CENTER_X + 220
local lifeBarY = SCREEN_CENTER_Y

if not HV.MinimalisticMode() and not isSync then
t[#t + 1] = Def.ActorFrame {
	Name = "VerticalLifeBar",
	InitCommand = function(self)
		self:xy(lifeBarX, lifeBarY):visible(false)
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

				-- Coloring based on Life Difficulty (consistent with avatar.lua)
				local diff = GetLifeDifficulty()
				if diff <= 2 then
					self:diffuse(color("#A0CFAB")) -- Green
				elseif diff <= 4 then
					self:diffuse(color("#5ABAFF")) -- Cyan/Blue
				elseif diff == 5 then
					self:diffuse(color("#CFD198")) -- Yellow
				elseif diff == 6 then
					self:diffuse(color("#E0B080")) -- Orange
				else
					self:diffuse(color("#CF9898")) -- Red
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

	-- Life % counter
	LoadFont("Common Normal") .. {
		Name = "LifePct",
		InitCommand = function(self)
			self:y(-lifeBarH / 2 - 10):zoom(0.25):diffuse(subText)
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
		end,

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
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 90):diffusealpha(0.8)
	end,

	LoadFont("Common Normal") .. {
		Name = "ScoreValue",
		InitCommand = function(self)
			self:zoom(0.45):diffuse(brightText):diffusealpha(0.7)
			self:settext("0.0000%")
		end,
		JudgmentMessageCommand = function(self, params)
			self.params = params
			self:queuecommand("Update")
		end,
		UpdateCommand = function(self)
			local params = self.params
			if not params then return end
			local wifePct
			if params and params.WifePercent then
				wifePct = params.WifePercent
			else
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local totalTaps = pss:GetTotalTaps()
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
				self.msg = msg
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local msg = self.msg
				if not msg then return end
				local tDiff = msg.WifeDifferential
				local displayTarget = targetGoalPct

				-- In PB or PB Replay mode, use the PB goal/differential if available
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
			end,

		}
	}
end

-- ============================================================
-- NOTEFIELD MEAN DISPLAY
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "NotefieldMean",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + 70):diffusealpha(0)
		-- Check if hit mean should be shown
		local showMean = HV.ShowHitMean() and not HV.MinimalisticMode() and not isSync
		self:visible(showMean)
	end,
	OnCommand = function(self)
		self:linear(0.2):diffusealpha(0.8)
	end,

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:zoom(0.35):diffuse(mainText):settext("0.00ms")
			end,
			JudgmentMessageCommand = function(self)
				self:queuecommand("Update")
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local dvt = pss:GetOffsetVector()
					if dvt and #dvt > 0 then
						self:settextf("%.2fms", wifeMean(dvt))
					end
				end
			end,
		
		}
	}

-- ============================================================
-- CENTERED COMBO / MISS COMBO
-- ============================================================
local showCombo = HV.ShowCombo() and not HV.MinimalisticMode()
local missStreak = 0

if showCombo then
t[#t + 1] = Def.ActorFrame {
	Name = "ComboDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 55)
	end,

	LoadFont("combo/_mochiy pop one 24px") .. {
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
		self.params = params
		self:queuecommand("Update")
	end,
	UpdateCommand = function(self)
		local params = self.params
		if not params then return end
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
			local totalNotes = getMaxNotes(PLAYER_1) or 1
			local threshold = math.floor(totalNotes * 0.25)
			local ct = getDetailedClearType(pss)
			local ctColor = getClearTypeColor(ct)
			
			numActor:settext(tostring(combo)):diffuse(brightText)
			
			-- Shadow display logic: 25% threshold + No combo breaks (FC status so far)
			local isFC = (ct ~= "MF" and ct ~= "SDCB" and ct ~= "Clear" and ct ~= "Failed")
			
			if combo >= threshold and isFC then
				numActor:shadowcolor(ctColor)
				numActor:shadowlength(1.5) -- Improved visibility
			else
				numActor:shadowlength(0)
			end
			
			graphic:visible(true):diffusealpha(1)
			text:visible(false)
		elseif missStreak < 5 then
			numActor:settext("0"):diffuse(dimText):shadowlength(0)
			graphic:visible(true):diffusealpha(0.5)
			text:visible(false)
		end
	end,

}
end -- End combo visibility check

-- ============================================================
-- COMBO BREAK LANE HIGHLIGHT
-- ============================================================
local showComboBreakHighlight = HV.ComboBreakHighlight() and not HV.MinimalisticMode() and not isSync

if showComboBreakHighlight then

-- Helper: build a gradient AMV lane quad.
-- xOffset: lane center X (relative to parent ActorFrame at SCREEN_CENTER)
-- laneW: lane pixel width
-- The quad spans from y=0 (screen center, top of highlight, transparent)
--   to y=SCREEN_HEIGHT/2 (receptor area, bottom, opaque at flash time).
-- Vertices are ordered: TL, TR, BR, BL (quad strip).
local function makeCBLane(name, xOffset, laneW)
	local halfW   = laneW / 2
	-- The parent frame sits at SCREEN_CENTER_Y.
	-- Receptors are near SCREEN_BOTTOM, so the opaque end of the gradient
	-- is SCREEN_HEIGHT/2 pixels below the frame origin (positive Y = down).
	-- 80% height means topY = (bottomY) - (0.8 * SCREEN_HEIGHT) = -0.3 * SCREEN_HEIGHT
	local topY    = -SCREEN_HEIGHT * 0.3 -- 80% height highlight
	local bottomY = SCREEN_HEIGHT / 2    -- receptor area       → opaque at flash peak

	return Def.ActorMultiVertex {
		Name = name,
		InitCommand = function(self)
			self:x(xOffset)
			-- Pre-set vertices with the desired gradient (peak alpha handled in FlashCommand)
			self:SetVertices({
				{{-halfW, topY,    0}, {1, 1, 1, 0}}, -- TL
				{{ halfW, topY,    0}, {1, 1, 1, 0}}, -- TR
				{{ halfW, bottomY, 0}, {1, 1, 1, 1}}, -- BR
				{{-halfW, bottomY, 0}, {1, 1, 1, 1}}, -- BL
			})
			self:SetDrawState({Mode="DrawMode_Quads", First=1, Num=4})
			self:diffusealpha(0)
		end,
		FlashCommand = function(self, params)
			local c = params and params.color or color("#FF5050")
			self:stoptweening()
			self:diffuse(c)
			
			-- Instant snap to a clearer peak (0.35) and a single linear fade-out.
			-- This avoids the "snapping to dim" feeling of the dual-ramp approach.
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

	-- 4 gradient lane highlights for standard 4K (64px wide, spaced 64px apart)
	makeCBLane("Lane1", -96, 64),
	makeCBLane("Lane2", -32, 64),
	makeCBLane("Lane3",  32, 64),
	makeCBLane("Lane4",  96, 64),

	JudgmentMessageCommand = function(self, params)
		if params.Player ~= PLAYER_1 then return end
		if not params.TapNoteScore then return end

		-- Flash on combo-breaking judgments
		local isComboBreak = (params.TapNoteScore == "TapNoteScore_Miss" or
							  params.TapNoteScore == "TapNoteScore_W5" or
							  params.TapNoteScore == "TapNoteScore_W4")

		if isComboBreak and params.Notes then
			local jColor = color("#FF5050")
			if params.TapNoteScore == "TapNoteScore_W4" then jColor = judgmentColors[4]
			elseif params.TapNoteScore == "TapNoteScore_W5" then jColor = judgmentColors[5]
			elseif params.TapNoteScore == "TapNoteScore_Miss" then jColor = judgmentColors[6] end

			-- Flash lanes that had notes in this judgment
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
		-- Only show CDG if it's not a Sync screen AND Practice Mode is ON
		self:visible(not isSync and GAMESTATE:IsPracticeMode())
	end,
	LoadActor("../_chorddensitygraph.lua") .. {
		InitCommand = function(self)
			self:zoom(0.8) -- Slightly larger
		end
	}
}


t[#t + 1] = LoadActor("replayscrolling.lua")

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
local ewmaAlpha = 0.07
local ebMode = ThemePrefs.Get("HV_ErrorBarMode") or "Standard"
local showEWMA = (ebMode == "EWMAOnly" or ebMode == "Both")
local showStandard = (ebMode == "Standard" or ebMode == "Both")

	t[#t + 1] = Def.ActorFrame {
		Name = "ErrorBar",
		InitCommand = function(self)
			local ebMode = ThemePrefs.Get("HV_ErrorBarMode") or "Standard"
			self:xy(SCREEN_CENTER_X, ebCenterY):visible(ebMode ~= "Off" and not isSync)
		end,

	-- Background line
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(ebW, ebH):visible(false)
		end
	},

	-- Center Line (0ms)
	Def.Quad {
		Name = "CenterLine",
		InitCommand = function(self)
			self:zoomto(1, ebH + 8):diffuse(color("1,1,1,0.3"))
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

	Def.Quad {
		Name = "EWMAMarker",
		InitCommand = function(self)
			self:zoomto(2, ebH + 8):diffuse(accentColor):visible(showEWMA)
		end,
		UpdateEWMACommand = function(self, params)
			local offset = params.offset
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

		-- Exclude misses from EWMA
		if params.TapNoteScore == "TapNoteScore_Miss" then return end

		-- Clamp for visualization
		local visualOffset = offset * 1000 -- to ms
		
		-- Update EWMA marker if enabled
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
-- TWO-COLUMN JUDGMENT TALLY + PERFORMANCE METRICS
-- ============================================================
local colSpacing = 70
local showJudgeCounter = HV.ShowJudgeCounter()
local tallyX = SCREEN_CENTER_X + 160
local tallyY = SCREEN_HEIGHT - 176

if showJudgeCounter and not HV.MinimalisticMode() and not isSync then
t[#t + 1] = Def.ActorFrame {
	Name = "TallyAndMetrics",
	InitCommand = function(self)
		self:xy(tallyX, tallyY):diffusealpha(0.8)
	end,

	-- COLUMN 1: Judgments + OK/NG
	Def.ActorFrame {
		Name = "Column1_Judgments",
		
		-- Loop through standard judgments (W1-Miss)
		(function()
			local g = Def.ActorFrame{}
			for i, label in ipairs(judgmentLabels) do
				g[#g+1] = Def.ActorFrame {
					InitCommand = function(self)
						self:y((i - 1) * 16)
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

		-- OK / NG counters
		Def.ActorFrame {
			Name = "OKNGDisplay",
			InitCommand = function(self)
				self:y(#judgmentLabels * 16 + 4)
			end,

			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:halign(0):valign(0):zoom(0.34):diffuse(HVColor.GetJudgmentColor("Held")):diffusealpha(0.8)
					self:settext(THEME:GetString("HoldNoteScore", "OK"))
				end
			},
			LoadFont("Common Normal") .. {
				Name = "OKCount",
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
						local ok = pss:GetHoldNoteScores("HoldNoteScore_Held")
						self:settext(tostring(ok))
					end
				end,
				PracticeModeResetMessageCommand = function(self) self:settext("0") end,
				PracticeModeReloadMessageCommand = function(self) self:settext("0") end
			},

			LoadFont("Common Normal") .. {
				InitCommand = function(self)
					self:halign(0):valign(0):y(16):zoom(0.34):diffuse(HVColor.GetJudgmentColor("LetGo")):diffusealpha(0.8)
					self:settext(THEME:GetString("HoldNoteScore", "NG"))
				end
			},
			LoadFont("Common Normal") .. {
				Name = "NGCount",
				InitCommand = function(self)
					self:halign(1):valign(0):x(60):y(16):zoom(0.34):diffuse(mainText):diffusealpha(0.8)
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

	-- COLUMN 2: Performance Metrics (aligned to the right of Column 1)
	Def.ActorFrame {
		Name = "Column2_Metrics",
		InitCommand = function(self)
			self:x(colSpacing)
			-- Hide metrics in Simple mode
			if HV.GetJudgmentTallyMode() == "Simple" then
				self:visible(false)
			end
		end,

		-- Rescored % (J4)
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
				-- Only process tap-related judgments.
				if msg.TapNoteScore and msg.TapNoteScore ~= "TapNoteScore_AvoidMine" and msg.TapNoteScore ~= "TapNoteScore_CheckpointHit" then
					local ts = ms.JudgeScalers[4] or 1.0 -- J4 rescaling always uses J4 (Index 4)
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

		-- MA Ratio (W1/W2)
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
					local ratio = 0
					if w2 > 0 then
						ratio = w1 / w2
						self:settext(string.format("%.2f:1", ratio))
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

		-- PA Ratio (W2/W3)
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
					local ratio = 0
					if w3 > 0 then
						ratio = w2 / w3
						self:settext(string.format("%.2f:1", ratio))
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

		-- Longest Combo
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

		-- Std Dev
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
						local sd = wifeSd(dvt)
						self:settext(string.format("%.2f", sd))
					end
				end
			end,
			PracticeModeResetMessageCommand = function(self) self:settext("0.00") end,
			PracticeModeReloadMessageCommand = function(self) self:settext("0.00") end
		},

		-- Largest Offset
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
						local max = wifeMax(dvt)
						self:settext(string.format("%.2f", max))
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
-- SONG TITLE (BOTTOM of screen)
-- ============================================================
if not HV.MinimalisticMode() and not isSync then
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
end

-- ============================================================
-- TOASTY (fires at combo 250, 500, 750, 1000, ...)
-- technically it should be every 250 perfect combo but eh
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

if not isSync then
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
end

-- ============================================================
-- LANE COVER
-- ============================================================
local suddenHeight = HV.GetLaneCoverSudden()
local hiddenHeight = HV.GetLaneCoverHidden()

if suddenHeight > 0 or hiddenHeight > 0 then
	local isReverse = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions():UsingReverse()
	
	-- Helper to create a cover quad (isTop=true for Top, false for Bottom)
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

	-- Sudden: spawn side (Top for Standard, Bottom for Reverse)
	if suddenHeight > 0 then
		t_cover[#t_cover + 1] = createCover(suddenHeight, not isReverse)
	end

	-- Hidden: receptor side (Bottom for Standard, Top for Reverse)
	if hiddenHeight > 0 then
		t_cover[#t_cover + 1] = createCover(hiddenHeight, isReverse)
	end
	
	t[#t + 1] = t_cover
end

if not isSync then
	t[#t + 1] = LoadActor("scoretracking")
	t[#t + 1] = LoadActor("pacemaker")
	t[#t + 1] = LoadActor("npscalc")
	t[#t + 1] = LoadActor("multiplayer")
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
-- FC and above: rise-up text with color animation at chart end
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
	-- Create a pool of 24 rays (max intensity)
	for i = 1, 24 do
		burst[#burst+1] = Def.Quad{
			InitCommand = function(self)
				self:zoomto(2, 200):diffusealpha(0)
			end,
			BurstCommand = function(self, params)
				self:stoptweening():diffusealpha(0):zoomto(2, 0)
				-- Distribute rays evenly based on the current active count
				self:rotationz((params.index - 1) * (360 / params.numRays))
				
				-- Start white (or red flash for heartbreaks) then transition to clear type color
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
			self:diffusealpha(0):y(30)  -- start below center
		end,
		OffCommand = function(self)
			if isSync then return end
			
			-- Delay slightly to ensure statistics are stabilized
			self:sleep(0.05)
			
			local epn = pn or GAMESTATE:GetEnabledPlayers()[1] or PLAYER_1
			local epss = STATSMAN:GetCurStageStats():GetPlayerStageStats(epn)
			if not epss then return end
			local steps = GAMESTATE:GetCurrentSteps()
			if not steps then return end
			
			local clearLevel = getClearLevel(epn, steps, epss)

			-- Fallback: if getClearLevel failed but it's a Full Combo
			if clearLevel > 7 and epss:FullComboOfScore("TapNoteScore_W3") then
				clearLevel = 7 -- Regular FC
			end

			-- MFC=1 ... FC=7
			if clearLevel <= 7 then
				local ctName = getClearType(epn, steps, epss)
				if clearLevel == 7 and (not ctName or ctName == "") then ctName = "FC" end
				
				local ctText = getClearTypeText(ctName)
				local ctColor = getClearTypeColor(ctName)

				-- Intensity settings: rays and speed
				local numRays = 10
				local burstSpeed = 0.6
				local isHeartbreak = false
				
				if clearLevel == 1 then -- MFC
					numRays = 24
					burstSpeed = 0.4
				elseif clearLevel == 2 then -- WF (Heartbreak)
					numRays = 20
					burstSpeed = 0.45
					isHeartbreak = true
				elseif clearLevel <= 4 then -- PFC variants
					numRays = 16
					burstSpeed = 0.5
				elseif clearLevel == 5 then -- BF (Heartbreak)
					numRays = 14
					burstSpeed = 0.55
					isHeartbreak = true
				end

				local txt = self:GetChild("CTText")
				txt:stoptweening():settext(ctText)
				
				-- Intense red flash for heartbreaks
				if isHeartbreak then
					txt:diffuse(color("#FF0000"))
				else
					txt:diffuse(color("#FFFFFF"))
				end

				-- Trigger dynamic burst
				self:GetParent():RunCommandsOnChildren(function(c) 
					c:playcommand("Celebration", {
						numRays = numRays, 
						speed = burstSpeed, 
						color = ctColor, 
						isHeartbreak = isHeartbreak
					})
				end)

				-- Rise-up animation: from y=30 to y=0
				self:stoptweening()
				self:y(30):diffusealpha(0):zoom(1.5)
				self:decelerate(0.5):y(0):diffusealpha(1):zoom(1)

				-- Special Heartbreak Shake/Pulse
				if clearLevel == 2 then -- WF: Jitter shake
					for i=1, 4 do
						self:sleep(0.02):x(-3):sleep(0.02):x(3)
					end
					self:sleep(0.02):x(0)
				elseif clearLevel == 5 then -- BF: Vertical thump/pulse
					self:bounce(0.2):effectmagnitude(0, -6, 0):effectclock("bgm"):effectperiod(0.1)
					self:sleep(0.4):stopeffect()
				end

				-- Color sweep: stay red/white then transition to clear type color
				if isHeartbreak then
					txt:sleep(0.4):linear(0.2):diffuse(color("#FFFFFF")):linear(0.5):diffuse(ctColor)
				else
					txt:sleep(0.3):linear(0.5):diffuse(ctColor)
				end
				
				-- Gentle pulse
				txt:sleep(0.2):linear(0.4):diffusealpha(0.8):linear(0.4):diffusealpha(1)

				-- Hold then fade out before the evaluation screen takes over
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



return t
