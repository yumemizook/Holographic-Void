-- Holographic Void: Multiplayer Scoreboard (osu!lazer minimal style)
-- Minimal floating scoreboard showing player ranks, scores, and accuracy
-- Only visible when 2+ players are active
-- to be reformatted so it match leaderboard.lua

local numPlayers = #GAMESTATE:GetEnabledPlayers()
if numPlayers < 2 then
	return Def.ActorFrame {} -- Single player - hide scoreboard
end

-- HV-themed colors
local accentColor = HVColor.Accent or color("#00CFFF")
local brightText = color("1,1,1,1")
local dimText = color("0.65,0.65,0.65,1")
local bgCard = color("0.06,0.06,0.06,0.85")

-- Scoreboard configuration - osu!lazer minimal style
local scoreboardW = 140
local scoreboardH = 28
local rowSpacing = 32
local scoreboardX = SCREEN_RIGHT - scoreboardW - 10
local scoreboardY = 40

-- Player data storage
local playerData = {}

-- Initialize player data for all enabled players
for i, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
	playerData[pn] = {
		index = i,
		name = PROFILEMAN:GetPlayerName(pn),
		score = 0,
		accuracy = 0,
		combo = 0,
		isAlive = true
	}
end

local t = Def.ActorFrame {
	Name = "MultiplayerScoreboard",
	
	InitCommand = function(self)
		self:xy(scoreboardX, scoreboardY)
	end,

	-- Background panel
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
				:zoomto(scoreboardW, (numPlayers * rowSpacing) + 8)
				:diffuse(bgCard):diffusealpha(0.9)
		end
	},

	-- Left accent line
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
				:zoomto(2, (numPlayers * rowSpacing) + 8)
				:diffuse(accentColor):diffusealpha(0.5)
		end
	}
}

-- Create a row for each player
for i, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
	local rowY = 4 + (i - 1) * rowSpacing
	local isP1 = (pn == PLAYER_1)
	local playerColor = isP1 and accentColor or color("#FF6B6B") -- P1 gets accent, P2 gets red-ish
	
	local rowFrame = Def.ActorFrame {
		Name = "PlayerRow_" .. (isP1 and "P1" or "P2"),
		InitCommand = function(self)
			self:xy(8, rowY)
		end,

		-- Rank number (1, 2, etc.)
		LoadFont("Common Normal") .. {
			Name = "Rank",
			InitCommand = function(self)
				self:halign(0):valign(0)
					:zoom(0.35)
					:diffuse(playerColor)
					:settext(tostring(i))
			end
		},

		-- Player name (truncated)
		LoadFont("Common Normal") .. {
			Name = "PlayerName",
			InitCommand = function(self)
				self:halign(0):valign(0)
					:x(14)
					:zoom(0.32)
					:diffuse(brightText)
					:maxwidth((scoreboardW - 50) / 0.32)
					:settext(playerData[pn].name)
			end
		},

		-- Active indicator dot
		Def.Quad {
			Name = "ActiveDot",
			InitCommand = function(self)
				self:halign(0):valign(0.5)
					:x(scoreboardW - 20)
					:y(6)
					:zoomto(6, 6)
					:diffuse(playerColor)
			end
		},

		-- Accuracy %
		LoadFont("Common Normal") .. {
			Name = "Accuracy",
			InitCommand = function(self)
				self:halign(1):valign(0)
					:x(scoreboardW - 24)
					:y(2)
					:zoom(0.38)
					:diffuse(brightText)
					:settext("0.00%")
			end,
			JudgmentMessageCommand = function(self, params)
				if params.Player ~= pn then return end
				
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(pn)
				if pss then
					local wifeScore = pss:GetWifeScore()
					if wifeScore then
						local pct = wifeScore * 100
						if pct >= 99 then
							self:settext(string.format("%.4f%%", pct))
						else
							self:settext(string.format("%.2f%%", pct))
						end
						
						-- Color by accuracy
						local gradeStr = "F"
						if     pct >= 99.9935 then gradeStr = "AAAAA"
						elseif pct >= 99.955  then gradeStr = "AAAA"
						elseif pct >= 99.70   then gradeStr = "AAA"
						elseif pct >= 93.00   then gradeStr = "AA"
						elseif pct >= 80.00   then gradeStr = "A"
						elseif pct >= 70.00   then gradeStr = "B"
						elseif pct >= 60.00   then gradeStr = "C"
						elseif pct >= 0       then gradeStr = "D"
						end
						self:diffuse(HVColor.GetGradeColor(gradeStr))
					end
				end
			end
		},

		-- Combo counter (small, below accuracy)
		LoadFont("Common Normal") .. {
			Name = "Combo",
			InitCommand = function(self)
				self:halign(1):valign(0)
					:x(scoreboardW - 24)
					:y(14)
					:zoom(0.28)
					:diffuse(dimText)
					:settext("0x")
			end,
			ComboChangedMessageCommand = function(self, params)
				if params.Player ~= pn then return end
				
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(pn)
				if pss then
					local combo = pss:GetCurrentCombo()
					self:settext(tostring(combo) .. "x")
					
					-- Highlight on high combo
					if combo >= 100 then
						self:diffuse(accentColor)
					else
						self:diffuse(dimText)
					end
				end
			end
		},

		-- Row separator (except for last row)
		Def.Quad {
			InitCommand = function(self)
				if i < numPlayers then
					self:halign(0):valign(0)
						:y(rowSpacing - 4)
						:zoomto(scoreboardW - 16, 1)
						:diffuse(color("0.2,0.2,0.2,0.5"))
				else
					self:visible(false)
				end
			end
		}
	}
	
	t[#t + 1] = rowFrame
end

-- Rank update logic - reorder players by score
function t:UpdateRanks()
	local players = GAMESTATE:GetEnabledPlayers()
	local sorted = {}
	
	for _, pn in ipairs(players) do
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(pn)
		if pss then
			table.insert(sorted, {pn = pn, score = pss:GetWifeScore()})
		end
	end
	
	-- Sort by score descending
	table.sort(sorted, function(a, b) return a.score > b.score end)
	
	-- Update rank numbers
	for rank, data in ipairs(sorted) do
		local row = self:GetChild("PlayerRow_" .. (data.pn == PLAYER_1 and "P1" or "P2"))
		if row then
			local rankLabel = row:GetChild("Rank")
			if rankLabel then
				rankLabel:settext(tostring(rank))
			end
		end
	end
end

t.JudgmentMessageCommand = function(self)
	self:UpdateRanks()
end

return t
