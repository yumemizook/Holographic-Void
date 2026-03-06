--- Holographic Void: Local Scoreboard (ported from Fatigue / spawncamping-wallhack)
-- Displays paginated local high-scores for the chart at the current rate.
-- Features: SSR, Judgment tally (no labels), ClearType lamp, sort by SSR.

local lines = 4
local pn = GAMESTATE:GetEnabledPlayers()[1]
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
local steps = GAMESTATE:GetCurrentSteps()
local score = pss:GetHighScore()
local hsTable = getScoreTable(pn, getCurRate()) or {}

local scoreIndex = 0
if #hsTable > 0 then
	local ok, idx = pcall(function() return getHighScoreIndex(hsTable, score) end)
	if ok and idx then scoreIndex = idx end
end

-- Sort by SSR (descending)
table.sort(hsTable, function(a, b)
	local sa = a:GetSkillsetSSR("Overall")
	local sb = b:GetSkillsetSSR("Overall")
	return sa > sb
end)

-- Re-find scoreIndex after sort
for i, s in ipairs(hsTable) do
	if s == score then
		scoreIndex = i
		break
	end
end

local curPage = scoreIndex > 0 and math.ceil(scoreIndex / lines) or 1
local maxPages = math.max(1, math.ceil(#hsTable / lines))

local function movePage(n)
	if maxPages <= 1 then return end
	if n > 0 then
		curPage = ((curPage + n - 1) % maxPages) + 1
	else
		curPage = ((curPage + n + maxPages - 1) % maxPages) + 1
	end
	MESSAGEMAN:Broadcast("UpdateLocalScoreboard")
end

-- HV Color palette
local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")
local dimText = brightText
local subText = brightText
local mainText = brightText
local bgCard = color("0.06,0.06,0.06,0.95")

-- Judgment colors (same as main eval for tally coloring)
local judgmentColors = {
	color("#FFFFFF"), color("#E0E0A0"), color("#A0E0A0"),
	color("#A0C8E0"), color("#C8A0E0"), color("#E0A0A0")
}

local function scoreItem(i)
	return Def.ActorFrame {
		Name = "LocalRow" .. i,
		InitCommand = function(self) self:y((i - 1) * 46) end,
		OnCommand = function(self) self:playcommand("UpdateRow") end,
		UpdateLocalScoreboardMessageCommand = function(self) self:playcommand("UpdateRow") end,
		UpdateRowCommand = function(self)
			local idx = (curPage - 1) * lines + i
			if hsTable[idx] then
				self:visible(true)
				self:RunCommandsOnChildren(function(child) child:playcommand("SetScore", {index = idx}) end)
			else
				self:visible(false)
			end
		end,

		-- Row BG
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(300, 42):diffuse(color("0,0,0,0.4"))
			end,
			SetScoreCommand = function(self, params)
				if params.index == scoreIndex then
					self:diffuse(accentColor):diffusealpha(0.1)
				else
					self:diffuse(color("0,0,0,0.4"))
				end
			end,
			WheelUpSlowMessageCommand = function(self) if self:IsOver() then movePage(-1) end end,
			WheelDownSlowMessageCommand = function(self) if self:IsOver() then movePage(1) end end
		},

		-- ClearType lamp
		Def.Quad {
			InitCommand = function(self) self:halign(0):valign(0):zoomto(4, 42) end,
			SetScoreCommand = function(self, params)
				local ct = getClearType(pn, steps, hsTable[params.index])
				self:diffuse(getClearTypeColor(ct))
			end
		},

		-- Rank #
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(-10, 12):zoom(0.28):diffuse(dimText) end,
			SetScoreCommand = function(self, params)
				self:settext(params.index)
				if params.index == scoreIndex then
					self:diffuse(accentColor)
				else
					self:diffuse(dimText)
				end
			end
		},

		-- Grade
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(16, 8):zoom(0.45):halign(0) end,
			SetScoreCommand = function(self, params)
				local grade = hsTable[params.index]:GetWifeGrade()
				self:settext(HV.GetGradeName(ToEnumShortString(grade)))
				self:diffuse(HVColor.GetGradeColor(ToEnumShortString(grade)))
			end
		},

		-- Score %
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(60, 8):zoom(0.45):halign(0):diffuse(mainText) end,
			SetScoreCommand = function(self, params)
				local ws = hsTable[params.index]:GetWifeScore()
				if ws >= 0.99 then
					self:settextf("%.4f%%", math.floor(ws * 1000000) / 10000)
				else
					self:settextf("%.2f%%", math.floor(ws * 10000) / 100)
				end
			end
		},

		-- SSR
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(290, 8):zoom(0.45):halign(1) end,
			SetScoreCommand = function(self, params)
				local ssr = hsTable[params.index]:GetSkillsetSSR("Overall")
				if ssr > 0 then
					self:settextf("%.2f", ssr)
					self:diffuse(HVColor.GetMSDRatingColor(ssr))
				else
					self:settext(""):diffuse(dimText)
				end
			end
		},

		-- Judgment tally (colored, no labels)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(16, 24):zoom(0.25):halign(0) end,
			SetScoreCommand = function(self, params)
				local s = hsTable[params.index]
				local counts = {
					s:GetTapNoteScore("TapNoteScore_W1"),
					s:GetTapNoteScore("TapNoteScore_W2"),
					s:GetTapNoteScore("TapNoteScore_W3"),
					s:GetTapNoteScore("TapNoteScore_W4"),
					s:GetTapNoteScore("TapNoteScore_W5"),
					s:GetTapNoteScore("TapNoteScore_Miss")
				}
				self:settextf("%d / %d / %d / %d / %d / %d",
					counts[1], counts[2], counts[3], counts[4], counts[5], counts[6])
				self:diffuse(subText)
			end
		},

		-- Date
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(290, 24):zoom(0.3):halign(1):diffuse(dimText) end,
			SetScoreCommand = function(self, params)
				self:settext(hsTable[params.index]:GetDate())
			end
		},

		-- Replay dot
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(290, 35):zoom(0.15):halign(1):diffuse(color("#7AFFAF"))
				self:settext("●"):visible(false)
			end,
			SetScoreCommand = function(self, params)
				self:visible(hsTable[params.index]:HasReplayData())
			end
		},
	}
end

local t = Def.ActorFrame {
	Name = "LocalScoreboard",
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_FirstPress" then
				if event.button == "MenuLeft" then movePage(-1)
				elseif event.button == "MenuRight" then movePage(1) end
			end
		end)
	end,

	-- Header
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(0, -18):zoom(0.35):halign(0):diffuse(accentColor) end,
		OnCommand = function(self)
			self:settextf("Local Scores (sorted by SSR) — %d total", #hsTable)
		end
	},

	-- Page info
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self) self:xy(150, lines * 46 + 8):zoom(0.28):diffuse(dimText) end,
		OnCommand = function(self) self:playcommand("UpdateText") end,
		UpdateLocalScoreboardMessageCommand = function(self) self:playcommand("UpdateText") end,
		UpdateTextCommand = function(self)
			if #hsTable > 0 then
				self:settextf("Page %d/%d", curPage, maxPages)
			else
				self:settext("No scores")
			end
		end
	},
}

for i = 1, lines do
	t[#t + 1] = scoreItem(i)
end

return t
