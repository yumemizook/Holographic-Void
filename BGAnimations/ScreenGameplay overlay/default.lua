--- Holographic Void: ScreenGameplay Overlay
-- Overhauled HUD:
--   - Clean vertical life bar with % counter (per-note update)
--   - Per-note score%, combo, and 4-digit accuracy tracker
--   - Progress bar at TOP, song title at BOTTOM
--   - Compact judgment tally with OK/NG and real-time grade
--   - Centered combo (no duplicate judgment display, no animations)
--   - Toasty animation preserved

local t = Def.ActorFrame {
	Name = "GameplayOverlay"
}

local accentColor = color("#5ABAFF")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")

local judgmentColors = {
	color("#FFFFFF"), color("#E0E0A0"), color("#A0E0A0"),
	color("#A0C8E0"), color("#C8A0E0"), color("#E0A0A0")
}
local judgmentLabels = {"W1", "W2", "W3", "W4", "W5", "Miss"}
local judgmentTNS = {
	"TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3",
	"TapNoteScore_W4", "TapNoteScore_W5", "TapNoteScore_Miss"
}

-- ============================================================
-- FRAME UPDATER (for time-based elements: life bar, progress bar)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(function(s)
			s:GetParent():playcommand("Update")
		end)
		self:SetUpdateRate(1 / 30)
	end
}

-- ============================================================
-- SONG PROGRESS BAR (TOP of screen)
-- ============================================================
local barW = SCREEN_WIDTH * 0.4
local barH = 3
local barY = 10

t[#t + 1] = Def.ActorFrame {
	Name = "ProgressBar",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, barY)
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
		UpdateCommand = function(self)
			local songPos = GAMESTATE:GetSongPercent()
			if songPos then
				self:zoomto(barW * songPos, barH)
			end
		end
	},

	LoadFont("Common Normal") .. {
		Name = "TimeRemaining",
		InitCommand = function(self)
			self:x(barW / 2 + 8):zoom(0.25):halign(0):diffuse(dimText)
		end,
		UpdateCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local songLen = song:MusicLengthSeconds()
				local curTime = GAMESTATE:GetSongPosition():GetMusicSeconds()
				local remaining = math.max(0, songLen - curTime)
				local mins = math.floor(remaining / 60)
				local secs = math.floor(remaining % 60)
				self:settext(string.format("-%d:%02d", mins, secs))
			end
		end
	},

	-- Difficulty / MSD / Rate (left of progress bar)
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-barW / 2 - 8):zoom(0.25):halign(1):diffuse(subText)
		end,
		BeginCommand = function(self)
			local steps = GAMESTATE:GetCurrentSteps()
			if steps then
				local diff = ToEnumShortString(steps:GetDifficulty())
				local msd = steps:GetMSD(getCurRateValue(), 1)
				local rate = getCurRateString()
				local txt = diff
				if msd and msd > 0 then txt = txt .. " " .. string.format("%.2f", msd) end
				if rate and rate ~= "1x" and rate ~= "1.0x" then txt = txt .. " " .. rate end
				self:settext(txt)
			end
		end
	}
}

-- ============================================================
-- VERTICAL LIFE BAR (right edge) with % counter
-- ============================================================
local lifeBarW = 8
local lifeBarH = SCREEN_HEIGHT * 0.5
local lifeBarX = SCREEN_RIGHT - 16
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
		UpdateCommand = function(self)
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
		UpdateCommand = function(self)
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
		end
	}
}

-- ============================================================
-- CENTERED COMBO DISPLAY (per-note update, no animation)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "ComboDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + SCREEN_HEIGHT * 0.22)
		self:visible(false)
	end,

	LoadFont("Common Large") .. {
		Name = "ComboNumber",
		InitCommand = function(self)
			self:zoom(0.65):diffuse(brightText):y(-4)
		end
	},

	LoadFont("Common Normal") .. {
		Name = "ComboLabel",
		InitCommand = function(self)
			self:zoom(0.22):diffuse(subText):y(14)
			self:settext("COMBO")
		end
	},

	JudgmentMessageCommand = function(self)
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if pss then
			local combo = pss:GetCurrentCombo()
			if combo and combo > 0 then
				self:visible(true)
				self:GetChild("ComboNumber"):settext(tostring(combo))
			else
				self:visible(false)
			end
		end
	end
}

-- ============================================================
-- REAL-TIME ACCURACY / SCORE% (per-note, 4-digit precision)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "AccuracyDisplay",
	InitCommand = function(self)
		self:xy(12, SCREEN_BOTTOM - 50)
	end,

	LoadFont("Common Normal") .. {
		Name = "ScorePercent",
		InitCommand = function(self)
			self:halign(0):valign(1):zoom(0.6):diffuse(brightText)
			self:settext("0.0000%")
		end,
		JudgmentMessageCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local wifePct = pss:GetWifeScore() * 100
				self:settext(string.format("%.4f%%", wifePct))
			end
		end
	},

	-- Player name
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(1):y(-20):zoom(0.28):diffuse(dimText)
		end,
		BeginCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local name = profile:GetDisplayName()
				if name == "" then name = "Player" end
				self:settext(name)
			end
		end
	}
}

-- ============================================================
-- COMPACT JUDGMENT TALLY + OK/NG + REAL-TIME GRADE
-- ============================================================
local tallyX = SCREEN_RIGHT - 160
local tallyY = SCREEN_CENTER_Y - 80

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
				self:halign(0):valign(0):zoom(0.22):diffuse(judgmentColors[i]):diffusealpha(0.8)
				self:settext(label)
			end
		},

		LoadFont("Common Normal") .. {
			Name = "TallyCount_" .. label,
			InitCommand = function(self)
				self:halign(1):valign(0):x(100):zoom(0.26):diffuse(mainText):diffusealpha(0.8)
				self:settext("0")
			end,
			JudgmentMessageCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					self:settext(pss:GetTapNoteScores(judgmentTNS[i]))
				end
			end
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
			self:halign(0):valign(0):zoom(0.22):diffuse(color("#A0E0A0")):diffusealpha(0.8)
			self:settext("OK")
		end
	},
	LoadFont("Common Normal") .. {
		Name = "OKCount",
		InitCommand = function(self)
			self:halign(1):valign(0):x(100):zoom(0.26):diffuse(mainText):diffusealpha(0.8)
			self:settext("0")
		end,
		JudgmentMessageCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local ok = pss:GetHoldNoteScores("HoldNoteScore_Held")
				self:settext(tostring(ok))
			end
		end
	},

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):y(16):zoom(0.22):diffuse(color("#E0A0A0")):diffusealpha(0.8)
			self:settext("NG")
		end
	},
	LoadFont("Common Normal") .. {
		Name = "NGCount",
		InitCommand = function(self)
			self:halign(1):valign(0):x(100):y(16):zoom(0.26):diffuse(mainText):diffusealpha(0.8)
			self:settext("0")
		end,
		JudgmentMessageCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local ng = pss:GetHoldNoteScores("HoldNoteScore_LetGo")
				self:settext(tostring(ng))
			end
		end
	}
}

-- Real-time Grade Display (below OK/NG)
t[#t + 1] = Def.ActorFrame {
	Name = "RealtimeGrade",
	InitCommand = function(self)
		self:xy(tallyX, okngY + 40)
	end,

	LoadFont("Common Normal") .. {
		Name = "GradeLabel",
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.22):diffuse(dimText)
			self:settext("GRADE")
		end
	},

	LoadFont("Common Normal") .. {
		Name = "GradeValue",
		InitCommand = function(self)
			self:halign(1):valign(0):x(100):zoom(0.4):diffuse(brightText)
		end,
		JudgmentMessageCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local grade = pss:GetGrade()
				local gradeStr = ToEnumShortString(grade)
				self:settext(gradeStr)
				self:diffuse(HVColor.GetGradeColor(gradeStr))
			end
		end
	}
}

-- ============================================================
-- SONG TITLE (BOTTOM of screen)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "SongInfoHUD",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 10)
	end,
	OnCommand = function(self)
		self:diffusealpha(0.5)
	end,

	LoadFont("Zpix Normal") .. {
		InitCommand = function(self)
			self:zoom(0.3):diffuse(mainText):maxwidth(SCREEN_WIDTH * 0.5 / 0.3)
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

local toastyImgPath = (function()
	local candidates = {
		THEME:GetPathG("", "toasty"),
		THEME:GetPathG("Common", "toasty"),
	}
	for _, p in ipairs(candidates) do
		if p and p ~= "" and FILEMAN:DoesFileExist(p) then return p end
	end
	return nil
end)()

local toastySndPath = (function()
	local candidates = {
		THEME:GetPathS("", "toasty"),
		THEME:GetPathS("Common", "toasty"),
	}
	for _, p in ipairs(candidates) do
		if p and p ~= "" and FILEMAN:DoesFileExist(p) then return p end
	end
	return nil
end)()

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

return t
