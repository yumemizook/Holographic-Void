--- Holographic Void: ScreenSelectMusic Decorations
-- Dashboard-style song info panel on the LEFT side with:
--   - Banner display
--   - Song title, artist, pack name
--   - MSD (difficulty calculator) ratings with hover skillset breakdown
--   - BPM, length, chart info
--   - Player profile + avatar at bottom-left
--   - Overall rating display with hover skillset tooltip

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

local profileOverlayActor = nil -- Local reference for the overlay

local t = Def.ActorFrame {
	Name = "SelectMusicDecorations"
}

-- ClickDebug was moved to overlay/default.lua for better visibility

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
				local rate = getCurRateValue() or 1
				local b1 = bpms[1] * rate
				local b2 = bpms[2] * rate
				if math.abs(b1 - b2) < 1 then
					self:settext(string.format("%.0f", b1))
				else
					self:settext(string.format("%.0f-%.0f", b1, b2))
				end
			else
				self:settext("---")
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		CurrentRateChangedMessageCommand = function(self)
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
				local rate = getCurRateValue() or 1
				if rate > 0 then len = len / rate end
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
		end,
		CurrentRateChangedMessageCommand = function(self)
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
-- DIFFICULTY SELECTOR TABS (Vertical, right of sidebar)
-- ============================================================
local diffSelectorY = msdY + 80
local diffTabW = 70
local diffTabH = 22
local diffNames = {"Beginner", "Easy", "Medium", "Hard", "Challenge", "Edit"}
local diffShort = {"BG", "EZ", "MD", "HD", "CH", "ED"}
local diffSelectorX = panelX + panelW + 14
local diffSelectorTopY = panelY + 8

t[#t + 1] = Def.ActorFrame {
	Name = "DifficultySelector",
	InitCommand = function(self)
		self:xy(diffSelectorX, diffSelectorTopY)
	end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.28):diffuse(accentColor)
			self:settext("CHART")
		end
	}
}

for di, dname in ipairs(diffNames) do
	t[#t + 1] = Def.ActorFrame {
		Name = "DiffTab_" .. dname,
		InitCommand = function(self)
			self:xy(diffSelectorX, diffSelectorTopY + 16 + (di - 1) * (diffTabH + 3))
		end,

		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(diffTabW, diffTabH)
					:diffuse(color("0.08,0.08,0.08,1"))
			end,
			SetMessageCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if not song then self:diffusealpha(0.3) return end
				local allSteps = (song.GetChartsOfCurrentGameType and song:GetChartsOfCurrentGameType()) or (song.GetStepsByStepsType and song:GetStepsByStepsType(GAMESTATE:GetCurrentStyle():GetStepsType()))
				if not allSteps then self:diffusealpha(0.3) return end
				local found = false
				for _, st in ipairs(allSteps) do
					if ToEnumShortString(st:GetDifficulty()) == dname then
						found = true
						break
					end
				end
				if not found then
					self:diffuse(color("0.08,0.08,0.08,1")):diffusealpha(0.15)
				else
					local curSteps = GAMESTATE:GetCurrentSteps()
					if curSteps and ToEnumShortString(curSteps:GetDifficulty()) == dname then
						self:diffuse(HVColor.Difficulty[dname] or accentColor):diffusealpha(0.4)
					else
						self:diffuse(color("0.08,0.08,0.08,1")):diffusealpha(1)
					end
				end
			end,
			CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
			CurrentStepsChangedMessageCommand = function(self) self:playcommand("Set") end
		},

		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:halign(0):valign(0.5)
					:xy(6, diffTabH / 2)
					:zoom(0.26):diffuse(mainText)
				self:settext(diffShort[di])
			end,
			SetMessageCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if not song then self:diffusealpha(0.3) return end
				local allSteps = (song.GetChartsOfCurrentGameType and song:GetChartsOfCurrentGameType()) or (song.GetStepsByStepsType and song:GetStepsByStepsType(GAMESTATE:GetCurrentStyle():GetStepsType()))
				if not allSteps then self:diffusealpha(0.3) return end
				local found = false
				for _, st in ipairs(allSteps) do
					if ToEnumShortString(st:GetDifficulty()) == dname then
						found = true
						break
					end
				end
				self:diffusealpha(found and 1 or 0.2)
			end,
			CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
			CurrentStepsChangedMessageCommand = function(self) self:playcommand("Set") end
		},

		LoadFont("Common Normal") .. {
			Name = "MSDVal",
			InitCommand = function(self)
				self:halign(1):valign(0.5)
					:xy(diffTabW - 6, diffTabH / 2)
					:zoom(0.26):diffuse(dimText)
			end,
			SetMessageCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if not song then self:settext("") return end
				local allSteps = (song.GetChartsOfCurrentGameType and song:GetChartsOfCurrentGameType()) or (song.GetStepsByStepsType and song:GetStepsByStepsType(GAMESTATE:GetCurrentStyle():GetStepsType()))
				if not allSteps then self:settext("") return end
				for _, st in ipairs(allSteps) do
					if ToEnumShortString(st:GetDifficulty()) == dname then
						local msd = st:GetMSD(getCurRateValue(), 1)
						if msd and msd > 0 then
							self:settext(string.format("%.1f", msd))
							self:diffuse(HVColor.GetMSDRatingColor(msd))
						else
							self:settext("-")
							self:diffuse(dimText)
						end
						return
					end
				end
				self:settext("")
			end,
			CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
			CurrentStepsChangedMessageCommand = function(self) self:playcommand("Set") end,
			CurrentRateChangedMessageCommand = function(self) self:playcommand("Set") end
		}
	}
end

-- Difficulty selector click handler (vertical layout)
t[#t + 1] = Def.ActorFrame {
	Name = "DiffSelectorClickHandler",
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end
			local btn = event.DeviceInput.button
			if btn ~= "DeviceButton_left mouse button" then return end
			local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			local song = GAMESTATE:GetCurrentSong()
			if not song then return end
			for di2, dname2 in ipairs(diffNames) do
				local tx = diffSelectorX
				local ty = diffSelectorTopY + 16 + (di2 - 1) * (diffTabH + 3)
				if mx >= tx and mx <= tx + diffTabW and my >= ty and my <= ty + diffTabH then
					local allSteps = (song.GetChartsOfCurrentGameType and song:GetChartsOfCurrentGameType()) or (song.GetStepsByStepsType and song:GetStepsByStepsType(GAMESTATE:GetCurrentStyle():GetStepsType()))
					if allSteps then
						for _, st in ipairs(allSteps) do
							if ToEnumShortString(st:GetDifficulty()) == dname2 then
								GAMESTATE:SetCurrentSteps(PLAYER_1, st)
								return true
							end
						end
					end
				end
			end
		end)
	end
}

-- ============================================================
-- PERSONAL BEST DISPLAY (Under MSD rating in sidebar)
-- ============================================================
local pbY = msdY + 70

t[#t + 1] = Def.ActorFrame {
	Name = "PersonalBestFrame",
	InitCommand = function(self)
		self:xy(panelX + 16, pbY)
	end,

	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):y(-4)
				:zoomto(panelW - 32, 1)
				:diffuse(color("0.12,0.12,0.12,1"))
		end
	},

	LoadFont("Common Normal") .. {
		Name = "PBHeader",
		InitCommand = function(self)
			self:halign(0):valign(0):y(2):zoom(0.28):diffuse(accentColor)
			self:settext("PERSONAL BEST")
		end
	},

	LoadFont("Common Normal") .. {
		Name = "PBScore",
		InitCommand = function(self)
			self:halign(0):valign(0):y(18):zoom(0.55):diffuse(brightText)
		end,
		SetMessageCommand = function(self)
			local score = GetDisplayScore()
			if score then
				local wifePct = score:GetWifeScore() * 100
				if wifePct >= 99 then
					self:settext(string.format("%.4f%%", wifePct))
				else
					self:settext(string.format("%.2f%%", wifePct))
				end
				self:diffuse(brightText)
			else
				self:settext("No Score")
				self:diffuse(dimText)
			end
		end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
		CurrentStepsChangedMessageCommand = function(self) self:playcommand("Set") end
	},

	LoadFont("Common Normal") .. {
		Name = "PBDetails",
		InitCommand = function(self)
			self:halign(0):valign(0):y(36):zoom(0.26):diffuse(subText)
		end,
		SetMessageCommand = function(self)
			local score = GetDisplayScore()
			if score then
				local gradeShort = ToEnumShortString(score:GetWifeGrade())
				local grade = THEME:GetString("Grade", gradeShort)
				local rate = score:GetMusicRate()
				local date = score:GetDate()
				self:settext(string.format("%s · %.2fx · %s", grade, rate, date))
				self:diffuse(subText)
			else
				self:settext("")
			end
		end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
		CurrentStepsChangedMessageCommand = function(self) self:playcommand("Set") end
	},

	LoadFont("Common Normal") .. {
		Name = "PBGrade",
		InitCommand = function(self)
			self:halign(1):valign(0):x(panelW - 32):y(16):zoom(0.5)
		end,
		SetMessageCommand = function(self)
			local score = GetDisplayScore()
			if score then
				local gradeStr = ToEnumShortString(score:GetWifeGrade())
				self:settext(THEME:GetString("Grade", gradeStr))
				self:diffuse(HVColor.GetGradeColor(gradeStr))
			else
				self:settext("")
			end
		end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
		CurrentStepsChangedMessageCommand = function(self) self:playcommand("Set") end
	},

	-- Clear Type Lamp
	LoadFont("Common Normal") .. {
		Name = "PBClearType",
		InitCommand = function(self)
			self:halign(1):valign(0):x(panelW - 32):y(40):zoom(0.24)
		end,
		SetMessageCommand = function(self)
			local score = GetDisplayScore()
			if score then
				local ct = getDetailedClearType(score)
				self:settext(THEME:GetString("ClearTypes", ct))
				self:diffuse(HVColor.GetClearTypeColor(ct))
			else
				self:settext("")
			end
		end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
		CurrentStepsChangedMessageCommand = function(self) self:playcommand("Set") end
	}
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
				if profile.GetAvatarPath and type(profile.GetAvatarPath) == "function" then 
					avatarPath = profile:GetAvatarPath() 
				end
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
-- profileOverlay was moved to overlay/default.lua for better layering

-- ============================================================
-- MUSIC RATE DISPLAY
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "RateDisplay",
	InitCommand = function(self) self:xy(panelX + 16, detailY + 52) end,
	LoadFont("Common Normal") .. {
		Name = "RateLabel",
		InitCommand = function(self) self:halign(0):valign(0):zoom(0.35):diffuse(dimText):settext("RATE") end
	},
	LoadFont("Common Normal") .. {
		Name = "RateValue",
		InitCommand = function(self) self:halign(0):valign(0):x(40):zoom(0.4):diffuse(accentColor) end,
		SetMessageCommand = function(self)
			local rate = getCurRateValue() or 1
			if math.abs(rate - 1.0) < 0.005 then
				self:settext("1.0x"):diffuse(mainText)
			else
				self:settext(string.format("%.2fx", rate)):diffuse(accentColor)
			end
		end,
		CurrentRateChangedMessageCommand = function(self) self:playcommand("Set") end
	}
}

return t
