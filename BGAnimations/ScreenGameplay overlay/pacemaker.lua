-- Holographic Void: Pacemaker (adapted from Fatigue)
-- Visual score meter comparing current score against personal best and a target goal.
-- Includes a real-time grade display, colored by HVColor.

local pn = GAMESTATE:GetEnabledPlayers()[1]
local baseline = SCREEN_HEIGHT * 0.385
local meterheight = SCREEN_HEIGHT * 0.725
local panelWidth = SCREEN_HEIGHT * 0.22
local panelPos = 1 -- 1 = right, -1 = left
local pm = 2 -- Default to right side (2)
if pm == 0 then
	return Def.ActorFrame {}
elseif pm == 1 then
	panelPos = -1
end

local notes = GAMESTATE:GetCurrentSteps(pn):GetRadarValues(pn):GetValue(0)
local progress = 0
local maxcombo = 0
local percent = 0
local passflag = 0
local target1 = 0
local target2 = tonumber(ThemePrefs.Get("HV_PacemakerTargetGoal")) or 93 -- Default Target Goal (AA)

-- HV-themed colors
local colour = {
	Current = color("#00CFFF"),
	Target1 = color("#00E87A"),
	Target2 = color("#FF6B6B")
}

-- Grade table using HV's grade color system
local percent2grade = {
	{percent = 0,        grade = "D",     tier = "Tier16"},
	{percent = 60,       grade = "C",     tier = "Tier15"},
	{percent = 70,       grade = "B",     tier = "Tier14"},
	{percent = 80,       grade = "A",     tier = "Tier13"},
	{percent = 93.00,    grade = "AA",    tier = "Tier10"},
	{percent = 99.70,    grade = "AAA",   tier = "Tier07"},
	{percent = 99.955,   grade = "AAAA",  tier = "Tier04"},
	{percent = 99.9935,  grade = "AAAAA", tier = "Tier01"},
}

-- Get best score for the current rate
local function getBestScoreForCurrentRate()
	local rtTable = getRateTable()
	if rtTable == nil then return nil end
	local curRate = getCurRateDisplayString()
	if rtTable[curRate] and #rtTable[curRate] > 0 then
		return rtTable[curRate][1]
	end
	-- Fallback: try common formats
	local rv = getCurRateValue()
	local key = string.format("%.1fx", rv)
	if rtTable[key] and #rtTable[key] > 0 then
		return rtTable[key][1]
	end
	return nil
end

-- Abort completely if disabled via ThemePrefs
local showPacemakerGraph = ThemePrefs.Get("HV_ShowPacemakerGraph") ~= "false"
if not showPacemakerGraph then
	return Def.ActorFrame {}
end

local score = nil

-- Font zoom scaled up for HV visibility
local fontZoom = (SCREEN_HEIGHT / 1000) * 1.3
local fontZoomSmall = (SCREEN_HEIGHT / 1200) * 1.3

local t = Def.ActorFrame {
	Name = "PaceMaker",

	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X + ((SCREEN_WIDTH - panelWidth) / 2 * panelPos), SCREEN_CENTER_Y)
		score = getBestScoreForCurrentRate()
		if score then
			target1 = score:GetWifeScore() * 100
		end
		self:queuecommand("Display")
	end,
	JudgmentMessageCommand = function(self, msg)
		if msg.Judgment == "TapNoteScore_W1" or
			msg.Judgment == "TapNoteScore_W2" or
			msg.Judgment == "TapNoteScore_W3" or
			msg.Judgment == "TapNoteScore_W4" or
			msg.Judgment == "TapNoteScore_W5" or
			msg.Judgment == "TapNoteScore_Miss" then
			progress = progress + 1
			percent = msg.WifePercent
			self:playcommand("Update")
			if progress / notes * percent >= percent2grade[passflag + 1].percent then
				for j = 1, #percent2grade do
					if progress / notes * percent >= percent2grade[j].percent then
						passflag = j
					end
				end
				self:playcommand("UpdateGrade")
			end
		end
	end,

	-- Panel background
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(panelWidth, SCREEN_HEIGHT)
			self:diffuse(0.03, 0.03, 0.03, 0.85)
		end,
	},

	-- Current score meter
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(-0.33 * panelWidth * panelPos, baseline)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:align(0.5, 1)
				self:zoomto(panelWidth * 0.22, 0)
				self:diffuse(colour.Current)
				self:diffusealpha(0.2)
			end,
			UpdateCommand = function(self, msg)
				if percent < 0 then
					self:zoomtoheight(0)
				else
					self:zoomtoheight(meterheight * percent / 100)
				end
			end
		},
		Def.Quad {
			InitCommand = function(self)
				self:align(0.5, 1)
				self:zoomto(panelWidth * 0.22, 0)
				self:diffuse(colour.Current)
				self:diffusealpha(0.75)
			end,
			UpdateCommand = function(self, msg)
				if percent < 0 then
					self:zoomtoheight(0)
				else
					self:zoomtoheight(meterheight * percent / 100 * progress / notes)
				end
			end
		},
	},

	-- Target 1 (Best Score)
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(0, baseline)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:align(0.5, 1)
				self:zoomto(panelWidth * 0.22, 0)
				self:diffuse(colour.Target1):diffusealpha(0.2)
			end,
			DisplayCommand = function(self)
				self:decelerate(1.5):zoomtoheight(meterheight * target1 / 100)
			end,
		},
		Def.Quad {
			InitCommand = function(self)
				self:align(0.5, 1)
				self:zoomto(panelWidth * 0.22, 0)
				self:diffuse(colour.Target1)
				self:diffusealpha(0.75)
			end,
			UpdateCommand = function(self)
				self:zoomtoheight(meterheight * target1 / 100):croptop(1 - (progress / notes))
			end,
		},
		LoadFont("Common Normal") .. {
			DisplayCommand = function(self)
				self:align(0.5, 1.1):zoom(fontZoomSmall):y(-10)
				self:settext("Best")
				self:decelerate(1.5):y(-(meterheight - 10) * target1 / 100 - 10)
				self:sleep(1):linear(0.5):diffusealpha(0)
			end,
		},
		LoadFont("Common Normal") .. {
			DisplayCommand = function(self)
				self:align(0.5, -0.1):zoom(fontZoomSmall):y(-10)
				self:settextf("%2.2f", notes * target1 / 50):maxwidth(panelWidth * 0.22 / 0.35)
				self:decelerate(1.5):y(-(meterheight - 10) * target1 / 100 - 10)
				self:sleep(1):linear(0.5):diffusealpha(0)
			end,
		}
	},

	-- Target 2 (Goal)
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(0.33 * panelWidth * panelPos, baseline)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:align(0.5, 1)
				self:zoomto(panelWidth * 0.22, 0)
				self:diffuse(colour.Target2):diffusealpha(0.2)
			end,
			DisplayCommand = function(self)
				self:decelerate(1.5):zoomtoheight(meterheight * target2 / 100)
			end,
		},
		Def.Quad {
			InitCommand = function(self)
				self:align(0.5, 1)
				self:zoomto(panelWidth * 0.22, 0)
				self:diffuse(colour.Target2)
				self:diffusealpha(0.75)
			end,
			UpdateCommand = function(self)
				self:zoomtoheight(meterheight * target2 / 100):croptop(1 - (progress / notes))
			end,
		},
		LoadFont("Common Normal") .. {
			DisplayCommand = function(self)
				self:align(0.5, 1.1):zoom(fontZoomSmall):y(-10)
				self:settext("Target"):maxwidth(panelWidth * 0.22 / 0.35)
				self:decelerate(1.5):y(-(meterheight - 10) * target2 / 100 - 10)
				self:sleep(1):linear(0.5):diffusealpha(0)
			end,
		},
		LoadFont("Common Normal") .. {
			DisplayCommand = function(self)
				self:align(0.5, -0.1):zoom(fontZoomSmall):y(-10)
				self:settextf("%2.2f", notes * target2 / 50):maxwidth(panelWidth * 0.22 / 0.35)
				self:decelerate(1.5):y(-(meterheight - 10) * target2 / 100 - 10)
				self:sleep(1):linear(0.5):diffusealpha(0)
			end,
		}
	},

	-- Top text (left side)
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(-panelWidth * 0.48, -SCREEN_HEIGHT * 0.410)
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(0, 1):zoom(fontZoomSmall)
				self:settext("Timing Difficulty:"):y(-30)
				self:diffusealpha(0.5)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(0, 1):zoom(fontZoomSmall)
				self:settext("Life Difficulty:"):y(-16)
				self:diffusealpha(0.5)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(0, 1):zoom(fontZoomSmall)
				self:diffuse(colour.Current)
				self:settext(DLMAN:IsLoggedIn() and DLMAN:GetUsername() or PROFILEMAN:GetPlayerName(pn))
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(0, 1):zoom(fontZoomSmall):y(10)
				self:settext("PS Best")
				self:diffuse(colour.Target1)
			end,
		},
		LoadFont("Common Normal") .. {
			DisplayCommand = function(self)
				self:align(0, 1):zoom(fontZoomSmall):y(20)
				self:settext("PS " .. target2 .. "%")
				self:diffuse(colour.Target2)
			end,
		},
	},

	-- Top text (right side)
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(panelWidth * 0.48, -SCREEN_HEIGHT * 0.410)
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(1, 1):zoom(fontZoomSmall)
				self:settext(GetTimingDifficulty()):y(-30)
				self:diffusealpha(0.5)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(1, 1):zoom(fontZoomSmall)
				self:settext(GetLifeDifficulty()):y(-16)
				self:diffusealpha(0.5)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(1, 1):zoom(fontZoomSmall)
				self:settextf("%2.2f", 0)
			end,
			UpdateCommand = function(self, msg)
				self:settextf("%2.2f", progress * percent / 50)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(1, 1):zoom(fontZoomSmall):y(10)
				self:settextf("%2.2f", 0)
			end,
			UpdateCommand = function(self, msg)
				self:settextf("%2.2f", progress * target1 / 50)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:align(1, 1):zoom(fontZoomSmall):y(20)
				self:settextf("%2.2f", 0)
			end,
			UpdateCommand = function(self, msg)
				self:settextf("%2.2f", progress * target2 / 50)
			end
		},
	},

	-- Bottom text + Real-Time Grade Display
	Def.ActorFrame {
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:settext("Current Score")
				self:diffuse(colour.Current):zoom(fontZoomSmall)
				self:y(baseline + (SCREEN_HEIGHT * 0.02))
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:settext("Best Score")
				self:diffuse(colour.Target1):zoom(fontZoomSmall)
				self:y(baseline + (SCREEN_HEIGHT * 0.042))
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:settext("Target Score")
				self:diffuse(colour.Target2):zoom(fontZoomSmall)
				self:y(baseline + (SCREEN_HEIGHT * 0.064))
			end
		},
		-- Real-time Grade (colored by HV grade colors)
		LoadFont("Common Normal") .. {
			Name = "PacemakerGrade",
			InitCommand = function(self)
				self:zoom(fontZoom * 1.8)
				self:valign(1)
				self:y(baseline - 10)
				self:diffusealpha(0.8)
				self:settext("")
			end,
			UpdateGradeCommand = function(self)
				if passflag > 0 and passflag <= #percent2grade then
					local g = percent2grade[passflag]
					self:settext(g.grade)
					self:diffuse(HVColor.GetGradeColor(g.grade))
				end
			end,
			UpdateCommand = function(self)
				-- Also update on every judgment in case the grade mapping changes
				local wifePct = progress > 0 and (progress / notes * percent) or 0
				local gradeStr = "D"
				for j = 1, #percent2grade do
					if wifePct >= percent2grade[j].percent then
						gradeStr = percent2grade[j].grade
					end
				end
				self:settext(gradeStr)
				self:diffuse(HVColor.GetGradeColor(gradeStr))
			end,
		},
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(panelWidth, 2):y(baseline):align(0.5, 0)
				self:diffusealpha(0.3)
			end,
			UpdateCommand = function(self)
				if progress / notes * percent > 0 then
					self:diffuse(color("#00CFFF66"))
				end
			end
		},
	},
}

-- Grade tier markers along the meter
-- Displaying C, B, A, AA, AAA, AAAA, AAAAA (Indices 2 to 8 in percent2grade)
-- Static grade tier markers (C, B, A, AA)
for i = 2, 5 do
	t[#t + 1] = Def.ActorFrame {
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(panelWidth, SCREEN_HEIGHT / 300)
				self:y(baseline - (meterheight * percent2grade[i].percent / 100))
				self:align(0.5, 1)
				self:diffusealpha(0.3)
			end,
			UpdateGradeCommand = function(self)
				if passflag >= i then
					self:diffuse(color("#00CFFF66"))
				end
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-panelWidth * 0.5 * panelPos, baseline - (meterheight * percent2grade[i].percent / 100) - 2)
				self:align((1 - panelPos) / 2, 1)
				self:settext(percent2grade[i].grade)
				self:zoom(fontZoomSmall)
				self:diffusealpha(0.3)
			end,
			UpdateGradeCommand = function(self)
				if passflag == i then
					self:diffusealpha(0.7)
					local g = percent2grade[passflag]
					self:settext(g.grade)
					self:diffuse(HVColor.GetGradeColor(g.grade))
				end
			end
		},
	}
end

-- Dynamic high-tier marker (AAA -> AAAA -> AAAAA)
t[#t + 1] = Def.ActorFrame {
	Name = "DynamicHighTier",
	Def.Quad {
		Name = "Line",
		InitCommand = function(self)
			self:zoomto(panelWidth, SCREEN_HEIGHT / 300)
			self:align(0.5, 1)
			self:diffusealpha(0.3)
			self:playcommand("UpdateGrade")
		end,
		UpdateGradeCommand = function(self)
			local targetIdx = math.max(6, math.min(8, passflag))
			local g = percent2grade[targetIdx]
			self:y(baseline - (meterheight * g.percent / 100))
			if passflag >= targetIdx then
				self:diffuse(color("#00CFFF66"))
			else
				self:diffuse(color("#FFFFFF4D"))
			end
		end
	},
	LoadFont("Common Normal") .. {
		Name = "Label",
		InitCommand = function(self)
			self:align((1 - panelPos) / 2, 1)
			self:zoom(fontZoomSmall)
			self:diffusealpha(0.3)
			self:playcommand("UpdateGrade")
		end,
		UpdateGradeCommand = function(self)
			local targetIdx = math.max(6, math.min(8, passflag))
			local g = percent2grade[targetIdx]
			self:xy(-panelWidth * 0.5 * panelPos, baseline - (meterheight * g.percent / 100) - 2)
			self:settext(g.grade)
			
			if passflag >= targetIdx then
				self:diffusealpha(0.7)
				self:diffuse(HVColor.GetGradeColor(g.grade))
			else
				self:diffuse(color("#FFFFFF4D"))
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:align(0.5, 1):zoom(fontZoom)
			self:diffusealpha(0)
		end,
		UpdateGradeCommand = function(self)
			if passflag >= 6 then
				self:stoptweening()
				local g = percent2grade[passflag]
				self:settext("Rank " .. g.grade .. " Pass")
				self:diffusealpha(0):x(panelWidth * panelPos):linear(0.2):diffusealpha(1):x(0)
				self:sleep(1):linear(0.2):x(panelWidth * panelPos):diffusealpha(0)
			end
		end
	},
}

return t
