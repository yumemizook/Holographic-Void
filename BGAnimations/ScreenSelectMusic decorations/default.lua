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
local panelY = 48                     -- Top margin (pushed down for header)
local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")
local bgCard = color("0.06,0.06,0.06,0.9")
local headerH = 40
local footerH = 40

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
			:zoomto(panelW, SCREEN_HEIGHT - headerH - footerH - 16)
			:diffuse(bgCard)
	end
}

-- Panel left border accent
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:halign(0):valign(0)
			:xy(panelX, panelY)
			:zoomto(2, SCREEN_HEIGHT - headerH - footerH - 16)
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
		SetCommand = function(self)
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
	},

	-- CDTitle
	Def.Sprite {
		Name = "CDTitle",
		InitCommand = function(self)
			-- Placed relative to the SongInfoFrame below instead
			self:visible(false)
		end,
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
		SetCommand = function(self)
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
		SetCommand = function(self)
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
				:maxwidth((panelW - 32 - 50) / 0.35) -- Leave space for CDTitle
				:diffuse(dimText)
		end,
		SetCommand = function(self)
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

	Def.ActorFrame {
		Name = "CDTitleBox",
		InitCommand = function(self)
			self:xy(panelW - 32, 22) -- Align to right edge
		end,
		SetCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song and song:HasCDTitle() then
				self:visible(true)
			else
				self:visible(false)
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		
		-- Real CDTitle Sprite with Hover tooltips attached natively
		UIElements.SpriteButton(1, 1, nil) .. {
			Name = "CDTitle",
			InitCommand = function(self)
				self:halign(1):valign(0)
			end,
			SetCommand = function(self)
				self:finishtweening()
				self.song = GAMESTATE:GetCurrentSong()
				if self.song and self.song:HasCDTitle() then
					self:visible(true)
					self:Load(self.song:GetCDTitlePath())
				else
					self:visible(false)
				end
				
				local maxDim = 32 -- Smaller to fit next to text
				local w, h = self:GetWidth(), self:GetHeight()
				if w > 0 and h > 0 then
					local scale = math.min(maxDim / w, maxDim / h)
					self:zoom(scale)
				end
				
				if isOver(self) then
					self:playcommand("ToolTip")
				end
			end,
			CurrentSongChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			ToolTipCommand = function(self)
				if isOver(self) then
					if self.song and self.song:HasCDTitle() and self:GetVisible() then
						local creditStr = "None defined"
						
						local steps = GAMESTATE:GetCurrentSteps(PLAYER_1)
						if steps then
							local ok, res = pcall(function() return steps:GetAuthorCredit() end)
							if ok and type(res) == "string" and res ~= "" then
								creditStr = res
							else
								local ok2, res2 = pcall(function() return steps:GetCredit() end)
								if ok2 and type(res2) == "string" and res2 ~= "" then
									creditStr = res2
								end
							end
						end
						
						if creditStr == "None defined" and self.song then
							local ok, res = pcall(function() return self.song:GetCredit() end)
							if ok and type(res) == "string" and res ~= "" then
								creditStr = res
							end
						end
						
						TOOLTIP:SetText(creditStr)
						TOOLTIP:Show()
					else
						TOOLTIP:Hide()
					end
				end
			end,
			MouseOverCommand = function(self)
				self:playcommand("ToolTip")
			end,
			MouseOutCommand = function(self)
				TOOLTIP:Hide()
			end
		}
	},

	-- Separator line
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):y(60)
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
		SetCommand = function(self)
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
		SetCommand = function(self)
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
local msdY = detailY + 45
local skillsets = {"Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}

t[#t + 1] = Def.ActorFrame {
	Name = "MSDFrame",
	InitCommand = function(self)
		self:xy(panelX + 16, msdY)
		local show = ThemePrefs.Get("HV_ShowMSD")
		self:visible(show == "true" or show == true)
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
		local show = ThemePrefs.Get("HV_ShowMSD")
		self:visible(show == "true" or show == true)
	end,

	LoadFont("Common Large") .. {
		Name = "MSD_Overall",
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.45):diffuse(mainText)
		end,
		SetCommand = function(self)
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
	},
	
	-- Top 3 Skillsets Displays
	Def.ActorFrame {
		Name = "TopSkillsetIcons",
		InitCommand = function(self)
			self:xy(120, -10) -- Raised higher and shifted right for bigger MSD
		end,
		
		-- Container for Icon 1
		Def.ActorFrame {
			Name = "IconContainer1",
			InitCommand = function(self) self:x(0) end,
			Def.Sprite { Name = "Img", InitCommand = function(self) self:y(0):zoom(0.7):visible(false) end },
			LoadFont("Common Normal") .. { Name = "Lbl", InitCommand = function(self) self:y(34):zoom(0.25):diffuse(dimText):visible(false) end }
		},
		-- Container for Icon 2
		Def.ActorFrame {
			Name = "IconContainer2",
			InitCommand = function(self) self:x(70) end,
			Def.Sprite { Name = "Img", InitCommand = function(self) self:y(0):zoom(0.7):visible(false) end },
			LoadFont("Common Normal") .. { Name = "Lbl", InitCommand = function(self) self:y(34):zoom(0.25):diffuse(dimText):visible(false) end }
		},
		-- Container for Icon 3
		Def.ActorFrame {
			Name = "IconContainer3",
			InitCommand = function(self) self:x(140) end,
			Def.Sprite { Name = "Img", InitCommand = function(self) self:y(0):zoom(0.7):visible(false) end },
			LoadFont("Common Normal") .. { Name = "Lbl", InitCommand = function(self) self:y(34):zoom(0.25):diffuse(dimText):visible(false) end }
		},
		
		SetCommand = function(self)
			local c1 = self:GetChild("IconContainer1")
			local c2 = self:GetChild("IconContainer2")
			local c3 = self:GetChild("IconContainer3")
			c1:GetChild("Img"):visible(false) c1:GetChild("Lbl"):visible(false)
			c2:GetChild("Img"):visible(false) c2:GetChild("Lbl"):visible(false)
			c3:GetChild("Img"):visible(false) c3:GetChild("Lbl"):visible(false)
			
			local steps = GAMESTATE:GetCurrentSteps()
			if not steps then return end
			local rate = getCurRateValue() or 1
			
			local vals = {}
			-- Indices 2 to 8 map to the 7 specific skillsets
			local ssNames = {"Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}
			for i, name in ipairs(ssNames) do
				local m = steps:GetMSD(rate, i + 1)
				if m > 0 then table.insert(vals, {name = name, val = m}) end
			end
			
			table.sort(vals, function(a, b) return a.val > b.val end)
			
			if #vals >= 1 then 
				c1:GetChild("Img"):Load(THEME:GetPathG("", "skillsets/" .. string.lower(vals[1].name) .. ".png")):visible(true)
				c1:GetChild("Lbl"):settext(vals[1].name):visible(true)
			end
			if #vals >= 2 then 
				c2:GetChild("Img"):Load(THEME:GetPathG("", "skillsets/" .. string.lower(vals[2].name) .. ".png")):visible(true)
				c2:GetChild("Lbl"):settext(vals[2].name):visible(true)
			end
			if #vals >= 3 then 
				c3:GetChild("Img"):Load(THEME:GetPathG("", "skillsets/" .. string.lower(vals[3].name) .. ".png")):visible(true)
				c3:GetChild("Lbl"):settext(vals[3].name):visible(true)
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
			if isHovering and ThemePrefs.Get("HV_ShowMSD") == "true" then
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
			SetCommand = function(self)
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
			SetCommand = function(self)
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
			SetCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if not song then self:settext("") return end
				local allSteps = (song.GetChartsOfCurrentGameType and song:GetChartsOfCurrentGameType()) or (song.GetStepsByStepsType and song:GetStepsByStepsType(GAMESTATE:GetCurrentStyle():GetStepsType()))
				if not allSteps then self:settext("") return end
				
				local showMSD = ThemePrefs.Get("HV_ShowMSD") == "true" or ThemePrefs.Get("HV_ShowMSD") == true
				
				for _, st in ipairs(allSteps) do
					if ToEnumShortString(st:GetDifficulty()) == dname then
						if showMSD then
							local msd = st:GetMSD(getCurRateValue(), 1)
							if msd and msd > 0 then
								self:settext(string.format("%.2f", msd))
								self:diffuse(HVColor.GetMSDRatingColor(msd))
							else
								self:settext("-")
								self:diffuse(dimText)
							end
						else
							-- Show chart meter if MSD is disabled
							local meter = st:GetMeter()
							self:settext(tostring(meter))
							self:diffuse(mainText)
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
		-- Removed self:visible() logic from here; frame must remain visible for PB Score.
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
		SetCommand = function(self)
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
		SetCommand = function(self)
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
		Name = "PBSSR",
		InitCommand = function(self)
			self:halign(0):valign(0):y(52):zoom(0.26):diffuse(mainText)
		end,
		SetCommand = function(self)
			local showMSD = ThemePrefs.Get("HV_ShowMSD") == "true" or ThemePrefs.Get("HV_ShowMSD") == true
			if not showMSD then
				self:settext("")
				return
			end
			
			local score = GetDisplayScore()
			if score then
				local ssr = score:GetSkillsetSSR("Overall")
				self:settext(string.format("SSR: %.2f", ssr))
				self:diffuse(HVColor.GetMSDRatingColor(ssr))
			else
				self:settext("")
			end
		end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
		CurrentStepsChangedMessageCommand = function(self) self:playcommand("Set") end
	},

	LoadFont("Common Normal") .. {
		Name = "PBJudges",
		InitCommand = function(self)
			self:halign(0):valign(0):y(66):zoom(0.22):diffuse(subText)
		end,
		SetCommand = function(self)
			local score = GetDisplayScore()
			if score then
				local marv = score:GetTapNoteScore("TapNoteScore_W1")
				local perf = score:GetTapNoteScore("TapNoteScore_W2")
				local gret = score:GetTapNoteScore("TapNoteScore_W3")
				local good = score:GetTapNoteScore("TapNoteScore_W4")
				local bad = score:GetTapNoteScore("TapNoteScore_W5")
				local miss = score:GetTapNoteScore("TapNoteScore_Miss")
				self:settext(string.format("Juds: %d / %d / %d / %d / %d / %d", marv, perf, gret, good, bad, miss))
			else
				self:settext("")
			end
		end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
		CurrentStepsChangedMessageCommand = function(self) self:playcommand("Set") end
	},

	LoadFont("Common Normal") .. {
		Name = "PBCBs",
		InitCommand = function(self)
			self:halign(0):valign(0):y(78):zoom(0.22):diffuse(subText)
		end,
		SetCommand = function(self)
			local score = GetDisplayScore()
			local steps = GAMESTATE:GetCurrentSteps()
			if score and steps then
				local bad = score:GetTapNoteScore("TapNoteScore_W5")
				local miss = score:GetTapNoteScore("TapNoteScore_Miss")
				local cbs = bad + miss
				self:settext(string.format("CBs/Breaks: %d", cbs))
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
		SetCommand = function(self)
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
		SetCommand = function(self)
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
-- COMPACT PROFILE + LOGIN (Right of Left Panel / Lower Half)
-- ============================================================
local compactProfileY = SCREEN_HEIGHT - footerH - 75
local compactProfileX = panelX + panelW + 16

t[#t + 1] = Def.ActorFrame {
	Name = "SmallProfileFrame",
	InitCommand = function(self)
		self:xy(compactProfileX, compactProfileY)
	end,

	-- Card background for profile
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-8, -8)
				:zoomto(180, 65)
				:diffuse(color("0.05,0.05,0.05,0.85"))
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):xy(-8, -8)
				:zoomto(2, 65)
				:diffuse(accentColor)
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
				local avatarPath = getAvatarPath(PLAYER_1)
				if avatarPath and avatarPath ~= "" and FILEMAN:DoesFileExist(avatarPath) then
					self:Load(avatarPath)
				else
					local fallback = "/Assets/Avatars/_fallback.png"
					if FILEMAN:DoesFileExist(fallback) then self:Load(fallback) end
				end
				self:scaletoclipped(49, 49):visible(true)
			else
				self:visible(false)
			end
		end,
		OnCommand = function(self) self:playcommand("Set") end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end
	},

	-- Profile name
	LoadFont("Common Normal") .. {
		Name = "ProfileName",
		InitCommand = function(self)
			self:halign(0):valign(0):x(56):y(0):zoom(0.40):diffuse(mainText)
		end,
		SetCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local name = profile:GetDisplayName()
				if name == "" then name = "Player" end
				if DLMAN:IsLoggedIn() then
					local onlineName = DLMAN:GetUsername()
					if onlineName ~= "" then name = onlineName end
				end
				self:settext(name)
			else
				self:settext("No Profile"):diffuse(dimText)
			end
		end,
		LoginMessageCommand = function(self) self:playcommand("Set") end,
		LogOutMessageCommand = function(self) self:playcommand("Set") end,
		OnlineUpdateMessageCommand = function(self) self:playcommand("Set") end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
		OnCommand = function(self) self:playcommand("Set") end
	},

	-- Rank (Top Right)
	LoadFont("Common Normal") .. {
		Name = "Rank",
		InitCommand = function(self)
			self:halign(1):valign(0):x(164):y(10):zoom(0.30)
		end,
		SetCommand = function(self)
			local showProfileStats = HV.ShowProfileStats()
			if not (showProfileStats == "true" or showProfileStats == true) then
				self:visible(false)
				return
			end
			
			if DLMAN:IsLoggedIn() then
				local rank = DLMAN:GetSkillsetRank("Overall")
				local rankColor = color("#A6A6A6")
				if rank and rank > 0 then
					if rank <= 10 then rankColor = color("#CFD198")
					elseif rank <= 50 then rankColor = color("#A0CFAB")
					elseif rank <= 100 then rankColor = color("#80C0CF")
					elseif rank <= 500 then rankColor = color("#D9D9D9")
					end
				else
					rankColor = color("#737373")
				end
				self:settextf("#%d", rank):diffuse(rankColor):visible(true)
			else
				self:settext("OFFLINE"):diffuse(dimText):visible(true)
			end
		end,
		LoginMessageCommand = function(self) self:playcommand("Set") end,
		LogOutMessageCommand = function(self) self:playcommand("Set") end,
		OnlineUpdateMessageCommand = function(self) self:playcommand("Set") end,
		OnCommand = function(self) self:playcommand("Set") end
	},

	-- MSD/Rating (Bottom Left)
	LoadFont("Common Large") .. {
		Name = "Rating",
		InitCommand = function(self)
			self:halign(0):valign(1):x(56):y(53):zoom(0.35)
		end,
		SetCommand = function(self)
			local showProfileStats = HV.ShowProfileStats()
			if not (showProfileStats == "true" or showProfileStats == true) then
				self:settext("")
				return
			end
			
			local rating = 0
			if DLMAN:IsLoggedIn() then
				rating = DLMAN:GetSkillsetRating("Overall")
			else
				local profile = PROFILEMAN:GetProfile(PLAYER_1)
				if profile then rating = profile:GetPlayerRating() end
			end
			if rating > 0 then
				self:settextf("%.2f", rating):diffuse(HVColor.GetMSDRatingColor(rating))
			else
				self:settext("-"):diffuse(dimText)
			end
		end,
		LoginMessageCommand = function(self) self:playcommand("Set") end,
		LogOutMessageCommand = function(self) self:playcommand("Set") end,
		OnlineUpdateMessageCommand = function(self) self:playcommand("Set") end,
		OnCommand = function(self) self:playcommand("Set") end
	},

	-- Stats (Bottom Right)
	LoadFont("Common Normal") .. {
		Name = "Stats",
		InitCommand = function(self)
			self:halign(1):valign(1):x(164):y(54):zoom(0.30):diffuse(subText)
		end,
		SetCommand = function(self)
			local showProfileStats = HV.ShowProfileStats()
			if not (showProfileStats == "true" or showProfileStats == true) then
				self:visible(false)
				return
			end
			
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local notesHit = profile:GetTotalTapsAndHolds()
				local sessionSecs = profile:GetTotalSessionSeconds()
				self:settextf("Notes: %d\nSession: %d:%02d", notesHit, math.floor(sessionSecs/60), sessionSecs%60):visible(true)
			else
				self:visible(false)
			end
		end,
		LoginMessageCommand = function(self) self:playcommand("Set") end,
		LogOutMessageCommand = function(self) self:playcommand("Set") end,
		OnlineUpdateMessageCommand = function(self) self:playcommand("Set") end,
		OnCommand = function(self) self:playcommand("Set") end
	},

	-- Integrated Login Button Area (Moved Above Profile)
	Def.ActorFrame {
		Name = "LoginButtonUI",
		InitCommand = function(self)
			self:xy(0, -22) -- Above the profile picture
		end,
		BeginCommand = function(self)
			if not DLMAN:IsLoggedIn() then
				local user = ThemePrefs.Get("HV_Username")
				local token = ThemePrefs.Get("HV_PasswordToken")
				if user and token and user ~= "" and token ~= "" then
					DLMAN:LoginWithToken(user, token)
				end
			end
		end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):zoomto(80, 24):diffuse(accentColor):diffusealpha(0.8)
			end,
			SetMessageCommand = function(self)
				if DLMAN:IsLoggedIn() then
					self:diffuse(color("0.1,0.28,0.15,0.8"))
				else
					self:diffuse(accentColor):diffusealpha(0.8)
				end
			end,
			LoginMessageCommand = function(self) self:playcommand("Set") end,
			LogOutMessageCommand = function(self) self:playcommand("Set") end,
		},
		LoadFont("Common Normal") .. {
			Name = "Txt",
			InitCommand = function(self) self:halign(0.5):xy(40, 0):zoom(0.3) end,
			SetMessageCommand = function(self)
				if DLMAN:IsLoggedIn() then
					self:settext("LOG OUT"):diffuse(color("0.65,1,0.72,1"))
				else
					self:settext("LOG IN"):diffuse(brightText)
				end
			end,
			LoginMessageCommand = function(self) self:playcommand("Set") end,
			LogOutMessageCommand = function(self) self:playcommand("Set") end,
			OnCommand = function(self) self:playcommand("Set") end
		}
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
	InitCommand = function(self) 
		-- Right of song info, above the banner 
		-- Banner is at panelX, panelY+12. Above banner is panelY
		self:xy(panelX + panelW - 40, panelY + 6) 
	end,
	LoadFont("Common Normal") .. {
		Name = "RateLabel",
		InitCommand = function(self) self:halign(1):valign(0):x(-2):zoom(0.35):diffuse(dimText):settext("RATE") end
	},
	LoadFont("Common Normal") .. {
		Name = "RateValue",
		InitCommand = function(self) self:halign(0):valign(0):zoom(0.4):diffuse(accentColor) end,
		SetCommand = function(self)
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

-- ============================================================
-- RADAR INTEGRATION
-- ============================================================
-- Add the radar component to visually track step characteristics
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		-- Centered directly above the profile card
		self:xy(compactProfileX + 85, compactProfileY - 80)
		self:zoom(1.0)
	end,
	LoadActor("radar.lua")
}

-- ============================================================
-- CREDIT TOOLTIP (Mouse-following)
-- ============================================================
local creditTooltipActor = nil
local creditTooltip = Def.ActorFrame {
	Name = "CreditTooltip",
	InitCommand = function(self)
		creditTooltipActor = self
		-- Use a very high Z index here
		self:visible(false):z(9000)
	end,
	Def.Quad {
		Name = "Bg",
		InitCommand = function(self)
			self:halign(0):valign(0):diffuse(color("0.05,0.05,0.05,0.95"))
		end
	},
	Def.Quad {
		Name = "Border",
		InitCommand = function(self)
			self:halign(0):valign(0):diffuse(accentColor):diffusealpha(0.5)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "Text",
		InitCommand = function(self)
			self:halign(0):valign(0):xy(8, 8):zoom(0.35):diffuse(mainText)
		end
	}
}
t[#t + 1] = creditTooltip

t[#t + 1] = Def.ActorFrame {
	Name = "CreditTooltipHandler",
	OnCommand = function(self)
		local function Update()
			if not creditTooltipActor then return end
			local song = GAMESTATE:GetCurrentSong()
			
			local hasCredit = false
			local cStr = ""
			if song then
				local ok, res = pcall(function() return song:GetCredit() end)
				if ok and type(res) == "string" and res ~= "" then
					hasCredit = true
					cStr = res
				end
			end
			
			-- Expand hover bounding box to include CDTitle placed near pack name
			local isHovering = IsMouseOver(panelX + 16, infoY, panelW - 16, 75)
			
			if isHovering and hasCredit then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				local wasHidden = not creditTooltipActor:GetVisible()
				creditTooltipActor:visible(true):xy(mx + 15, my + 15)
				
				if wasHidden then
					local txt = creditTooltipActor:GetChild("Text")
					local bg = creditTooltipActor:GetChild("Bg")
					local border = creditTooltipActor:GetChild("Border")
					
					txt:settext("Credit: " .. cStr)
					local w = txt:GetZoomedWidth() + 16
					local h = txt:GetZoomedHeight() + 16
					bg:zoomto(w, h)
					border:zoomto(w, 1)
				end
			else
				creditTooltipActor:visible(false)
			end
		end

		if self.SetUpdateFunction then
			self:SetUpdateFunction(Update)
		elseif self.SetUpdate then
			self:SetUpdate(Update)
		else
			self:queuecommand("Tick")
		end
		self.HV_Update = Update
	end,
	TickCommand = function(self)
		if self.HV_Update then self.HV_Update() end
		self:sleep(0.02):queuecommand("Tick")
	end
}

return t
