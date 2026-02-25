--- Holographic Void: ScreenSelectMusic Decorations
-- Dashboard-style song info panel on the LEFT side with:
--   - Banner display
--   - Song title, artist, pack name
--   - MSD (difficulty calculator) ratings with hover skillset breakdown
--   - BPM, length, chart info
--   - Player profile + avatar at bottom-left
--   - Overall rating display with hover skillset tooltip

local t = Def.ActorFrame {
	Name = "SelectMusicDecorations"
}

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
	-- Length Value
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
			else
				self:settext("--:--")
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
-- MSD SKILLSET RATINGS
-- ============================================================
local msdY = detailY + 30
local skillsets = {"Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}

t[#t + 1] = Def.ActorFrame {
	Name = "MSDFrame",
	InitCommand = function(self)
		self:xy(panelX + 16, msdY)
	end,

	-- MSD Header
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.35):diffuse(accentColor)
			self:settext("MSD RATINGS")
		end
	}
}

-- Create individual skillset rows
for i, ss in ipairs(skillsets) do
	t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(panelX + 16, msdY + 14 + (i * 16))
		end,

		-- Skillset label
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoom(0.3):diffuse(subText)
				self:settext(ss)
			end
		},

		-- Skillset value
		LoadFont("Common Normal") .. {
			Name = "MSD_" .. ss,
			InitCommand = function(self)
				self:halign(1):valign(0):x(panelW - 32):zoom(0.35):diffuse(mainText)
			end,
			SetMessageCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if song then
					local steps = GAMESTATE:GetCurrentSteps()
					if steps then
						local msd = steps:GetMSD(getCurRateValue(), i)
						if msd and msd > 0 then
							self:settext(string.format("%.2f", msd))
							-- Color intensity based on difficulty
							local intensity = math.min(msd / 35, 1)
							self:diffuse(
								lerp_color(intensity, mainText, brightText)
							)
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
			CurrentSongChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			CurrentStepsChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			CurrentRateChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		},

		-- Subtle bar graph behind value
		Def.Quad {
			Name = "MSDBar_" .. ss,
			InitCommand = function(self)
				self:halign(1):valign(0):x(panelW - 32):y(1)
					:zoomto(0, 12):diffuse(accentColor):diffusealpha(0.06)
			end,
			SetMessageCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if song then
					local steps = GAMESTATE:GetCurrentSteps()
					if steps then
						local msd = steps:GetMSD(getCurRateValue(), i)
						if msd and msd > 0 then
							local w = math.min(msd / 35, 1) * (panelW - 64)
							self:stoptweening():linear(0.2):zoomto(w, 12)
						else
							self:stoptweening():linear(0.1):zoomto(0, 12)
						end
					else
						self:stoptweening():linear(0.1):zoomto(0, 12)
					end
				else
					self:stoptweening():linear(0.1):zoomto(0, 12)
				end
			end,
			CurrentSongChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			CurrentStepsChangedMessageCommand = function(self)
				self:playcommand("Set")
			end,
			CurrentRateChangedMessageCommand = function(self)
				self:playcommand("Set")
			end
		}
	}
end

-- ============================================================
-- PLAYER PROFILE + AVATAR (bottom-left corner)
-- ============================================================
local profileY = SCREEN_HEIGHT - 90

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
				-- Try to load the player's avatar from Assets/Avatars
				local avatarPath = nil
				-- Attempt getAvatarPath from the profile if available (0.74.4)
				if profile.GetAvatarPath then
					avatarPath = profile:GetAvatarPath()
				end
				if avatarPath and avatarPath ~= "" and FILEMAN:DoesFileExist(avatarPath) then
					self:Load(avatarPath)
				else
					-- Fallback
					local fallback = "/Assets/Avatars/_fallback.png"
					if FILEMAN:DoesFileExist(fallback) then
						self:Load(fallback)
					end
				end
				self:scaletoclipped(40, 40)
				self:visible(true)
			else
				self:visible(false)
			end
		end,
		OnCommand = function(self) self:playcommand("Set") end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	},

	-- Profile name
	LoadFont("Common Normal") .. {
		Name = "ProfileName",
		InitCommand = function(self)
			self:halign(0):valign(0):x(48):y(2):zoom(0.4):diffuse(mainText)
		end,
		SetMessageCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local name = profile:GetDisplayName()
				if name == "" then name = "Player" end
				self:settext(name)
			else
				self:settext("No Profile")
				self:diffuse(dimText)
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	},

	-- Overall rating (large, accent)
	LoadFont("Common Normal") .. {
		Name = "OverallRating",
		InitCommand = function(self)
			self:halign(0):valign(0):x(48):y(18):zoom(0.5):diffuse(accentColor)
		end,
		SetMessageCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local rating = profile:GetPlayerRating()
				self:settext(string.format("%.2f", rating))
			else
				self:settext("--")
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	},

	-- Rating label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):x(48 + 50):y(20):zoom(0.26):diffuse(dimText)
			self:settext("RATING")
		end
	},

	-- Play count (right-aligned)
	LoadFont("Common Normal") .. {
		Name = "PlayCount",
		InitCommand = function(self)
			self:halign(1):valign(0):x(panelW - 32):y(2):zoom(0.32):diffuse(subText)
		end,
		SetMessageCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				self:settext(tostring(profile:GetNumTotalSongsPlayed()) .. " plays")
			else
				self:settext("")
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
}

-- ============================================================
-- OVERALL RATING HOVER TOOLTIP (skillset breakdown)
-- Shows individual skillsets when hovering the rating display
-- ============================================================
local ratingSkillsets = {"Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}
local tooltipW = 180
local tooltipH = #ratingSkillsets * 18 + 20

t[#t + 1] = Def.ActorFrame {
	Name = "RatingTooltip",
	InitCommand = function(self)
		self:xy(panelX + 48, profileY + 18 - tooltipH - 4)
		self:visible(false)
	end,

	-- Tooltip background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
				:zoomto(tooltipW, tooltipH)
				:diffuse(color("0.08,0.08,0.08,0.95"))
		end
	},

	-- Tooltip border
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
				:zoomto(tooltipW, 1)
				:diffuse(accentColor):diffusealpha(0.4)
		end
	}
}

-- Add skillset rows to the tooltip
for i, ssName in ipairs(ratingSkillsets) do
	t[#t + 1] = Def.ActorFrame {
		Name = "TooltipRow_" .. ssName,
		InitCommand = function(self)
			self:xy(panelX + 48 + 8, profileY + 18 - tooltipH - 4 + 8 + (i - 1) * 18)
			self:visible(false)
		end,

		-- Skillset name
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoom(0.28):diffuse(subText)
				self:settext(ssName)
			end
		},

		-- Skillset value
		LoadFont("Common Normal") .. {
			Name = "TooltipVal_" .. ssName,
			InitCommand = function(self)
				self:halign(1):valign(0):x(tooltipW - 16):zoom(0.3):diffuse(mainText)
			end,
			SetCommand = function(self)
				local profile = PROFILEMAN:GetProfile(PLAYER_1)
				if profile then
					local skillIdx = i + 1 -- offset: Overall is 1, skillsets start at 2
					local val = profile:GetPlayerSkillsetRating(skillIdx)
					if val and val > 0 then
						self:settext(string.format("%.2f", val))
					else
						self:settext("-")
					end
				else
					self:settext("-")
				end
			end,
			OnCommand = function(self) self:playcommand("Set") end
		}
	}
end

-- Mouse hover handler for the rating tooltip
t[#t + 1] = Def.ActorFrame {
	Name = "RatingHoverHandler",
	BeginCommand = function(self)
		local tooltipVisible = false
		local tooltipFrame = self:GetParent():GetChild("RatingTooltip")
		local tooltipRows = {}
		for _, ssName in ipairs(ratingSkillsets) do
			tooltipRows[#tooltipRows + 1] = self:GetParent():GetChild("TooltipRow_" .. ssName)
		end

		-- Rating hitbox: near the overall rating text
		local ratingX1 = panelX + 48
		local ratingX2 = panelX + 48 + 100
		local ratingY1 = profileY + 16
		local ratingY2 = profileY + 36

		self:SetUpdateFunction(function()
			local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			local hovering = mx >= ratingX1 and mx <= ratingX2
				and my >= ratingY1 and my <= ratingY2

			if hovering and not tooltipVisible then
				tooltipVisible = true
				if tooltipFrame then tooltipFrame:visible(true) end
				for _, row in ipairs(tooltipRows) do
					if row then row:visible(true) end
				end
			elseif not hovering and tooltipVisible then
				tooltipVisible = false
				if tooltipFrame then tooltipFrame:visible(false) end
				for _, row in ipairs(tooltipRows) do
					if row then row:visible(false) end
				end
			end
		end)
	end
}

-- ============================================================
-- MUSIC RATE DISPLAY (above the wheel on the right)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "RateDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 180, 10)
	end,

	LoadFont("Common Normal") .. {
		Name = "RateText",
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.45):diffuse(mainText)
		end,
		SetMessageCommand = function(self)
			local rate = getCurRateString()
			if rate then
				self:settext("Rate: " .. rate)
			else
				self:settext("Rate: 1.0x")
			end
		end,
		CurrentRateChangedMessageCommand = function(self)
			self:playcommand("Set")
		end
	}
}

-- ============================================================
-- MOUSE SUPPORT: Wheel Scroll + Click
-- ============================================================
local wheelX = SCREEN_WIDTH - 180    -- from metrics.ini MusicWheelX
local wheelY = SCREEN_CENTER_Y       -- from metrics.ini MusicWheelY
local wheelItemH = 36                -- from metrics.ini ItemTransformFunction spacing
local wheelNumItems = 35             -- from metrics.ini NumWheelItems
local wheelItemW = 340               -- approximate clickable width
local lastHoveredWheelItem = nil

t[#t + 1] = Def.ActorFrame {
	Name = "MouseHandler",
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		-- Per-frame hover tracking for wheel items
		self:SetUpdateFunction(function()
			local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			-- Determine which wheel item the mouse is over (center item = index 0)
			local halfVisible = math.floor(wheelNumItems / 2)
			local hovered = nil
			for i = -halfVisible, halfVisible do
				local iy = wheelY + i * wheelItemH
				if mx >= wheelX - wheelItemW / 2 and mx <= wheelX + wheelItemW / 2
					and my >= iy - wheelItemH / 2 and my <= iy + wheelItemH / 2 then
					hovered = i
					break
				end
			end
			lastHoveredWheelItem = hovered
		end)

		-- InputCallback for scroll and click
		screen:AddInputCallback(function(event)
			if event.type == "InputEventType_Release" then return end
			local btn = event.DeviceInput.button

			-- Mouse wheel -> scroll the MusicWheel directly
			local scroll = GetMouseScrollDirection(btn)
			if scroll ~= 0 then
				local scr = SCREENMAN:GetTopScreen()
				if scr then
					local mw = scr:GetMusicWheel()
					if mw then
						mw:Move(scroll)
						mw:Move(0) -- flush the move
					end
				end
				return
			end

			-- Mouse left click
			if IsMouseLeftClick(btn) then
				local scr = SCREENMAN:GetTopScreen()
				if not scr then return end

				-- Click on a wheel item
				if lastHoveredWheelItem then
					local mw = scr:GetMusicWheel()
					if mw then
						-- Move the wheel to the clicked item first
						if lastHoveredWheelItem ~= 0 then
							for _ = 1, math.abs(lastHoveredWheelItem) do
								if lastHoveredWheelItem > 0 then
									mw:Move(1)
								else
									mw:Move(-1)
								end
							end
							mw:Move(0) -- flush
						else
							-- Already centered, simulate pressing Start to select/open
							mw:Select()
						end
					end
				end
				return
			end
		end)
	end
}

return t
