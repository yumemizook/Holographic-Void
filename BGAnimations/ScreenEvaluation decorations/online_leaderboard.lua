--- Holographic Void: Online Leaderboard (ported from Fatigue / spawncamping-wallhack)
-- Displays EtternaOnline chart leaderboard with Local/Online toggle,
-- Current/All rate filtering, sorted by SSR.

local pn = GAMESTATE:GetEnabledPlayers()[1]
local steps = GAMESTATE:GetCurrentSteps()
local profile = PROFILEMAN:GetProfile(pn)
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
local score = pss:GetHighScore()

local hsTable = getScoreTable(pn, getCurRate()) or {}

-- HV Color palette
local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.06,0.06,0.06,0.95")

local lbActor
local isLocal = true
local currentCountry = "Global"
local scoresPerPage = 5
local maxPages = math.max(1, math.ceil(#hsTable / scoresPerPage))
local curPage = 1
local alreadyPulled = false
local scoreList = hsTable
local showAllRates = false
local offsetScoreID

local function updateLeaderBoardForCurrentChart()
	alreadyPulled = true
	if steps then
		DLMAN:RequestChartLeaderBoardFromOnline(
			steps:GetChartKey(),
			function(leaderboard)
				if lbActor then
					lbActor:queuecommand("SetFromLeaderboard", leaderboard)
				end
			end
		)
	else
		if lbActor then
			lbActor:queuecommand("SetFromLeaderboard", {})
		end
	end
end

local function movePage(n)
	if maxPages <= 1 then return end
	if n > 0 then
		curPage = ((curPage + n - 1) % maxPages) + 1
	else
		curPage = ((curPage + n + maxPages - 1) % maxPages) + 1
	end
	MESSAGEMAN:Broadcast("UpdateOnlineList")
end

local function refreshScores(self)
	if isLocal then
		if showAllRates then
			-- All rates: gather all scores across rates
			scoreList = {}
			local song = GAMESTATE:GetCurrentSong()
			if song and steps then
				local chartKey = steps:GetChartKey()
				local scoresByKey = SCOREMAN:GetScoresByKey(chartKey)
				if scoresByKey then
					for rateStr, rateScores in pairs(scoresByKey) do
						for j = 1, #rateScores do
							scoreList[#scoreList + 1] = rateScores[j]
						end
					end
				end
			end
			if #scoreList == 0 then
				scoreList = hsTable
			end
		else
			scoreList = getScoreTable(pn, getCurRate()) or {}
		end
		-- Sort local scores by SSR
		table.sort(scoreList, function(a, b)
			local sa = a:GetSkillsetSSR("Overall")
			local sb = b:GetSkillsetSSR("Overall")
			return sa > sb
		end)
	else
		scoreList = DLMAN:GetChartLeaderBoard(steps:GetChartKey(), currentCountry)
		if scoreList ~= nil and #scoreList == 0 and not alreadyPulled then
			updateLeaderBoardForCurrentChart()
		end
		if scoreList then
			-- Sort online scores by SSR
			table.sort(scoreList, function(a, b)
				local sa = a:GetSkillsetSSR("Overall")
				local sb = b:GetSkillsetSSR("Overall")
				return sa > sb
			end)
		end
	end
	curPage = 1
	if scoreList ~= nil then
		maxPages = math.max(1, math.ceil(#scoreList / scoresPerPage))
	else
		maxPages = 1
		scoreList = {}
	end
end

local function scoreItem(i)
	return Def.ActorFrame {
		Name = "OnlineRow" .. i,
		InitCommand = function(self) self:y((i - 1) * 46) end,
		OnCommand = function(self) self:playcommand("UpdateRow") end,
		UpdateOnlineListMessageCommand = function(self) self:playcommand("UpdateRow") end,
		RefreshOnlineScoreboardMessageCommand = function(self) self:playcommand("UpdateRow") end,
		UpdateRowCommand = function(self)
			local idx = (curPage - 1) * scoresPerPage + i
			if scoreList and scoreList[idx] then
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
				self:diffuse(color("0,0,0,0.4"))
			end,
			WheelUpSlowMessageCommand = function(self) if self:IsOver() then movePage(-1) end end,
			WheelDownSlowMessageCommand = function(self) if self:IsOver() then movePage(1) end end
		},

		-- Rank #
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(-10, 12):zoom(0.22):diffuse(dimText) end,
			SetScoreCommand = function(self, params)
				self:settext(params.index)
			end
		},

		-- Grade
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(16, 8):zoom(0.28):halign(0) end,
			SetScoreCommand = function(self, params)
				local s = scoreList[params.index]
				local grade = s:GetWifeGrade()
				self:settext(HV.GetGradeName(ToEnumShortString(grade)))
				self:diffuse(HVColor.GetGradeColor(ToEnumShortString(grade)))
			end
		},

		-- Score %
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(55, 8):zoom(0.28):halign(0):diffuse(mainText) end,
			SetScoreCommand = function(self, params)
				local ws = scoreList[params.index]:GetWifeScore()
				if ws >= 0.99 then
					self:settextf("%.4f%%", math.floor(ws * 1000000) / 10000)
				else
					self:settextf("%.2f%%", math.floor(ws * 10000) / 100)
				end
			end
		},

		-- SSR
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(290, 8):zoom(0.24):halign(1) end,
			SetScoreCommand = function(self, params)
				local ssr = scoreList[params.index]:GetSkillsetSSR("Overall")
				if ssr > 0 then
					self:settextf("%.2f", ssr)
					self:diffuse(HVColor.GetMSDRatingColor(ssr))
				else
					self:settext(""):diffuse(dimText)
				end
			end
		},

		-- Player name (online only) or date (local)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(290, 24):zoom(0.18):halign(1):diffuse(dimText) end,
			SetScoreCommand = function(self, params)
				if isLocal then
					self:settext(scoreList[params.index]:GetDate())
				else
					local name = scoreList[params.index]:GetDisplayName()
					if name and name ~= "" then
						self:settext(name)
					else
						self:settext("")
					end
				end
			end
		},

		-- Judgment tally (no labels)
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:xy(16, 24):zoom(0.2):halign(0):diffuse(subText) end,
			SetScoreCommand = function(self, params)
				local s = scoreList[params.index]
				self:settextf("%d / %d / %d / %d / %d / %d",
					s:GetTapNoteScore("TapNoteScore_W1"),
					s:GetTapNoteScore("TapNoteScore_W2"),
					s:GetTapNoteScore("TapNoteScore_W3"),
					s:GetTapNoteScore("TapNoteScore_W4"),
					s:GetTapNoteScore("TapNoteScore_W5"),
					s:GetTapNoteScore("TapNoteScore_Miss"))
			end
		},
	}
end

local t = Def.ActorFrame {
	Name = "OnlineLeaderboard",
	InitCommand = function(self) lbActor = self end,
	OnCommand = function(self)
		refreshScores(self)
		self:playcommand("RefreshUI")
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_FirstPress" then
				if event.button == "MenuLeft" then movePage(-1)
				elseif event.button == "MenuRight" then movePage(1) end
			end
		end)
	end,
	SetFromLeaderboardCommand = function(self, leaderboard)
		refreshScores(self)
		self:playcommand("RefreshUI")
	end,
	RefreshUICommand = function(self)
		MESSAGEMAN:Broadcast("RefreshOnlineScoreboard")
	end,

	-- ============================================================
	-- TAB BUTTONS: Local / Online
	-- ============================================================
	Def.Quad {
		Name = "LocalTab",
		InitCommand = function(self)
			self:xy(0, -38):zoomto(60, 16):halign(0):valign(0)
			self:diffuse(accentColor):diffusealpha(isLocal and 0.4 or 0.1)
		end,
		RefreshOnlineScoreboardMessageCommand = function(self)
			self:diffusealpha(isLocal and 0.4 or 0.1)
		end,
		MouseDownCommand = function(self)
			if not isLocal then
				isLocal = true
				refreshScores(self:GetParent())
				self:GetParent():playcommand("RefreshUI")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(30, -30):zoom(0.2):diffuse(brightText):settext("Local") end
	},

	Def.Quad {
		Name = "OnlineTab",
		InitCommand = function(self)
			self:xy(64, -38):zoomto(60, 16):halign(0):valign(0)
			self:diffuse(accentColor):diffusealpha(not isLocal and 0.4 or 0.1)
		end,
		RefreshOnlineScoreboardMessageCommand = function(self)
			self:diffusealpha(not isLocal and 0.4 or 0.1)
		end,
		MouseDownCommand = function(self)
			if isLocal and DLMAN:IsLoggedIn() then
				isLocal = false
				refreshScores(self:GetParent())
				self:GetParent():playcommand("RefreshUI")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(94, -30):zoom(0.2):diffuse(brightText):settext("Online") end
	},

	-- ============================================================
	-- RATE FILTER: Current / All
	-- ============================================================
	Def.Quad {
		Name = "CurrentRateTab",
		InitCommand = function(self)
			self:xy(160, -38):zoomto(70, 16):halign(0):valign(0)
			self:diffuse(color("#555555")):diffusealpha(not showAllRates and 0.4 or 0.1)
		end,
		RefreshOnlineScoreboardMessageCommand = function(self)
			self:diffusealpha(not showAllRates and 0.4 or 0.1)
		end,
		MouseDownCommand = function(self)
			if showAllRates then
				showAllRates = false
				pcall(function() DLMAN:ToggleRateFilter() end)
				refreshScores(self:GetParent())
				self:GetParent():playcommand("RefreshUI")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(195, -30):zoom(0.18):diffuse(brightText):settext("Current") end
	},

	Def.Quad {
		Name = "AllRatesTab",
		InitCommand = function(self)
			self:xy(234, -38):zoomto(60, 16):halign(0):valign(0)
			self:diffuse(color("#555555")):diffusealpha(showAllRates and 0.4 or 0.1)
		end,
		RefreshOnlineScoreboardMessageCommand = function(self)
			self:diffusealpha(showAllRates and 0.4 or 0.1)
		end,
		MouseDownCommand = function(self)
			if not showAllRates then
				showAllRates = true
				pcall(function() DLMAN:ToggleRateFilter() end)
				refreshScores(self:GetParent())
				self:GetParent():playcommand("RefreshUI")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:xy(264, -30):zoom(0.18):diffuse(brightText):settext("All") end
	},

	-- Page info
	LoadFont("Common Normal") .. {
		Name = "PageInfo",
		InitCommand = function(self) self:xy(150, scoresPerPage * 46 + 8):zoom(0.2):diffuse(dimText) end,
		OnCommand = function(self) self:playcommand("UpdateText") end,
		UpdateOnlineListMessageCommand = function(self) self:playcommand("UpdateText") end,
		RefreshOnlineScoreboardMessageCommand = function(self) self:playcommand("UpdateText") end,
		UpdateTextCommand = function(self)
			if scoreList and #scoreList > 0 then
				local src = isLocal and "Local" or "Online"
				local rateLabel = showAllRates and "All Rates" or "Current Rate"
				self:settextf("%s (%s) — Page %d/%d — %d scores", src, rateLabel, curPage, maxPages, #scoreList)
			else
				self:settext("No scores")
			end
		end
	},
}

for i = 1, scoresPerPage do
	t[#t + 1] = scoreItem(i)
end

return t
