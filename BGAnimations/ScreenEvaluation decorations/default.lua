--- Holographic Void: ScreenEvaluation Decorations
-- Full results display (1-player only) with:
--   - Grade, score percentage (4 decimals if >=99%), clear type
--   - Player avatar + profile
--   - Judgment breakdown
--   - Life/Combo graph, Offset graph
--   - Local + Online leaderboards

local t = Def.ActorFrame {
	Name = "EvalDecorations"
}

local accentColor = color("#5ABAFF")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.06,0.06,0.06,0.9")

local judgmentColors = {
	color("#FFFFFF"), color("#E0E0A0"), color("#A0E0A0"),
	color("#A0C8E0"), color("#C8A0E0"), color("#E0A0A0")
}

-- ============================================================
-- HELPER: Clear Type detection
-- ============================================================
local function getClearType(pss)
	if not pss then return "FAILED" end
	local miss = pss:GetTapNoteScores("TapNoteScore_Miss")
	local w5 = pss:GetTapNoteScores("TapNoteScore_W5")
	local w4 = pss:GetTapNoteScores("TapNoteScore_W4")
	local w3 = pss:GetTapNoteScores("TapNoteScore_W3")
	local w2 = pss:GetTapNoteScores("TapNoteScore_W2")

	if miss > 0 then
		local grade = pss:GetGrade()
		local gradeStr = ToEnumShortString(grade)
		if gradeStr == "Failed" then return "FAILED" end
		return "CLEAR"
	end
	-- Full combo variants
	if w5 > 0 then return "FULL COMBO" end
	if w4 > 0 then return "FULL COMBO" end
	if w3 > 0 then return "FULL COMBO" end
	if w2 > 0 then return "ALL PERFECT" end
	return "ALL MARVELOUS"
end

-- ============================================================
-- HEADER: Song Info + Clear Type
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "HeaderFrame",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, 20)
	end,

	-- Song title
	LoadFont("Zpix Normal") .. {
		InitCommand = function(self)
			self:valign(0):zoom(0.6):diffuse(brightText):maxwidth(SCREEN_WIDTH * 0.6 / 0.6)
		end,
		BeginCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:settext(song:GetDisplayMainTitle())
			end
		end
	},

	-- Artist
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:valign(0):y(20):zoom(0.38):diffuse(subText):maxwidth(SCREEN_WIDTH * 0.6 / 0.38)
		end,
		BeginCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:settext(song:GetDisplayArtist())
			end
		end
	},

	-- Difficulty + Rate
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:valign(0):y(36):zoom(0.3):diffuse(dimText)
		end,
		BeginCommand = function(self)
			local steps = GAMESTATE:GetCurrentSteps()
			local rate = getCurRateString()
			if steps then
				local diff = ToEnumShortString(steps:GetDifficulty())
				self:settext(diff .. " · " .. (rate or "1.0x"))
			end
		end
	},

	-- Clear Type
	LoadFont("Common Normal") .. {
		Name = "ClearType",
		InitCommand = function(self)
			self:valign(0):y(0):x(SCREEN_WIDTH * 0.38):zoom(0.45)
		end,
		BeginCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local ct = getClearType(pss)
				self:settext(ct)
				self:diffuse(HVColor.GetClearTypeColor(ct))
			end
		end
	},

	-- Header separator
	Def.Quad {
		InitCommand = function(self)
			self:y(52):zoomto(SCREEN_WIDTH * 0.85, 1):diffuse(color("0.15,0.15,0.15,1"))
		end
	}
}

-- ============================================================
-- LEFT SIDE: Avatar + Grade + Score + Judgments
-- ============================================================
local leftX = SCREEN_WIDTH * 0.22
local panelTop = 72

-- Player Avatar + Name
t[#t + 1] = Def.ActorFrame {
	Name = "PlayerInfo",
	InitCommand = function(self)
		self:xy(leftX - SCREEN_WIDTH * 0.14, panelTop + 8)
	end,

	-- Avatar
	Def.Sprite {
		Name = "EvalAvatar",
		InitCommand = function(self)
			self:halign(0):valign(0)
		end,
		BeginCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local avatarPath = nil
				if profile.GetAvatarPath then
					avatarPath = profile:GetAvatarPath()
				end
				if avatarPath and avatarPath ~= "" and FILEMAN:DoesFileExist(avatarPath) then
					self:Load(avatarPath)
				else
					local fallback = "/Assets/Avatars/_fallback.png"
					if FILEMAN:DoesFileExist(fallback) then
						self:Load(fallback)
					end
				end
				self:scaletoclipped(44, 44)
				self:visible(true)
			else
				self:visible(false)
			end
		end
	},

	-- Player name
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):x(52):y(4):zoom(0.4):diffuse(mainText)
		end,
		BeginCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local name = profile:GetDisplayName()
				if name == "" then name = "Player" end
				self:settext(name)
			end
		end
	},

	-- Rating
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):x(52):y(22):zoom(0.32):diffuse(accentColor)
		end,
		BeginCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				self:settext(string.format("%.2f", profile:GetPlayerRating()))
			end
		end
	}
}

-- Grade + Score panel
t[#t + 1] = Def.ActorFrame {
	Name = "GradePanel",
	InitCommand = function(self)
		self:xy(leftX, panelTop + 64)
	end,

	-- Panel background
	Def.Quad {
		InitCommand = function(self)
			self:valign(0):zoomto(SCREEN_WIDTH * 0.35, 180):diffuse(bgCard)
		end
	},

	-- Grade letter
	LoadFont("Common Large") .. {
		Name = "GradeLetter",
		InitCommand = function(self)
			self:y(24):zoom(1.1):diffuse(brightText)
		end,
		BeginCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local grade = pss:GetGrade()
				local gradeStr = ToEnumShortString(grade)
				self:settext(gradeStr)
				self:diffuse(HVColor.GetGradeColor(gradeStr))
			end
		end
	},

	-- Wife Score (4 decimals if >= 99%)
	LoadFont("Common Normal") .. {
		Name = "WifeScore",
		InitCommand = function(self)
			self:y(62):zoom(0.75):diffuse(accentColor)
		end,
		BeginCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local wifePct = pss:GetWifeScore() * 100
				if wifePct >= 99 then
					self:settext(string.format("%.4f%%", wifePct))
				else
					self:settext(string.format("%.2f%%", wifePct))
				end
			end
		end
	},

	-- Score label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(82):zoom(0.26):diffuse(dimText)
			self:settext("WIFE SCORE")
		end
	},

	-- Max Combo
	LoadFont("Common Normal") .. {
		Name = "MaxCombo",
		InitCommand = function(self)
			self:y(106):zoom(0.4):diffuse(mainText)
		end,
		BeginCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				self:settext("Max Combo: " .. pss:MaxCombo())
			end
		end
	},

	-- Mean offset
	LoadFont("Common Normal") .. {
		Name = "MeanOffset",
		InitCommand = function(self)
			self:y(126):zoom(0.32):diffuse(subText)
		end,
		BeginCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local offsets = pss:GetOffsetVector()
				if offsets and #offsets > 0 then
					local sum = 0
					for _, v in ipairs(offsets) do
						sum = sum + v
					end
					local mean = sum / #offsets
					self:settext(string.format("Mean: %.1fms", mean * 1000))
				else
					self:settext("")
				end
			end
		end
	}
}

-- Judgment Breakdown
local judgmentNames = {"W1", "W2", "W3", "W4", "W5", "Miss"}
local judgmentLabels = {"Marvelous", "Perfect", "Great", "Good", "Bad", "Miss"}

t[#t + 1] = Def.ActorFrame {
	Name = "JudgmentPanel",
	InitCommand = function(self)
		self:xy(leftX, panelTop + 256)
	end,

	-- Header
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:valign(0):y(0):zoom(0.3):diffuse(accentColor)
			self:settext("JUDGMENTS")
		end
	}
}

for i, jName in ipairs(judgmentNames) do
	t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(leftX, panelTop + 270 + (i * 22))
		end,

		-- Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):x(-SCREEN_WIDTH * 0.15):zoom(0.32)
					:diffuse(judgmentColors[i])
			end,
			BeginCommand = function(self)
				self:settext(judgmentLabels[i])
			end
		},

		-- Count
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(1):x(SCREEN_WIDTH * 0.15):zoom(0.38):diffuse(mainText)
			end,
			BeginCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local tns
					if jName == "Miss" then
						tns = "TapNoteScore_Miss"
					else
						tns = "TapNoteScore_" .. jName
					end
					self:settext(pss:GetTapNoteScores(tns))
				end
			end
		},

		-- Bar
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):x(-SCREEN_WIDTH * 0.15):y(9)
					:zoomto(0, 2):diffuse(judgmentColors[i]):diffusealpha(0.15)
			end,
			BeginCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					local tns
					if jName == "Miss" then
						tns = "TapNoteScore_Miss"
					else
						tns = "TapNoteScore_" .. jName
					end
					local count = pss:GetTapNoteScores(tns)
					local total = pss:GetTotalTaps()
					if total > 0 then
						local pct = count / total
						local maxW = SCREEN_WIDTH * 0.30
						self:linear(0.5):zoomto(maxW * pct, 2)
					end
				end
			end
		}
	}
end

-- ============================================================
-- RIGHT SIDE: Offset Graph + Leaderboards
-- ============================================================
local rightX = SCREEN_WIDTH * 0.7
local rightPanelW = SCREEN_WIDTH * 0.32

-- Offset Scatter Plot
local scatterY = panelTop + 72
local scatterW = rightPanelW
local scatterH = 80

t[#t + 1] = Def.ActorFrame {
	Name = "OffsetPlot",
	InitCommand = function(self)
		self:xy(rightX, scatterY)
	end,

	-- Background
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(scatterW, scatterH):diffuse(bgCard)
		end
	},

	-- Zero line
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(scatterW, 1):diffuse(color("0.25,0.25,0.25,1"))
		end
	},

	-- Header
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-scatterW / 2 + 5):y(-scatterH / 2 + 8)
				:halign(0):valign(0):zoom(0.22):diffuse(dimText)
			self:settext("HIT OFFSET")
		end
	},

	-- Offset dots
	Def.ActorFrame {
		Name = "OffsetDots",
		BeginCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if not pss then return end

			local offsets = pss:GetOffsetVector()
			if not offsets or #offsets == 0 then return end

			local maxDots = math.min(#offsets, 300)
			local step = math.max(1, math.floor(#offsets / maxDots))

			for j = 1, #offsets, step do
				local off = offsets[j]
				local clampedOff = math.max(-0.18, math.min(0.18, off))
				local xPos = (clampedOff / 0.18) * (scatterW / 2 - 10)
				local yPos = (math.random() - 0.5) * (scatterH * 0.7)

				local absOff = math.abs(clampedOff)
				local dotColor
				if absOff < 0.022 then
					dotColor = color("1,1,1,0.6")
				elseif absOff < 0.045 then
					dotColor = color("0.8,0.9,0.6,0.5")
				elseif absOff < 0.090 then
					dotColor = color("0.9,0.7,0.4,0.4")
				else
					dotColor = color("0.9,0.5,0.5,0.3")
				end

				local dot = Def.Quad {
					InitCommand = function(s)
						s:xy(xPos, yPos):zoomto(2, 2):diffuse(dotColor)
					end
				}
				self:AddChild(dot)
			end
		end
	}
}

-- ============================================================
-- LIFE / COMBO GRAPH (simple bar visualization)
-- ============================================================
local graphY = scatterY + scatterH / 2 + 20
local graphH = 50

t[#t + 1] = Def.ActorFrame {
	Name = "LifeComboGraph",
	InitCommand = function(self)
		self:xy(rightX, graphY)
	end,

	-- Background
	Def.Quad {
		InitCommand = function(self)
			self:valign(0):zoomto(rightPanelW, graphH):diffuse(bgCard)
		end
	},

	-- Header
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-rightPanelW / 2 + 5):y(8)
				:halign(0):valign(0):zoom(0.22):diffuse(dimText)
			self:settext("LIFE GRAPH")
		end
	},

	-- Life graph placeholder (using combo data as a simple line)
	Def.ActorFrame {
		Name = "LifeGraphBars",
		BeginCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if not pss then return end

			local offsets = pss:GetOffsetVector()
			if not offsets or #offsets == 0 then return end

			-- Simple bar graph: divide into segments
			local numBars = math.min(40, #offsets)
			local segSize = math.max(1, math.floor(#offsets / numBars))
			local barW = (rightPanelW - 10) / numBars

			for b = 1, numBars do
				-- Calculate average "life" for this segment (based on hits vs misses)
				local startIdx = (b - 1) * segSize + 1
				local endIdx = math.min(b * segSize, #offsets)
				local hits = 0
				local total = 0
				for k = startIdx, endIdx do
					total = total + 1
					if math.abs(offsets[k]) < 0.18 then
						hits = hits + 1
					end
				end
				local pct = total > 0 and (hits / total) or 0
				local barHeight = pct * (graphH - 16)

				local bar = Def.Quad {
					InitCommand = function(s)
						s:halign(0):valign(1)
						s:xy(-rightPanelW / 2 + 5 + (b - 1) * barW, graphH - 2)
						s:zoomto(barW - 1, barHeight)
						s:diffuse(accentColor):diffusealpha(0.3)
					end
				}
				self:AddChild(bar)
			end
		end
	}
}

-- ============================================================
-- LOCAL LEADERBOARD
-- ============================================================
local ldbY = graphY + graphH + 16

t[#t + 1] = Def.ActorFrame {
	Name = "LocalLeaderboard",
	InitCommand = function(self)
		self:xy(rightX, ldbY)
	end,

	-- Background
	Def.Quad {
		InitCommand = function(self)
			self:valign(0):zoomto(rightPanelW, 110):diffuse(bgCard)
		end
	},

	-- Header
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-rightPanelW / 2 + 5):y(6)
				:halign(0):valign(0):zoom(0.24):diffuse(accentColor)
			self:settext("LOCAL SCORES")
		end
	}
}

-- Local leaderboard entries
for rank = 1, 5 do
	t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(rightX, ldbY + 18 + rank * 16)
		end,

		-- Rank number
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):x(-rightPanelW / 2 + 5):zoom(0.25):diffuse(dimText)
			end,
			BeginCommand = function(self)
				self:settext(tostring(rank) .. ".")
			end
		},

		-- Score
		LoadFont("Common Normal") .. {
			Name = "LdbScore_" .. rank,
			InitCommand = function(self)
				self:halign(0):x(-rightPanelW / 2 + 24):zoom(0.28):diffuse(mainText)
			end,
			BeginCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				local steps = GAMESTATE:GetCurrentSteps()
				if song and steps then
					local profile = PROFILEMAN:GetProfile(PLAYER_1)
					if profile then
						local hsl = profile:GetHighScoreList(song, steps)
						if hsl then
							local scores = hsl:GetHighScores()
							if scores and scores[rank] then
								local wifePct = scores[rank]:GetWifeScore() * 100
								if wifePct >= 99 then
									self:settext(string.format("%.4f%%", wifePct))
								else
									self:settext(string.format("%.2f%%", wifePct))
								end
								return
							end
						end
					end
				end
				self:settext("---")
				self:diffuse(dimText)
			end
		},

		-- Grade
		LoadFont("Common Normal") .. {
			Name = "LdbGrade_" .. rank,
			InitCommand = function(self)
				self:halign(1):x(rightPanelW / 2 - 5):zoom(0.25):diffuse(subText)
			end,
			BeginCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				local steps = GAMESTATE:GetCurrentSteps()
				if song and steps then
					local profile = PROFILEMAN:GetProfile(PLAYER_1)
					if profile then
						local hsl = profile:GetHighScoreList(song, steps)
						if hsl then
							local scores = hsl:GetHighScores()
							if scores and scores[rank] then
								self:settext(ToEnumShortString(scores[rank]:GetGrade()))
								return
							end
						end
					end
				end
				self:settext("")
			end
		}
	}
end

-- ============================================================
-- ONLINE LEADERBOARD
-- ============================================================
local onlineLdbY = ldbY + 122

t[#t + 1] = Def.ActorFrame {
	Name = "OnlineLeaderboard",
	InitCommand = function(self)
		self:xy(rightX, onlineLdbY)
	end,

	-- Background
	Def.Quad {
		InitCommand = function(self)
			self:valign(0):zoomto(rightPanelW, 110):diffuse(bgCard)
		end
	},

	-- Header
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(-rightPanelW / 2 + 5):y(6)
				:halign(0):valign(0):zoom(0.24):diffuse(accentColor)
			self:settext("ONLINE SCORES")
		end
	}
}

-- Online leaderboard entries
for rank = 1, 5 do
	t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(rightX, onlineLdbY + 18 + rank * 16)
		end,

		-- Rank
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):x(-rightPanelW / 2 + 5):zoom(0.25):diffuse(dimText)
			end,
			BeginCommand = function(self)
				self:settext(tostring(rank) .. ".")
			end
		},

		-- Score
		LoadFont("Common Normal") .. {
			Name = "OnlineLdbScore_" .. rank,
			InitCommand = function(self)
				self:halign(0):x(-rightPanelW / 2 + 24):zoom(0.28):diffuse(mainText)
			end,
			BeginCommand = function(self)
				-- Try DLMAN online scores
				local steps = GAMESTATE:GetCurrentSteps()
				if steps then
					local chartKey = steps:GetChartKey()
					if chartKey and DLMAN.GetChartLeaderBoard then
						local lb = DLMAN:GetChartLeaderBoard(chartKey)
						if lb and lb[rank] then
							local wifePct = lb[rank]:GetWifeScore() * 100
							if wifePct >= 99 then
								self:settext(string.format("%.4f%%", wifePct))
							else
								self:settext(string.format("%.2f%%", wifePct))
							end
							return
						end
					end
				end
				self:settext("---")
				self:diffuse(dimText)
			end
		},

		-- Player name
		LoadFont("Common Normal") .. {
			Name = "OnlineLdbName_" .. rank,
			InitCommand = function(self)
				self:halign(1):x(rightPanelW / 2 - 5):zoom(0.22):diffuse(subText)
			end,
			BeginCommand = function(self)
				local steps = GAMESTATE:GetCurrentSteps()
				if steps then
					local chartKey = steps:GetChartKey()
					if chartKey and DLMAN.GetChartLeaderBoard then
						local lb = DLMAN:GetChartLeaderBoard(chartKey)
						if lb and lb[rank] then
							local name = lb[rank]:GetDisplayName()
							if name then
								self:settext(name)
								return
							end
						end
					end
				end
				self:settext("")
			end
		}
	}
end

-- ============================================================
-- MOUSE SUPPORT: Click to advance
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "MouseHandler",
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		screen:AddInputCallback(function(event)
			if event.type == "InputEventType_Release" then return end
			local btn = event.DeviceInput.button

			-- Left click anywhere -> advance screen (same as pressing Start)
			if IsMouseLeftClick(btn) then
				local scr = SCREENMAN:GetTopScreen()
				if scr then
					scr:StartTransitioningScreen("SM_GoToNextScreen")
				end
				return
			end
		end)
	end
}

return t
