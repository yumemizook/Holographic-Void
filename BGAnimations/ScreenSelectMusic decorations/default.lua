--- Holographic Void: ScreenSelectMusic Decorations
-- Dashboard-style song info panel on the LEFT side with:
--   - Banner display
--   - Song title, artist, pack name
--   - MSD (difficulty calculator) ratings with hover skillset breakdown
--   - BPM, length, chart info
--   - Player profile + avatar at bottom-left
--   - Overall rating display with hover skillset tooltip

local t = Def.ActorFrame {
	Name = "SelectMusicDecorations",
	BeginCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_FirstPress" and IsMouseLeftClick(event.DeviceInput.button) then
				-- Check avatar click ONLY when overlay is hidden
				local overlay = self:GetChild("ProfileOverlay")
				if overlay and not overlay:GetVisible() then
					if IsMouseOver(panelX + 16, profileY, 40, 40) then
						MESSAGEMAN:Broadcast("ToggleProfileOverlay")
					end
				end
			end
		end)
	end
}

-- ClickDebug was moved to overlay/default.lua for better visibility

-- ============================================================
-- LAYOUT CONSTANTS
-- ============================================================
local panelX = 8                      -- Left panel left edge
local panelW = SCREEN_WIDTH * 0.36   -- Panel width
local panelY = 8                      -- Top margin
local accentColor = color("#5ABAFF")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.06,0.06,0.06,0.9")
local profileY = SCREEN_HEIGHT - 90

HV = HV or {}
HV.LoginState = HV.LoginState or {
	visible = false,
	focused = "email",
	email = "",
	password = "",
	status = "Tab / Enter to switch fields"
}
local loginState = HV.LoginState

local loginBtnW = 180
local loginBtnH = 28
local loginBtnCX = panelX + panelW / 2
local loginBtnCY = SCREEN_BOTTOM - 24

local function GetOnlineStatus()
	local connected = DLMAN:IsLoggedIn()
	if connected then
		return true, "EtternaOnline", "Online"
	end
	return false, "", "Offline"
end

local function DeviceBtnToChar(btn, shifted)
	local letter = btn:match("^DeviceButton_([a-z])$")
	if letter then return shifted and letter:upper() or letter end
	local digit = btn:match("^DeviceButton_([0-9])$")
	if digit then
		if shifted then
			local shiftMap = { ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%",
				["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")" }
			return shiftMap[digit] or digit
		end
		return digit
	end
	local symMap = {
		["DeviceButton_period"] = shifted and ">" or ".",
		["DeviceButton_comma"] = shifted and "<" or ",",
		["DeviceButton_slash"] = shifted and "?" or "/",
		["DeviceButton_backslash"] = shifted and "|" or "\\",
		["DeviceButton_minus"] = shifted and "_" or "-",
		["DeviceButton_equals"] = shifted and "+" or "=",
		["DeviceButton_semicolon"] = shifted and ":" or ";",
		["DeviceButton_apostrophe"] = shifted and "\"" or "'",
		["DeviceButton_left bracket"] = shifted and "{" or "[",
		["DeviceButton_right bracket"] = shifted and "}" or "]",
		["DeviceButton_grave"] = shifted and "~" or "`",
		["DeviceButton_space"] = " ",
	}
	return symMap[btn]
end

-- ============================================================
-- LEFT PANEL BACKGROUND
-- ============================================================
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(0):valign(0)
			:xy(panelX, panelY)
			:zoomto(panelW, SCREEN_HEIGHT - 16)
			:diffuse(bgCard)
	end
}

-- Panel left border accent
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(0):valign(0)
			:xy(panelX, panelY)
			:zoomto(2, SCREEN_HEIGHT - 16)
			:diffuse(accentColor):diffusealpha(0.3)
	end
}

-- ============================================================
-- BANNER AREA
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "BannerFrame",
	InitCommand = function(self)
		self:xy(panelX + panelW / 2, panelY + 12)
	end,

	-- Banner background placeholder
	Def.Quad {
		InitCommand = function(self)
			self:valign(0):zoomto(panelW - 24, (panelW - 24) / 3.2)
				:diffuse(color("0.04,0.04,0.04,1"))
		end
	},

	-- Banner sprite
	Def.Sprite {
		Name = "Banner",
		InitCommand = function(self)
			self:valign(0):scaletoclipped(panelW - 24, (panelW - 24) / 3.2)
		end,
		SetMessageCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local bnpath = song:GetBannerPath()
				if bnpath then
					self:Load(bnpath)
					self:scaletoclipped(panelW - 24, (panelW - 24) / 3.2)
					self:visible(true)
				else
					self:visible(false)
				end
			else
				self:visible(false)
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
}

local bannerH = (panelW - 24) / 3.2
local infoY = panelY + 12 + bannerH + 16

-- ============================================================
-- SONG INFO TEXT
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "SongInfoFrame",
	InitCommand = function(self)
		self:xy(panelX + 16, infoY)
	end,

	-- Song Title
	LoadFont("Zpix Normal") .. {
		Name = "SongTitle",
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.7)
				:maxwidth((panelW - 32) / 0.7)
				:diffuse(brightText)
		end,
		SetMessageCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:settext(song:GetDisplayMainTitle())
			else
				self:settext("")
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	},

	-- Artist
	LoadFont("Common Normal") .. {
		Name = "SongArtist",
		InitCommand = function(self)
			self:halign(0):valign(0):y(22):zoom(0.45)
				:maxwidth((panelW - 32) / 0.45)
				:diffuse(subText)
		end,
		SetMessageCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:settext(song:GetDisplayArtist())
			else
				self:settext("")
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	},

	-- Pack / Group Name
	LoadFont("Common Normal") .. {
		Name = "GroupName",
		InitCommand = function(self)
			self:halign(0):valign(0):y(40):zoom(0.35)
				:maxwidth((panelW - 32) / 0.35)
				:diffuse(dimText)
		end,
		SetMessageCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:settext(song:GetGroupName())
			else
				self:settext("")
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	},

	-- Separator line
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):y(58)
				:zoomto(panelW - 32, 1)
				:diffuse(color("0.18,0.18,0.18,1"))
		end
	}
}

-- ============================================================
-- CHART DETAILS (BPM, Length)
-- ============================================================
local detailY = infoY + 68

t[#t + 1] = Def.ActorFrame {
	Name = "ChartDetailsFrame",
	InitCommand = function(self)
		self:xy(panelX + 16, detailY)
	end,

	-- BPM Label
	LoadFont("Common Normal") .. {
		Name = "BPMLabel",
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.35):diffuse(dimText)
			self:settext("BPM")
		end
	},
	-- BPM Value
	LoadFont("Common Normal") .. {
		Name = "BPMValue",
		InitCommand = function(self)
			self:halign(0):valign(0):x(40):zoom(0.4):diffuse(mainText)
		end,
		SetMessageCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local bpms = song:GetDisplayBpms()
				if bpms[1] == bpms[2] then
					self:settext(string.format("%.0f", bpms[1]))
				else
					self:settext(string.format("%.0f-%.0f", bpms[1], bpms[2]))
				end
			else
				self:settext("---")
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	},

	-- Length Label
	LoadFont("Common Normal") .. {
		Name = "LengthLabel",
		InitCommand = function(self)
			self:halign(0):valign(0):x(panelW * 0.35):zoom(0.35):diffuse(dimText)
			self:settext("LENGTH")
		end
	},
	LoadFont("Common Normal") .. {
		Name = "LengthValue",
		InitCommand = function(self)
			self:halign(0):valign(0):x(panelW * 0.35 + 56):zoom(0.4):diffuse(mainText)
		end,
		SetMessageCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local len = song:MusicLengthSeconds()
				local mins = math.floor(len / 60)
				local secs = math.floor(len % 60)
				self:settext(string.format("%d:%02d", mins, secs))
				self:diffuse(HVColor.GetSongLengthColor(len))
			else
				self:settext("--:--")
				self:diffuse(mainText)
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	},

	-- Separator
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):y(20)
				:zoomto(panelW - 32, 1)
				:diffuse(color("0.12,0.12,0.12,1"))
		end
	}
}

-- ============================================================
-- MSD SKILLSET RATINGS (Simplified)
-- ============================================================
local msdY = detailY + 30
local skillsets = {"Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}

t[#t + 1] = Def.ActorFrame {
	Name = "MSDFrame",
	InitCommand = function(self)
		self:xy(panelX + 16, msdY)
	end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.35):diffuse(accentColor)
			self:settext("MSD RATINGS")
		end
	}
}

-- Create Overall Rating Row (Large)
t[#t + 1] = Def.ActorFrame {
	Name = "MSDRow_Overall",
	InitCommand = function(self)
		self:xy(panelX + 16, msdY + 24)
	end,

	LoadFont("Common Normal") .. {
		Name = "MSD_Overall",
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(1.0):diffuse(mainText)
		end,
		SetMessageCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local steps = GAMESTATE:GetCurrentSteps()
				if steps then
					local msd = steps:GetMSD(getCurRateValue(), 1) -- 1 is Overall
					if msd and msd > 0 then
						self:settext(string.format("%.2f", msd))
						self:diffuse(HVColor.GetMSDRatingColor(msd))
					else
						self:settext("-")
						self:diffuse(dimText)
					end
				else
					self:settext("-")
					self:diffuse(dimText)
				end
			else
				self:settext("-")
				self:diffuse(dimText)
			end
		end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
		CurrentStepsChangedMessageCommand = function(self) self:playcommand("Set") end,
		CurrentRateChangedMessageCommand = function(self) self:playcommand("Set") end
	}
}

-- ============================================================
-- MSD SKILLSET TOOLTIP (Mouse-following)
-- ============================================================
local msdTooltipW = 185
local msdTooltipRowH = 24
local msdTooltipH = #skillsets * msdTooltipRowH + 10

local msdTooltipActor = nil
local msdTooltip = Def.ActorFrame {
	Name = "MSDTooltip",
	InitCommand = function(self)
		msdTooltipActor = self
		self:visible(false)
	end,
	-- Background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(msdTooltipW, msdTooltipH):diffuse(color("0.05,0.05,0.05,0.95"))
		end
	},
	-- Border
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(msdTooltipW, 1):diffuse(accentColor):diffusealpha(0.5)
		end
	}
}

-- Add rows to MSD tooltip
for i, ss in ipairs(skillsets) do
	msdTooltip[#msdTooltip + 1] = Def.ActorFrame {
		InitCommand = function(self) self:xy(8, 8 + (i - 1) * msdTooltipRowH) end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):zoom(0.32):diffuse(subText):settext(ss) end
		},
		LoadFont("Common Normal") .. {
			Name = "Val",
			InitCommand = function(self) self:halign(1):x(msdTooltipW - 16):zoom(0.4):diffuse(mainText) end,
			SetCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if song then
					local steps = GAMESTATE:GetCurrentSteps()
					if steps then
						local msd = steps:GetMSD(getCurRateValue(), i)
						if msd and msd > 0 then
							self:settext(string.format("%.2f", msd)):diffuse(HVColor.GetMSDRatingColor(msd))
						else self:settext("-") end
					else self:settext("-") end
				else self:settext("-") end
			end
		}
	}
end
t[#t + 1] = msdTooltip

-- Mouse Handler for MSD Tooltip
t[#t + 1] = Def.ActorFrame {
	Name = "MSDTooltipHandler",
	OnCommand = function(self)
		local function Update()
			if not msdTooltipActor then return end
			-- Use IsMouseOver for consistent coordinate units
			-- Hitbox for the large Overall rating (panelX+16 to panelX+120, msdY+20 to msdY+90)
			local isHovering = IsMouseOver(panelX + 10, msdY + 20, 110, 70)
			if isHovering then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				-- Check visibility BEFORE setting it to trigger updates correctly
				local wasHidden = not msdTooltipActor:GetVisible()
				msdTooltipActor:visible(true):xy(mx + 15, my + 15)
				if wasHidden then
					msdTooltipActor:playcommand("Set")
				end
			else
				msdTooltipActor:visible(false)
			end
		end

		if self.SetUpdateFunction then
			self:SetUpdateFunction(Update)
		elseif self.SetUpdate then
			self:SetUpdate(Update)
		else
			self:queuecommand("Tick")
		end
		-- Attach update function to satisfy TickCommand without re-running On
		self.HV_Update = Update
	end,
	TickCommand = function(self)
		if self.HV_Update then self.HV_Update() end
		self:sleep(0.02):queuecommand("Tick")
	end
}

-- ============================================================
-- PLAYER PROFILE + AVATAR (bottom-left corner)
-- ============================================================

t[#t + 1] = Def.ActorFrame {
	Name = "ProfileStatsFrame",
	InitCommand = function(self)
		self:xy(panelX + 16, profileY)
	end,

	-- Separator
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):y(-14)
				:zoomto(panelW - 32, 1)
				:diffuse(color("0.18,0.18,0.18,1"))
		end
	},

	-- Avatar
	Def.Sprite {
		Name = "PlayerAvatar",
		InitCommand = function(self)
			self:halign(0):valign(0):y(0)
		end,
		SetCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local avatarPath = nil
				if profile.GetAvatarPath then avatarPath = profile:GetAvatarPath() end
				if avatarPath and avatarPath ~= "" and FILEMAN:DoesFileExist(avatarPath) then
					self:Load(avatarPath)
				else
					local fallback = "/Assets/Avatars/_fallback.png"
					if FILEMAN:DoesFileExist(fallback) then self:Load(fallback) end
				end
				self:scaletoclipped(40, 40):visible(true)
			else
				self:visible(false)
			end
		end,
		OnCommand = function(self) self:playcommand("Set") end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end
	},

	-- Profile name + Online Status
	LoadFont("Common Normal") .. {
		Name = "ProfileName",
		InitCommand = function(self)
			self:halign(0):valign(0):x(48):y(0):zoom(0.4):diffuse(mainText)
		end,
		SetMessageCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local name = profile:GetDisplayName()
				if name == "" then name = "Player" end
				if DLMAN:IsLoggedIn() then
					local onlineName = DLMAN:GetUsername()
					if onlineName ~= "" then name = onlineName end
					self:settext(name .. " · ONLINE"):diffuse(color("0.65,1,0.72,1"))
				else
					self:settext(name .. " · OFFLINE"):diffuse(dimText)
				end
			else
				self:settext("No Profile"):diffuse(dimText)
			end
		end,
		LoginMessageCommand = function(self) self:playcommand("Set") end,
		LogOutMessageCommand = function(self) self:playcommand("Set") end,
		OnlineUpdateMessageCommand = function(self) self:playcommand("Set") end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end
	},

	-- Online Rank/Rating
	LoadFont("Common Normal") .. {
		Name = "OnlineStats",
		InitCommand = function(self)
			self:halign(0):valign(0):x(48):y(14):zoom(0.28):diffuse(subText)
		end,
		SetMessageCommand = function(self)
			if DLMAN:IsLoggedIn() then
				local rank = DLMAN:GetSkillsetRank("Overall")
				local rating = DLMAN:GetSkillsetRating("Overall")
				self:settextf("Rank: #%d (Rating: %.2f)", rank, rating):visible(true)
			else
				self:visible(false)
			end
		end,
		LoginMessageCommand = function(self) self:playcommand("Set") end,
		LogOutMessageCommand = function(self) self:playcommand("Set") end,
		OnlineUpdateMessageCommand = function(self) self:playcommand("Set") end
	},

	-- Total Hits
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):x(48):y(28):zoom(0.26):diffuse(dimText) end,
		SetMessageCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile and profile.GetTotalTapNoteScores then
				local w1 = profile:GetTotalTapNoteScores("TapNoteScore_W1")
				local w2 = profile:GetTotalTapNoteScores("TapNoteScore_W2")
				local w3 = profile:GetTotalTapNoteScores("TapNoteScore_W3")
				local w4 = profile:GetTotalTapNoteScores("TapNoteScore_W4")
				local w5 = profile:GetTotalTapNoteScores("TapNoteScore_W5")
				self:settextf("Total Hits: %d", w1 + w2 + w3 + w4 + w5)
			else self:settext("") end
		end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end
	},

	-- Play Time
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):x(48):y(38):zoom(0.26):diffuse(dimText) end,
		SetMessageCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile and profile.GetTotalSecondsPlayed then
				local secs = profile:GetTotalSecondsPlayed()
				local hours, mins, s = math.floor(secs / 3600), math.floor((secs % 3600) / 60), math.floor(secs % 60)
				self:settextf("Play Time: %02d:%02d:%02d", hours, mins, s)
			else self:settext("") end
		end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end
	},

	-- Overall rating (Large, right)
	LoadFont("Common Normal") .. {
		Name = "OverallRating",
		InitCommand = function(self) self:halign(1):valign(0):x(panelW - 32):y(16):zoom(0.5):diffuse(accentColor) end,
		SetMessageCommand = function(self)
			local rating = 0
			if DLMAN:IsLoggedIn() then rating = DLMAN:GetSkillsetRating("Overall")
			else
				local profile = PROFILEMAN:GetProfile(PLAYER_1)
				if profile then rating = profile:GetPlayerRating() end
			end
			if rating > 0 then
				self:settext(string.format("%.2f", rating)):diffuse(HVColor.GetMSDRatingColor(rating))
			else self:settext("--"):diffuse(accentColor) end
		end,
		LoginMessageCommand = function(self) self:playcommand("Set") end,
		LogOutMessageCommand = function(self) self:playcommand("Set") end,
		OnlineUpdateMessageCommand = function(self) self:playcommand("Set") end
	},

	-- Play count (top-right)
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(1):valign(0):x(panelW - 32):y(0):zoom(0.32):diffuse(subText) end,
		SetMessageCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then self:settext(tostring(profile:GetNumTotalSongsPlayed()) .. " plays")
			else self:settext("") end
		end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end
	}
}

-- ============================================================
-- PROFILE OVERLAY
-- ============================================================
local overlayW, overlayH = SCREEN_WIDTH * 0.8, SCREEN_HEIGHT * 0.7
local colW, scorePageSize = overlayW / 3, 10

-- Define columns as local variables first
local skillsetCol = Def.ActorFrame { 
	Name = "SkillsetColumn", InitCommand = function(self) self:x(-colW) end,
	LoadFont("Common Normal") .. { InitCommand = function(self) self:y(-overlayH / 2 + 70):zoom(0.4):diffuse(accentColor):settext("SKILLSETS") end }
}
local topScoresCol = Def.ActorFrame { 
	Name = "TopScoresColumn", InitCommand = function(self) self:x(0) end,
	LoadFont("Common Normal") .. { InitCommand = function(self) self:y(-overlayH / 2 + 70):zoom(0.4):diffuse(accentColor):settext("TOP SCORES (ONLINE)") end }
}
local recentScoresCol = Def.ActorFrame { 
	Name = "RecentScoresColumn", InitCommand = function(self) self:x(colW) end,
	LoadFont("Common Normal") .. { InitCommand = function(self) self:y(-overlayH / 2 + 70):zoom(0.4):diffuse(accentColor):settext("RECENT SCORES") end }
}

-- Skillset Rows in Overlay
for i, ss in ipairs(skillsets) do
	skillsetCol[#skillsetCol + 1] = Def.ActorFrame {
		InitCommand = function(self) self:y(-overlayH / 2 + 100 + (i * 22)) end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:halign(0):x(-colW / 2 + 20):zoom(0.35):diffuse(subText):settext(ss) end
		},
		LoadFont("Common Normal") .. {
			Name = "Val",
			InitCommand = function(self) self:halign(1):x(colW / 2 - 20):zoom(0.4):diffuse(mainText) end,
			UpdateOverlaySkillsetsMessageCommand = function(self)
				local val = 0
				if DLMAN:IsLoggedIn() then 
					val = DLMAN:GetSkillsetRating(ss)
				else
					local profile = PROFILEMAN:GetProfile(PLAYER_1)
					if profile then
						if ss == "Overall" then
							val = profile:GetPlayerRating()
						else
							-- Profile index mapping: Stream(0), JS(1), ... Tech(6)
							-- Our loop: Overall(1), Stream(2) ... Tech(8)
							-- So engine index = i - 2
							local engineSS = i - 2
							if engineSS >= 0 and profile.GetPlayerSkillsetRating then
								local ok, res = pcall(function() return profile:GetPlayerSkillsetRating(engineSS) end)
								if ok then val = res or 0 end
							end
						end
					end
				end
				self:settext(string.format("%.2f", val)):diffuse(HVColor.GetMSDRatingColor(val))
			end
		}
	}
end

-- Score Rows Logic
local function AddScoreRows(column, namePrefix)
	for i = 1, scorePageSize do
		column[#column + 1] = Def.ActorFrame {
			Name = namePrefix .. i,
			InitCommand = function(self) self:y(-overlayH / 2 + 100 + (i * 28)) end,
			LoadFont("Common Normal") .. {
				Name = "Title",
				InitCommand = function(self) self:halign(0):x(-colW / 2 + 10):y(-6):zoom(0.28):diffuse(mainText):maxwidth(colW * 2.5) end
			},
			LoadFont("Common Normal") .. {
				Name = "Details",
				InitCommand = function(self) self:halign(0):x(-colW / 2 + 10):y(6):zoom(0.22):diffuse(dimText) end
			},
			LoadFont("Common Normal") .. {
				Name = "Score",
				InitCommand = function(self) self:halign(1):x(colW / 2 - 10):zoom(0.32):diffuse(accentColor) end
			}
		}
	end
end
AddScoreRows(topScoresCol, "Top")
AddScoreRows(recentScoresCol, "Recent")

local profileOverlay = Def.ActorFrame {
	Name = "ProfileOverlay",
	InitCommand = function(self)
		self.topPage = 1
		self.recentPage = 1
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	-- Dark Background (Dim the rest of the screen)
	Def.Quad {
		InitCommand = function(self) self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,0.85")) end,
		BeginCommand = function(self)
			SCREENMAN:GetTopScreen():AddInputCallback(function(event)
				if self:GetParent() and self:GetParent():GetVisible() and event.type == "InputEventType_FirstPress" then
					if IsMouseLeftClick(event.DeviceInput.button) and not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
						MESSAGEMAN:Broadcast("ToggleProfileOverlay")
					elseif event.DeviceInput.button == "DeviceButton_left" then
						MESSAGEMAN:Broadcast("PrevScorePage")
					elseif event.DeviceInput.button == "DeviceButton_right" then
						MESSAGEMAN:Broadcast("NextScorePage")
					end
				end
			end)
		end
	},
	-- Main Panel
	Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(bgCard):diffusealpha(0.95) end },
	-- Header
	LoadFont("Zpix Normal") .. {
		InitCommand = function(self) self:y(-overlayH / 2 + 30):zoom(0.8):diffuse(brightText):settext("PLAYER PROFILE") end
	},
	-- Close Hint
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:y(overlayH / 2 - 20):zoom(0.3):diffuse(dimText):settext("Click outside or Avatar to close · Use Left/Right for pages") end
	},

	-- Columns
	skillsetCol,
	topScoresCol,
	recentScoresCol,

	-- Commands
	ToggleProfileOverlayMessageCommand = function(self)
		if not self then return end
		local isVisible = self:GetVisible()
		self:visible(not isVisible)
		if not isVisible then 
			self:playcommand("UpdateAllScores") 
		end
	end,

	UpdateAllScoresCommand = function(self)
		if not self or not self.GetChild then return end
		
		local topScores, recentScores = {}, {}
		if DLMAN:IsLoggedIn() then
			local okTop, resTop = pcall(function() return DLMAN:GetTopScores() end)
			if okTop then topScores = resTop or {} end
			local okRec, resRec = pcall(function() return DLMAN:GetRecentScores() end)
			if okRec then recentScores = resRec or {} end
		end

		local function UpdateList(colName, scores, page, prefix)
			local col = self:GetChild(colName)
			if not col or not col.GetChild then return end
			local p = page or 1
			local start = (p - 1) * scorePageSize
			for i = 1, scorePageSize do
				local row = col:GetChild(prefix .. i)
				if row then
					local score = scores[start + i]
					if score then
						row:visible(true)
						local songTitle = (score.GetSongTitle and score:GetSongTitle()) or "Unknown Song"
						local diff = (score.GetDifficulty and ToEnumShortString(score:GetDifficulty())) or "Unknown"
						local rate = (score.GetMusicRate and score:GetMusicRate()) or 1.0
						local date = (score.GetDate and score:GetDate()) or "N/A"
						local wife = (score.GetWifeScore and score:GetWifeScore()) or 0
						
						local titleChild = row:GetChild("Title")
						local detailsChild = row:GetChild("Details")
						local scoreChild = row:GetChild("Score")
						if titleChild then titleChild:settext(songTitle) end
						if detailsChild then detailsChild:settext(string.format("%s · %.2f · %s", diff, rate, date)) end
						if scoreChild then scoreChild:settext(string.format("%.2f%%", wife * 100)) end
					else row:visible(false) end
				end
			end
		end
		UpdateList("TopScoresColumn", topScores, self.topPage, "Top")
		UpdateList("RecentScoresColumn", recentScores, self.recentPage, "Recent")
		
		-- Propagate update to skillset rows via local message to avoid tree walking
		MESSAGEMAN:Broadcast("UpdateOverlaySkillsets")
	end,

	NextScorePageMessageCommand = function(self)
		self.topPage = self.topPage + 1
		self.recentPage = self.recentPage + 1
		self:playcommand("UpdateAllScores")
	end,

	PrevScorePageMessageCommand = function(self)
		self.topPage = math.max(1, self.topPage - 1)
		self.recentPage = math.max(1, self.recentPage - 1)
		self:playcommand("UpdateAllScores")
	end
}

t[#t + 1] = profileOverlay

-- ============================================================
-- MUSIC RATE DISPLAY
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "RateDisplay",
	InitCommand = function(self) self:xy(SCREEN_WIDTH - 180, 10) end,
	LoadFont("Common Normal") .. {
		InitCommand = function(self) self:halign(0):valign(0):zoom(0.45):diffuse(mainText) end,
		SetMessageCommand = function(self)
			local rate = getCurRateString()
			self:settext("Rate: " .. (rate or "1.0x"))
		end,
		CurrentRateChangedMessageCommand = function(self) self:playcommand("Set") end
	}
}

return t
