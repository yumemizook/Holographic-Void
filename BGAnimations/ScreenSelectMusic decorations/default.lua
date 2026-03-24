--- Holographic Void: ScreenSelectMusic Decorations

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

local profileOverlayActor = nil

local t = Def.ActorFrame {
	Name = "SelectMusicDecorations"
}


HV.LoginState = HV.LoginState or {
	visible = false,
	focused = "email",
	email = "",
	password = "",
	status = "Tab / Enter to switch fields"
}
local loginState = HV.LoginState

-- Centralized Data Cache
HV.CurrentSongData = {
	song = nil,
	steps = nil,
	rate = 1.0,
	allSteps = {},
	diffAvailability = {}, -- {Beginner = true, ...}
	diffMeters = {},       -- {Beginner = 10, ...}
	diffMSDs = {},         -- {Beginner = 25.4, ...}
	skillsetMSDs = {},     -- {1=Overall, 2=Stream, ...}
	pbScore = nil,
	pbSSR = 0,
}

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
-- SELECTION MANAGER (Centralized Logic)
-- ============================================================
t[#t + 1] = Def.Actor {
	Name = "SelectionManager",
	InitCommand = function(self)
		self:playcommand("UpdateData")
	end,
	UpdateDataCommand = function(self)
		local data = HV.CurrentSongData
		data.song = GAMESTATE:GetCurrentSong()
		data.steps = GAMESTATE:GetCurrentSteps()
		data.rate = getCurRateValue() or 1.0
	end,
	
	UpdateHeavyDataCommand = function(self)
		local data = HV.CurrentSongData
		if data.song then
			data.allSteps = (data.song.GetChartsOfCurrentGameType and data.song:GetChartsOfCurrentGameType()) 
				or (data.song.GetStepsByStepsType and data.song:GetStepsByStepsType(GAMESTATE:GetCurrentStyle():GetStepsType())) 
				or {}
			
			-- Diff availability and meters (O(N) once per song)
			data.diffAvailability = {}
			data.diffMeters = {}
			data.diffMSDs = {}
			for _, st in ipairs(data.allSteps) do
				local diff = ToEnumShortString(st:GetDifficulty())
				data.diffAvailability[diff] = true
				data.diffMeters[diff] = st:GetMeter()
				data.diffMSDs[diff] = st:GetMSD(data.rate, 1) or 0
			end
			
			-- Current Steps MSDs
			if data.steps then
				data.skillsetMSDs = {}
				for i = 1, 8 do
					data.skillsetMSDs[i] = data.steps:GetMSD(data.rate, i) or 0
				end
				data.pbScore = GetDisplayScore()
				if data.pbScore then
					data.pbSSR = data.pbScore:GetSkillsetSSR("Overall")
				else
					data.pbSSR = 0
				end
			else
				data.skillsetMSDs = {}
				data.pbScore = nil
				data.pbSSR = 0
			end
		else
			data.allSteps = {}
			data.diffAvailability = {}
			data.diffMeters = {}
			data.diffMSDs = {}
			data.skillsetMSDs = {}
			data.pbScore = nil
			data.pbSSR = 0
		end
	end,
	
	CurrentSongChangedMessageCommand = function(self)
		self:playcommand("UpdateData")
		-- Throttle InstantChartUpdate to avoid CPU spikes during fast scrolling
		-- 0.04s is roughly 1-2 frames at high refresh rates, enough to skip redundant zips
		self:stoptweening():sleep(0.04):queuecommand("TriggerInstantUpdate")
		
		-- Deferred update for heavy elements
		self:sleep(0.25):queuecommand("TriggerDelayedUpdate")
	end,
	CurrentStepsChangedMessageCommand = function(self)
		self:playcommand("UpdateData")
		self:stoptweening():sleep(0.04):queuecommand("TriggerInstantUpdate")
		self:sleep(0.15):queuecommand("TriggerDelayedUpdate")
	end,
	CurrentRateChangedMessageCommand = function(self)
		self:playcommand("UpdateData")
		self:stoptweening():sleep(0.04):queuecommand("TriggerInstantUpdate")
		self:sleep(0.15):queuecommand("TriggerDelayedUpdate")
	end,
	TriggerInstantUpdateCommand = function(self)
		MESSAGEMAN:Broadcast("InstantChartUpdate")
	end,
	TriggerDelayedUpdateCommand = function(self)
		self:playcommand("UpdateHeavyData")
		MESSAGEMAN:Broadcast("DelayedChartUpdate")
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
			self.lastPath = ""
		end,
		SetCommand = function(self)
			local song = HV.CurrentSongData.song
			if song then
				local bnpath = song:GetBannerPath()
				if bnpath and bnpath ~= "" then
					if bnpath ~= self.lastPath then
						self:Load(bnpath)
						self.lastPath = bnpath
					end
					self:scaletoclipped(panelW - 24, (panelW - 24) / 3.2)
					self:visible(true)
				else
					self:visible(false)
				end
			else
				self:visible(false)
			end
		end,
		DelayedChartUpdateMessageCommand = function(self)
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
			local song = HV.CurrentSongData.song
			if song then
				self:settext(song:GetDisplayMainTitle())
			else
				self:settext("")
			end
		end,
		InstantChartUpdateMessageCommand = function(self)
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
			local song = HV.CurrentSongData.song
			if song then
				self:settext(song:GetDisplayArtist())
			else
				self:settext("")
			end
		end,
		InstantChartUpdateMessageCommand = function(self)
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
			local song = HV.CurrentSongData.song
			if song then
				self:settext(song:GetGroupName())
			else
				self:settext("")
			end
		end,
		InstantChartUpdateMessageCommand = function(self)
			self:playcommand("Set")
		end
	},

	Def.ActorFrame {
		Name = "CDTitleBox",
		InitCommand = function(self)
			self:xy(panelW - 32, 22) -- Align to right edge
		end,
		SetCommand = function(self)
			local song = HV.CurrentSongData.song
			if song and song:HasCDTitle() then
				self:visible(true)
			else
				self:visible(false)
			end
		end,
		DelayedChartUpdateMessageCommand = function(self)
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
				self.song = HV.CurrentSongData.song
				if self.song and self.song:HasCDTitle() then
					local path = self.song:GetCDTitlePath()
					if path and path ~= "" then
						if path ~= self.lastPath then
							self:Load(path)
							self.lastPath = path
						end
						self:visible(true)
					else
						self:visible(false)
					end
				else
					self:visible(false)
				end
				
				local maxDim = 32 -- Smaller to fit next to text
				local w, h = self:GetWidth(), self:GetHeight()
				if w > 0 and h > 0 then
					local scale = math.min(maxDim / w, maxDim / h)
					self:zoom(scale)
				end
			end,
			DelayedChartUpdateMessageCommand = function(self)
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
			self:settext(THEME:GetString("ScreenSelectMusic", "BPM"))
		end
	},
	-- BPM Value
	LoadFont("Common Normal") .. {
		Name = "BPMValue",
		InitCommand = function(self)
			self:halign(0):valign(0):x(40):zoom(0.4):diffuse(mainText)
		end,
		SetCommand = function(self)
			local song = HV.CurrentSongData.song
			if song then
				local bpms = song:GetDisplayBpms()
				local rate = HV.CurrentSongData.rate
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
		InstantChartUpdateMessageCommand = function(self)
			self:playcommand("Set")
		end,
		CurrentRateChangedMessageCommand = function(self)
			-- SelectionManager handles this now
		end
	},

	-- Length Label
	LoadFont("Common Normal") .. {
		Name = "LengthLabel",
		InitCommand = function(self)
			self:halign(0):valign(0):x(panelW * 0.35):zoom(0.35):diffuse(dimText)
			self:settext(THEME:GetString("ScreenSelectMusic", "Length"))
		end
	},
	LoadFont("Common Normal") .. {
		Name = "LengthValue",
		InitCommand = function(self)
			self:halign(0):valign(0):x(panelW * 0.35 + 56):zoom(0.4):diffuse(mainText)
		end,
		SetCommand = function(self)
			local song = HV.CurrentSongData.song
			if song then
				local len = song:MusicLengthSeconds()
				local rate = HV.CurrentSongData.rate
				if rate > 0 then len = len / rate end
				local mins = math.floor(len / 60)
				local secs = math.floor(len % 60)
				self:settext(string.format("%d:%02d", mins, secs))
				
				-- Color gradient based on length
				-- < 1:00 = white, 1:00-3:30 = green to yellow, 3:30-7:00 = yellow to red, 7:00-10:00 = red to purple, > 10:00 = purple
				if len < 60 then
					self:diffuse(color("1,1,1,1"))  -- White
				elseif len < 210 then  
					local t = (len - 60) / 150 
					local g = 1 - t * 0.5
					self:diffuse(color("0.5,"..g..",0.5,1"))  -- Green to Yellow
				elseif len < 420 then  
					local t = (len - 210) / 210 
					local r = 0.5 + t * 0.5 
					local g = 0.5 - t * 0.5 
					self:diffuse(color(r..","..g..",0.5,1"))  -- Yellow to Red
				elseif len < 600 then  
					local t = (len - 420) / 180 
					local b = 0.5 + t * 0.5 
					self:diffuse(color("1,0,"..b..",1"))  -- Red to Purple
				else
					self:diffuse(color("0.7,0,1,1"))  -- Purple
				end
			else
				self:settext("--:--")
				self:diffuse(mainText)
			end
		end,
		InstantChartUpdateMessageCommand = function(self)
			self:playcommand("Set")
		end,
		CurrentRateChangedMessageCommand = function(self)
			-- SelectionManager handles this now
		end
	},

	-- NPS Label
	LoadFont("Common Normal") .. {
		Name = "NPSLabel",
		InitCommand = function(self)
			self:halign(0):valign(0):x(panelW * 0.65):zoom(0.35):diffuse(dimText)
			self:settext("NPS")
		end
	},
	LoadFont("Common Normal") .. {
		Name = "NPSValue",
		InitCommand = function(self)
			self:halign(0):valign(0):x(panelW * 0.65 + 28):zoom(0.4):diffuse(mainText)
		end,
		SetCommand = function(self)
			local data = HV.CurrentSongData
			if data.steps then
				local rate = math.max(0.05, getCurRateValue())
				local vectors = data.steps:GetCDGraphVectors(rate)
				if vectors and vectors[1] and #vectors[1] > 0 then
					local npsV = vectors[1]
					local mNPS = 0
					for i=1, #npsV do
						if npsV[i] > mNPS then mNPS = npsV[i] end
					end
					if mNPS >= 2 then
						local peak70 = mNPS * 0.7
						self:settextf("%.0f (%.0f)", mNPS, peak70)
						self:diffuse(accentColor)
					else
						self:settext("-- (--)")
						self:diffuse(dimText)
					end
				else
					self:settext("-- (--)")
					self:diffuse(dimText)
				end
			else
				self:settext("-- (--)")
				self:diffuse(dimText)
			end
		end,
		DelayedChartUpdateMessageCommand = function(self)
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
local msdY = detailY + 35
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
			self:settext(THEME:GetString("ScreenSelectMusic", "MSDRatings"))
		end
	}
}

-- Create Overall Rating Row (Large)
t[#t + 1] = Def.ActorFrame {
	Name = "MSDRow_Overall",
	InitCommand = function(self)
		self:xy(panelX + 16, msdY + 18)
		local show = ThemePrefs.Get("HV_ShowMSD")
		self:visible(show == "true" or show == true)
	end,

	LoadFont("Common Large") .. {
		Name = "MSD_Overall",
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.45):diffuse(mainText)
		end,
		SetCommand = function(self)
			local data = HV.CurrentSongData
			local msd = data.skillsetMSDs[1] -- Overall
			if msd and msd > 0 then
				self:settext(string.format("%.2f", msd))
				self:diffuse(HVColor.GetMSDRatingColor(msd))
			else
				self:settext("-")
				self:diffuse(dimText)
			end
		end,
		DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
	},
	
	-- Top 3 Skillsets Displays
	Def.ActorFrame {
		Name = "TopSkillsetIcons",
		InitCommand = function(self)
			self:xy(105, -6) -- Moved down 4px for better vertical alignment
		end,
		
		-- Container for Icon 1
		Def.ActorFrame {
			Name = "IconContainer1",
			InitCommand = function(self) self:x(0) end,
			Def.Sprite { Name = "Img", InitCommand = function(self) self:y(0):zoom(0.5):visible(false) end },
			LoadFont("Common Normal") .. { Name = "Lbl", InitCommand = function(self) self:y(30):zoom(0.28):diffuse(dimText):visible(false) end }
		},
		-- Container for Icon 2
		Def.ActorFrame {
			Name = "IconContainer2",
			InitCommand = function(self) self:x(55) end,
			Def.Sprite { Name = "Img", InitCommand = function(self) self:y(0):zoom(0.5):visible(false) end },
			LoadFont("Common Normal") .. { Name = "Lbl", InitCommand = function(self) self:y(30):zoom(0.28):diffuse(dimText):visible(false) end }
		},
		-- Container for Icon 3
		Def.ActorFrame {
			Name = "IconContainer3",
			InitCommand = function(self) self:x(110) end,
			Def.Sprite { Name = "Img", InitCommand = function(self) self:y(0):zoom(0.5):visible(false) end },
			LoadFont("Common Normal") .. { Name = "Lbl", InitCommand = function(self) self:y(30):zoom(0.28):diffuse(dimText):visible(false) end }
		},
		
		SetCommand = function(self)
			local c1 = self:GetChild("IconContainer1")
			local c2 = self:GetChild("IconContainer2")
			local c3 = self:GetChild("IconContainer3")
			c1:GetChild("Img"):visible(false) c1:GetChild("Lbl"):visible(false)
			c2:GetChild("Img"):visible(false) c2:GetChild("Lbl"):visible(false)
			c3:GetChild("Img"):visible(false) c3:GetChild("Lbl"):visible(false)
			
			local data = HV.CurrentSongData
			if not data.song or not data.steps then return end
			
			local vals = {}
			local ssNames = {"Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}
			for i, name in ipairs(ssNames) do
				local m = data.skillsetMSDs[i + 1]
				if m and m > 0 then table.insert(vals, {name = name, val = m}) end
			end
			
			table.sort(vals, function(a, b) return a.val > b.val end)
			
			if #vals >= 1 then 
				self:GetParent():playcommand("LoadSkillsetIcon", {container = c1, name = vals[1].name})
			end
			if #vals >= 2 then 
				self:GetParent():playcommand("LoadSkillsetIcon", {container = c2, name = vals[2].name})
			end
			if #vals >= 3 then 
				self:GetParent():playcommand("LoadSkillsetIcon", {container = c3, name = vals[3].name})
			end
		end,
		LoadSkillsetIconCommand = function(self, params)
			local c = params.container
			local name = params.name
			local path = THEME:GetPathG("", "skillsets/" .. string.lower(name) .. ".png")
			c:GetChild("Img"):Load(path):visible(true)
			c:GetChild("Lbl"):settext(name):visible(true)
		end,
		DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
	}
}

-- ============================================================
-- MSD SKILLSET TOOLTIP (Mouse-following, 4-up/3-down grid)
-- ============================================================
local msdTooltipW = 280
local msdTooltipH = 56

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
			self:halign(0):valign(1):zoomto(msdTooltipW, msdTooltipH):diffuse(color("0.05,0.05,0.05,0.95"))
		end
	},
	-- Border
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(1):zoomto(msdTooltipW, 1):y(-msdTooltipH):diffuse(accentColor):diffusealpha(0.5)
		end
	}
}

-- 7 skillsets (no Overall): 4 on top row, 3 on bottom row
local tooltipSkillsets = {
	{name="Stream", idx=2}, {name="Jumpstream", idx=3}, {name="Handstream", idx=4}, {name="Stamina", idx=5},
	{name="JackSpeed", idx=6}, {name="Chordjack", idx=7}, {name="Technical", idx=8}
}

for i, ss in ipairs(tooltipSkillsets) do
	local col, row, colW, offsetX
	if i <= 4 then
		row = 0
		col = i - 1
		colW = msdTooltipW / 4
		offsetX = col * colW + (colW / 2)
	else
		row = 1
		col = i - 5
		colW = msdTooltipW / 3
		offsetX = col * colW + (colW / 2)
	end

	local offsetY = -msdTooltipH + 12 + row * 24

	msdTooltip[#msdTooltip + 1] = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(offsetX, offsetY)
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:y(-7):zoom(0.22):diffuse(subText):settext(ss.name) end
		},
		LoadFont("Common Normal") .. {
			Name = "Val",
			InitCommand = function(self) self:y(5):zoom(0.35):diffuse(mainText) end,
			SetCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if song then
					local curSteps = GAMESTATE:GetCurrentSteps()
					if curSteps then
						local msd = curSteps:GetMSD(getCurRateValue(), ss.idx)
						if msd and msd > 0 then
							self:settext(string.format("%.2f", msd)):diffuse(HVColor.GetMSDRatingColor(msd))
						else self:settext("-"):diffuse(dimText) end
					else self:settext("-"):diffuse(dimText) end
				else self:settext("-"):diffuse(dimText) end
			end
		}
	}
end
t[#t + 1] = msdTooltip

-- Mouse Handler for MSD Tooltip
t[#t + 1] = Def.ActorFrame {
	Name = "MSDTooltipHandler",
	OnCommand = function(self)
		self:queuecommand("Tick")
	end,
	TickCommand = function(self)
		if msdTooltipActor then
			-- The label is at msdY and the number is at msdY + 18 with zoom ~0.45.
			-- The text height is around 40px, so 18 + 40 = 58.
			local isHovering = IsMouseOver(panelX + 10, msdY + 14, 120, 48)
			if isHovering and HV.ShowMSD() then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				local wasHidden = not msdTooltipActor:GetVisible()
				msdTooltipActor:visible(true):xy(mx + 5, my - 15)
				if wasHidden then
					msdTooltipActor:playcommand("Set")
				end
			else
				msdTooltipActor:visible(false)
			end
		end
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
			self:settext(THEME:GetString("ScreenSelectMusic", "Chart"))
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
				local data = HV.CurrentSongData
				if not data.song then self:diffusealpha(0.3) return end
				
				local found = data.diffAvailability[dname]
				if not found then
					self:diffuse(color("0.08,0.08,0.08,1")):diffusealpha(0.15)
				else
					local curSteps = data.steps
					if curSteps and ToEnumShortString(curSteps:GetDifficulty()) == dname then
						self:diffuse(HVColor.Difficulty[dname] or accentColor):diffusealpha(0.4)
					else
						self:diffuse(color("0.08,0.08,0.08,1")):diffusealpha(1)
					end
				end
			end,
			DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
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
				local data = HV.CurrentSongData
				if not data.song then self:diffusealpha(0.3) return end
				local found = data.diffAvailability[dname]
				self:diffusealpha(found and 1 or 0.2)
			end,
			DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
		},

		LoadFont("Common Normal") .. {
			Name = "MSDVal",
			InitCommand = function(self)
				self:halign(1):valign(0.5)
					:xy(diffTabW - 6, diffTabH / 2)
					:zoom(0.26):diffuse(dimText)
			end,
			SetCommand = function(self)
				local data = HV.CurrentSongData
				if not data.song then self:settext("") return end
				
				local found = data.diffAvailability[dname]
				if not found then self:settext("") return end

				local showMSD = (ThemePrefs.Get("HV_ShowMSD") == "true" or ThemePrefs.Get("HV_ShowMSD") == true) or ThemePrefs.Get("HV_ShowMSD") == true
				
				if showMSD then
					local msd = data.diffMSDs[dname]
					if msd and msd > 0 then
						self:settext(string.format("%.2f", msd))
						self:diffuse(HVColor.GetMSDRatingColor(msd))
					else
						self:settext("-")
						self:diffuse(dimText)
					end
				else
					-- Show chart meter if MSD is disabled
					local meter = data.diffMeters[dname] or 0
					self:settext(tostring(meter))
					self:diffuse(mainText)
				end
			end,
			DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
		}
	}
end

-- Difficulty selector click handler (vertical layout)
t[#t + 1] = Def.ActorFrame {
	Name = "DiffSelectorClickHandler",
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		
		-- Cleanup existing
		if HV.DiffSelectorInputCallback then
			pcall(function() screen:RemoveInputCallback(HV.DiffSelectorInputCallback) end)
		end
		
		HV.DiffSelectorInputCallback = function(event)
			if not event or not event.DeviceInput then return false end
			
			-- Screen name check to avoid leaking into text entry or other overlays
			local top = SCREENMAN:GetTopScreen()
			if not top or top:GetName() ~= "ScreenSelectMusic" then return false end
			
			if event.type ~= "InputEventType_FirstPress" then return false end
			
			-- Block input if an overlay tab is active
			if (HV.ActiveTab and HV.ActiveTab ~= "") then return false end

			local btn = event.DeviceInput.button
			if btn ~= "DeviceButton_left mouse button" then return false end
			
			local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			local song = GAMESTATE:GetCurrentSong()
			if not song then return false end
			
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
			return false
		end
		
		screen:AddInputCallback(HV.DiffSelectorInputCallback)
	end
}

-- ============================================================
-- PERSONAL BEST DISPLAY (Under MSD rating in sidebar)
-- ============================================================
local pbY = msdY + 60
local function getRescoreElementsFromScore(score)
	local o = {}
	if not score:HasReplayData() then return nil end
	local replay = score:GetReplay()
	local ok = pcall(function() replay:LoadAllData() end)
	if not ok then return nil end
	
	local dvtTmp = replay:GetOffsetVector()
	local tvt = replay:GetTapNoteTypeVector()
	local dvt = {}
	if tvt ~= nil and #tvt > 0 then
		for i, d in ipairs(dvtTmp) do
			local ty = tvt[i]
			if ty == "TapNoteType_Tap" or ty == "TapNoteType_HoldHead" or ty == "TapNoteType_Lift" then
				dvt[#dvt+1] = d
			end
		end
	else
		dvt = dvtTmp
	end
	o["dvt"] = dvt
	
	o["misses"] = score:GetTapNoteScore("TapNoteScore_Miss")
	o["holdsMissed"] = score:GetHoldNoteScore("HoldNoteScore_LetGo")
	o["rollsMissed"] = 0
	o["minesHit"] = score:GetTapNoteScore("TapNoteScore_HitMine")
	
	local hits = 0
	for _, name in ipairs({"W1","W2","W3","W4","W5"}) do
		hits = hits + score:GetTapNoteScore("TapNoteScore_"..name)
	end
	o["tapsHit"] = hits
	o["notesPassed"] = hits + o["misses"]
	
	local steps = GAMESTATE:GetCurrentSteps()
	local radar = steps and steps:GetRadarValues(PLAYER_1)
	o["totalHolds"] = (radar and radar:GetValue("RadarCategory_Holds")) or score:GetHoldNoteScore("HoldNoteScore_Held") + o["holdsMissed"]
	o["totalRolls"] = (radar and radar:GetValue("RadarCategory_Rolls")) or 0
	o["totalMines"] = (radar and radar:GetValue("RadarCategory_Mines")) or score:GetTapNoteScore("TapNoteScore_AvoidMine") + o["minesHit"]
	o["totalNotes"] = (radar and radar:GetValue("RadarCategory_Notes")) or o["notesPassed"]
	
	return o
end

t[#t + 1] = Def.ActorFrame {
	Name = "PersonalBestFrame",
	InitCommand = function(self)
		self:xy(panelX + 16, pbY)
		self.isHovering = false
	end,
	OnCommand = function(self)
		self:queuecommand("Tick")
	end,
	TickCommand = function(self)
		local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
		local isH = mx >= (panelX + 10) and mx <= (panelX + panelW - 22) and my >= (pbY - 4) and my <= (pbY + 110)
		if isH ~= self.isHovering then
			self.isHovering = isH
			self:playcommand("Set")
		end
		self:sleep(0.05):queuecommand("Tick")
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
		end,
		OnCommand = function(self)
			self:playcommand("Set")
		end,
		SetCommand = function(self)
			local score = HV.CurrentSongData.pbScore
			local isDifferentRate = score and math.abs(score:GetMusicRate() - getCurRateValue()) > 0.001
			
			if self:GetParent().isHovering then
				self:settext(THEME:GetString("ScreenSelectMusic", "PersonalBest") .. " (J4)")
				self:diffuse(color("#FF6666"))
			else
				self:settext(THEME:GetString("ScreenSelectMusic", "PersonalBest"))
				-- Color header if it's a different rate to highlight why
				self:diffuse(isDifferentRate and accentColor or accentColor)
			end
		end
	},
	
	LoadFont("Common Normal") .. {
		Name = "PBDate",
		InitCommand = function(self)
			self:halign(1):valign(0):x(panelW - 32):y(2):zoom(0.24):diffuse(subText)
		end,
		SetCommand = function(self)
			local score = HV.CurrentSongData.pbScore
			if score then
				self:settext(score:GetDate())
			else
				self:settext("")
			end
		end,
		DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
	},

	LoadFont("Common Normal") .. {
		Name = "PBScoringSystem",
		InitCommand = function(self)
			self:halign(0):valign(0):y(14):zoom(0.35):diffuse(subText)
		end,
		SetCommand = function(self)
			local score = HV.CurrentSongData.pbScore
			if score then
				if self:GetParent().isHovering then
					self:settext("")
				else
					local text = "Wife3"
					local norm = PREFSMAN:GetPreference("SortBySSRNormPercent")
					if not norm and type(score.GetJudgeScale) == "function" then
						local scale = score:GetJudgeScale()
						if scale then
							scale = math.floor(scale * 100 + 0.5) / 100 -- safe round
							local jIndex = 4
							for k, v in pairs(ms.JudgeScalers) do
								if math.floor(v * 100 + 0.5) / 100 == scale then
									jIndex = k
									if jIndex >= 4 then break end
								end
							end
							jIndex = math.max(4, math.min(9, jIndex))
							text = text .. " J" .. jIndex
						end
					end
					self:settext(text)
				end
			else
				self:settext("")
			end
		end,
		DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
	},

	LoadFont("Common Normal") .. {
		Name = "PBRate",
		InitCommand = function(self)
			self:halign(1):valign(0):x(panelW - 32):y(14):zoom(0.35):diffuse(mainText)
		end,
		SetCommand = function(self)
			local score = HV.CurrentSongData.pbScore
			if score then
				local r = score:GetMusicRate()
				self:settext(string.format("%.2fx", r))
				-- Color rate if it's NOT the current rate (Task 1)
				if math.abs(r - getCurRateValue()) > 0.001 then
					self:diffuse(accentColor)
				else
					self:diffuse(mainText)
				end
			else
				self:settext("")
			end
		end,
		DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
	},

	LoadFont("Common Large") .. {
		Name = "PBScore",
		InitCommand = function(self)
			self:halign(0):valign(0):y(28):zoom(0.5):diffuse(brightText)
		end,
		SetCommand = function(self)
			local score = HV.CurrentSongData.pbScore
			if score then
				local wifePct = score:GetWifeScore() * 100
				if self:GetParent().isHovering and score:HasReplayData() then
					local rst = getRescoreElementsFromScore(score)
					wifePct = rst and getRescoredWife3Judge(3, 4, rst) or wifePct
				elseif self:GetParent().isHovering and type(score.GetRescoredWifeScore) == "function" then
					wifePct = score:GetRescoredWifeScore(4) * 100
				end
				if wifePct >= 99 then
					self:settext(string.format("%.4f%%", wifePct))
				else
					self:settext(string.format("%.2f%%", wifePct))
				end
				self:diffuse(brightText)
			else
				self:settext(THEME:GetString("ScreenSelectMusic", "NoScore"))
				self:diffuse(dimText)
			end
		end,
		DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
	},

	LoadFont("Common Large") .. {
		Name = "PBGrade",
		InitCommand = function(self)
			self:halign(0):valign(0):x(115):y(28):zoom(0.5)
		end,
		SetCommand = function(self)
			local score = HV.CurrentSongData.pbScore
			if score then
				local gradeStr = score:GetWifeGrade()
				local wifePct = score:GetWifeScore() * 100
				if self:GetParent().isHovering and score:HasReplayData() then
					local rst = getRescoreElementsFromScore(score)
					wifePct = rst and getRescoredWife3Judge(3, 4, rst) or wifePct
					gradeStr = GetGradeFromPercent(wifePct / 100)
				elseif self:GetParent().isHovering and type(score.GetRescoredWifeScore) == "function" then
					wifePct = score:GetRescoredWifeScore(4) * 100
					gradeStr = GetGradeFromPercent(wifePct / 100)
				end
				
				-- gradeStr may be "Grade_Tier09" or "Tier09"; normalize
				if gradeStr and not gradeStr:find("^Grade_") then
					gradeStr = "Grade_" .. gradeStr
				end
				self:settext(HV.GetGradeName(gradeStr))
				self:diffuse(HVColor.GetGradeColor(gradeStr))
			else
				self:settext("")
			end
		end,
		DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
	},
	
	LoadFont("Common Large") .. {
		Name = "PBClearType",
		InitCommand = function(self)
			self:halign(1):valign(0):x(panelW - 32):y(28):zoom(0.4)
		end,
		SetCommand = function(self)
			local score = HV.CurrentSongData.pbScore
			if score then
				local ct = getDetailedClearType(score)
				
				if self:GetParent().isHovering and score:HasReplayData() then
					local rst = getRescoreElementsFromScore(score)
					if rst then
						local w1 = getRescoredJudge(rst.dvt, 4, 1)
						local w2 = getRescoredJudge(rst.dvt, 4, 2)
						local w3 = getRescoredJudge(rst.dvt, 4, 3)
						local w4 = getRescoredJudge(rst.dvt, 4, 4)
						local w5 = getRescoredJudge(rst.dvt, 4, 5)
						local miss = getRescoredJudge(rst.dvt, 4, 6)
						
						local pct = getRescoredWife3Judge(3, 4, rst) or 0
						if pct <= 0 then
							ct = "Failed"
						else
							local cb = miss + w5 + w4
							if cb > 0 then
								if cb == 1 then ct = "MF"
								elseif cb < 10 then ct = "SDCB"
								else ct = "Clear" end
							elseif w3 > 0 then
								if w3 == 1 then ct = "BF"
								elseif w3 < 10 then ct = "SDG"
								else ct = "FC" end
							elseif w2 > 0 then
								if w2 == 1 then ct = "WF"
								elseif w2 < 10 then ct = "SDP"
								else ct = "PFC" end
							else
								ct = "MFC"
							end
						end
					end
				elseif self:GetParent().isHovering and type(score.GetRescoredWifeScore) == "function" then
					-- Cannot easily construct ClearType without vectors safely, fallback
				end
				
				local ctStr = THEME:GetString("ClearTypes", ct)
				self:settext(ctStr)
				self:diffuse(HVColor.GetClearTypeColor(ct))
			else
				self:settext("")
			end
		end,
		DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
	},

	LoadFont("Common Normal") .. {
		Name = "PBSSR",
		InitCommand = function(self)
			self:halign(0):valign(0):y(52):zoom(0.30):diffuse(mainText)
		end,
		SetCommand = function(self)
			local showMSD = (ThemePrefs.Get("HV_ShowMSD") == "true" or ThemePrefs.Get("HV_ShowMSD") == true) or ThemePrefs.Get("HV_ShowMSD") == true
			if not showMSD then
				self:settext("")
				return
			end
			local ssr = HV.CurrentSongData.pbSSR
			if ssr and ssr > 0 then
				self:settext(string.format("%.2f", ssr))
				self:diffuse(HVColor.GetMSDRatingColor(ssr))
			else
				self:settext("")
			end
		end,
		DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
	},

	Def.ActorFrame {
		Name = "PBJudgesFrame",
		InitCommand = function(self)
			self:y(68)
		end,
		SetCommand = function(self)
			local score = HV.CurrentSongData.pbScore
			if not score then
				self:visible(false)
				return
			end
			self:visible(true)
			local judges = {
				{name = "W1", label = "MARV", val = score:GetTapNoteScore("TapNoteScore_W1")},
				{name = "W2", label = "PERF", val = score:GetTapNoteScore("TapNoteScore_W2")},
				{name = "W3", label = "GREAT", val = score:GetTapNoteScore("TapNoteScore_W3")},
				{name = "W4", label = "GOOD", val = score:GetTapNoteScore("TapNoteScore_W4")},
				{name = "W5", label = "BAD", val = score:GetTapNoteScore("TapNoteScore_W5")},
				{name = "Miss", label = "MISS", val = score:GetTapNoteScore("TapNoteScore_Miss")}
			}
			
			if self:GetParent().isHovering and score:HasReplayData() then
				local rst = getRescoreElementsFromScore(score)
				if rst then
					for i=1, 6 do
						judges[i].val = getRescoredJudge(rst.dvt, 4, i)
					end
				end
			end
			
			for i, j in ipairs(judges) do
				local block = self:GetChild("Blocks"):GetChild("Block_" .. i)
				local bg = block:GetChild("Bg")
				local lbl = block:GetChild("Lbl")
				local valTxt = block:GetChild("Val")
				
				if bg and lbl and valTxt then
					valTxt:settext(tostring(j.val))
					
					local c = HVColor.Judgment and HVColor.Judgment[j.name] or color("0.5,0.5,0.5,1")
					bg:diffuse(c):diffusealpha(0.2) -- translucent colored quad
					lbl:settext(j.label):diffuse(c):zoom(0.2)
					valTxt:diffuse(c):zoom(0.45)
				end
			end
		end,
		DelayedChartUpdateMessageCommand = function(self) self:playcommand("Set") end,
		(function()
			local blocks = Def.ActorFrame{ Name = "Blocks" }
			local numBlocks = 6
			local panelWConst = SCREEN_WIDTH * 0.36
			local gap = 2
			local blockW = (panelWConst - 32 - (gap * (numBlocks - 1))) / numBlocks
			
			for i = 1, numBlocks do
				blocks[#blocks + 1] = Def.ActorFrame {
					Name = "Block_" .. i,
					InitCommand = function(self)
						self:x((i - 1) * (blockW + gap))
					end,
					Def.Quad {
						Name = "Bg",
						InitCommand = function(self)
							self:halign(0):valign(0):zoomto(blockW, 22)
						end
					},
					LoadFont("Common Normal") .. {
						Name = "Val",
						InitCommand = function(self)
							self:halign(0.5):valign(0):xy(blockW/2, 2):zoom(0.30)
						end
					},
					LoadFont("Common Normal") .. {
						Name = "Lbl",
						InitCommand = function(self)
							self:halign(0.5):valign(0):xy(blockW/2, 13):zoom(0.20)
						end
					}
				}
			end
			return blocks
		end)()
	},


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
		local profile = PROFILEMAN:GetProfile(PLAYER_1)
		if profile then
			HV.LastTotalXP = HV.GetXP(profile)
		end
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
		-- Removed CurrentSongChanged trigger to avoid redundant reloads
	},

	-- Profile name
	LoadFont("Common Normal") .. {
		Name = "ProfileName",
		InitCommand = function(self)
			self:halign(0):valign(0):x(56):y(-4):zoom(0.40):diffuse(mainText)
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

	-- Level Badge
	Def.ActorFrame {
		Name = "PlayerLevelBadge",
		InitCommand = function(self) self:xy(56, 12) end,
		SetCommand = function(self)
			local showProfileStats = HV.ShowProfileStats()
			self:visible(showProfileStats == "true" or showProfileStats == true)
		end,
		
		-- Badge Quad
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):zoomto(32, 10):diffusealpha(0.8)
			end,
			SetCommand = function(self)
				local profile = PROFILEMAN:GetProfile(PLAYER_1)
				if profile and HV.GetLevelColor then
					local level = HV.GetLevel(profile)
					self:diffuse(HV.GetLevelColor(level))
				else
					self:diffuse(color("#666666"))
				end
			end
		},
		
		-- Level Text
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):x(2):zoom(0.28):diffuse(color("#000000"))
			end,
			SetCommand = function(self)
				local profile = PROFILEMAN:GetProfile(PLAYER_1)
				if profile then
					self:settextf("Lv. %d", HV.GetLevel(profile))
				end
			end
		},
		LoginMessageCommand = function(self) self:playcommand("Set") end,
		LogOutMessageCommand = function(self) self:playcommand("Set") end,
		OnlineUpdateMessageCommand = function(self) self:playcommand("Set") end,
		OnCommand = function(self) self:playcommand("Set") end
	},

	-- Progress Bar
	Def.ActorFrame {
		Name = "LevelProgress",
		InitCommand = function(self) self:xy(56, 24) end,
		SetCommand = function(self)
			local showProfileStats = HV.ShowProfileStats()
			self:visible(showProfileStats == "true" or showProfileStats == true)
		end,
		
		-- Bar BG
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):zoomto(60, 3):diffuse(0,0,0,0.5)
			end
		},
		-- Bar Fill
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):zoomto(0, 3):diffuse(color("#FF4081"))
			end,
			SetCommand = function(self)
				local profile = PROFILEMAN:GetProfile(PLAYER_1)
				if profile and HV.GetLevelProgress then
					local progress = HV.GetLevelProgress(profile)
					self:smooth(0.5):zoomx(60 * progress)
				elseif profile then
					self:zoomx(0)
				end
			end
		},
		-- Progress Numbers
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):xy(0, 8):zoom(0.22):diffuse(subText)
			end,
			SetCommand = function(self)
				local profile = PROFILEMAN:GetProfile(PLAYER_1)
				if profile and HV.GetLevelProgress then
					local _, cur, total = HV.GetLevelProgress(profile)
					self:settextf("%d / %d XP", cur, total)
				else
					self:settext("")
				end
			end
		},
		LoginMessageCommand = function(self) self:playcommand("Set") end,
		LogOutMessageCommand = function(self) self:playcommand("Set") end,
		OnlineUpdateMessageCommand = function(self) self:playcommand("Set") end,
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
			local showMSD = HV.ShowMSD()
			if not (showProfileStats == "true" or showProfileStats == true) or not showMSD then
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
				self:settextf("%s: %d\n%s: %d:%02d", 
					THEME:GetString("ScreenSelectMusic", "NotesFormatted"), notesHit, 
					THEME:GetString("ScreenSelectMusic", "SessionFormatted"), math.floor(sessionSecs/60), sessionSecs%60):visible(true)
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
					self:settext(THEME:GetString("ScreenSelectMusic", "LogOut")):diffuse(color("0.65,1,0.72,1"))
				else
					self:settext(THEME:GetString("ScreenSelectMusic", "LogIn")):diffuse(brightText)
				end
			end,
			LoginMessageCommand = function(self) self:playcommand("Set") end,
			LogOutMessageCommand = function(self) self:playcommand("Set") end,
			OnCommand = function(self) self:playcommand("Set") end
		}
	}
}


-- ============================================================
-- MUSIC RATE DISPLAY
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "RateDisplay",
	InitCommand = function(self) 
		self:xy(panelX + panelW - 40, panelY + 4) 
	end,
	LoadFont("Common Normal") .. {
		Name = "RateLabel",
		InitCommand = function(self) self:halign(1):valign(0):x(-2):zoom(0.35):diffuse(dimText):settext(THEME:GetString("ScreenSelectMusic", "Rate")) end
	},
	LoadFont("Common Normal") .. {
		Name = "RateValue",
		InitCommand = function(self) self:halign(0):valign(0):zoom(0.4):diffuse(accentColor):playcommand("Set") end,
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
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
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
	InitCommand = function(self)
		-- Removed redundant input callback to improve performance
	end,
	UpdateHoverCommand = function(self)
		if not creditTooltipActor then return end
		local song = HV.CurrentSongData.song
		if not song then creditTooltipActor:visible(false) return end

		local isHovering = IsMouseOver(panelX + 16, infoY, panelW - 16, 75)
		
		if isHovering then
			local ok, cStr = pcall(function() return song:GetCredit() end)
			if not ok or not cStr or cStr == "" then
				creditTooltipActor:visible(false)
				return
			end

			local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			local wasHidden = not creditTooltipActor:GetVisible()
			creditTooltipActor:visible(true):xy(mx + 15, my + 15)
			
			if wasHidden or creditTooltipActor._lastCredit ~= cStr then
				local txt = creditTooltipActor:GetChild("Text")
				local bg = creditTooltipActor:GetChild("Bg")
				local border = creditTooltipActor:GetChild("Border")
				
				txt:settextf(THEME:GetString("ScreenSelectMusic", "CreditFormatted"), cStr)
				local w = txt:GetZoomedWidth() + 16
				local h = txt:GetZoomedHeight() + 16
				bg:zoomto(w, h)
				border:zoomto(w, 1)
				creditTooltipActor._lastCredit = cStr
			end
		else
			creditTooltipActor:visible(false)
		end
	end,
	InstantChartUpdateMessageCommand = function(self)
		self:playcommand("UpdateHover")
	end
}

return t
