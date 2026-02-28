--- Holographic Void: ScreenSelectMusic Overlay
-- Restore sequential Til Death-style login flow.

local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")

-- Compact Profile Login Button Bounds
local panelX = 20
local panelW = SCREEN_WIDTH * 0.36
local compactProfileX = panelX + panelW + 16
local compactProfileY = SCREEN_HEIGHT - 40 - 75

local btnCX = compactProfileX + 40
local btnCY = compactProfileY - 22
local btnW, btnH = 80, 24

-- Profile Overlay Constants
local overlayW, overlayH = SCREEN_WIDTH * 0.8, SCREEN_HEIGHT * 0.7
local colW, scorePageSize = overlayW / 3, 10
local skillsets = {"Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local dimText = color("0.45,0.45,0.45,1")
local bgCard = color("0.06,0.06,0.06,0.9")

local profileOverlayActor = nil
local previewActive = false

local t = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(function(af)
			-- Hover Logic
			local virtualX = INPUTFILTER:GetMouseX()
			local virtualY = INPUTFILTER:GetMouseY()
			
			local over = virtualX >= btnCX - btnW/2 and virtualX <= btnCX + btnW/2
					 and virtualY >= btnCY - btnH/2 and virtualY <= btnCY + btnH/2

			-- Removed: local overlay updating of LoginButtonUI since it was moved to decorations
		end)
	end,
	BeginCommand = function(self)
		-- Store ScreenSelectMusic reference globally for chart preview to use
		HV = HV or {}
		HV.SSM = SCREENMAN:GetTopScreen()
	end,
	EndCommand = function(self)
		SCREENMAN:set_input_redirected(PLAYER_1, false)
		SCREENMAN:set_input_redirected(PLAYER_2, false)
	end,
	LoginMessageCommand = function(self)
		local user = DLMAN:GetUsername()
		local token = DLMAN:GetToken()
		if user and token and user ~= "" and token ~= "" then
			ThemePrefs.Set("HV_Username", user)
			ThemePrefs.Set("HV_PasswordToken", token)
			ThemePrefs.Save()
		end
	end,
	LoginFailedMessageCommand = function(self)
		ms.ok("Login Failed. Please check your credentials.")
	end,
	LogOutMessageCommand = function(self)
		-- Only clear username on manual logout to preserve auto-login token
	end,
	TriggerLoginFlowMessageCommand = function(self)
		-- Sequential Til Death flow with frame delay to avoid overlaps
		local tempEmail = ""
		easyInputStringOKCancel(
			"Email:", 255, true,
			function(email)
				if email ~= "" then
					self.tempEmail = email
					self:sleep(0.02):queuecommand("LoginStep2")
				else
					ms.ok("Login Canceled")
				end
			end,
			function() ms.ok("Login Canceled") end
		)
	end,
	
	LoginStep2Command = function(self)
		easyInputStringOKCancel(
			"Password:", 255, true,
			function(password)
				if password ~= "" then
					Trace("[HV] Attempting DLMAN:Login for " .. tostring(self.tempEmail))
					DLMAN:Login(self.tempEmail, password)
				else
					ms.ok("Login Canceled")
				end
			end,
			function() ms.ok("Login Canceled") end
		)
	end
}

-- LoginButtonUI was moved to decorations/default.lua to nest visually within the profile card.

-- Rate adjustment via CodeMessage (EffectUp/EffectDown mapped in metrics.ini)
local lastRatePresses = {0, 0}

local function adjustRate(delta)
	local curRate = getCurRateValue() or 1.0
	local newRate = math.floor((curRate + delta) * 100 + 0.5) / 100
	newRate = math.max(0.05, math.min(3.0, newRate))
	GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(newRate)
	GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(newRate)
	GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(newRate)
	MESSAGEMAN:Broadcast("CurrentRateChanged")
end

local function resetRate()
	GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(1.0)
	GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(1.0)
	GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(1.0)
	MESSAGEMAN:Broadcast("CurrentRateChanged")
end

-- Centralized Input Callback (Handles Click, Scroll, and both-EffectUp/Down reset)
t[#t + 1] = Def.ActorFrame {
	-- Handle rate changes via CodeMessageCommand (fired by metrics.ini CodeNames)
	CodeMessageCommand = function(self, params)
		if not params or not params.Name then return end
		if params.Name == "NextRate" then
			lastRatePresses[2] = GetTimeSinceStart and GetTimeSinceStart() or os.clock()
			-- Check for simultaneous press (both within 50ms)
			if math.abs(lastRatePresses[1] - lastRatePresses[2]) < 0.05 and lastRatePresses[1] ~= 0 and lastRatePresses[2] ~= 0 then
				resetRate()
			else
				adjustRate(0.05)
			end
		elseif params.Name == "PrevRate" then
			lastRatePresses[1] = GetTimeSinceStart and GetTimeSinceStart() or os.clock()
			if math.abs(lastRatePresses[1] - lastRatePresses[2]) < 0.05 and lastRatePresses[1] ~= 0 and lastRatePresses[2] ~= 0 then
				resetRate()
			else
				adjustRate(-0.05)
			end
		end
	end,
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			local deviceInput = event.DeviceInput or {}
			local btn = deviceInput.button or ""
			local gameBtn = event.GameButton or ""

			if event.type ~= "InputEventType_FirstPress" then return end

			-- 1. Mouse Scroll
			local scroll = 0
			if btn == "DeviceButton_mousewheel up" then scroll = -1
			elseif btn == "DeviceButton_mousewheel down" then scroll = 1 end
			if scroll ~= 0 then
				local mw = screen:GetMusicWheel()
				if mw then mw:Move(scroll) mw:Move(0) end
				return true
			end

			-- 2. Mouse Click
			if btn == "DeviceButton_left mouse button" then
				local virtualX = INPUTFILTER:GetMouseX()
				local virtualY = INPUTFILTER:GetMouseY()
				
				-- Check Login Button
				local loginOver = virtualX >= btnCX - btnW/2 and virtualX <= btnCX + btnW/2
						 and virtualY >= btnCY - btnH/2 and virtualY <= btnCY + btnH/2
				if loginOver then
					if DLMAN:IsLoggedIn() then
						ThemePrefs.Set("HV_Username", "")
						ThemePrefs.Set("HV_PasswordToken", "")
						ThemePrefs.Save()
						DLMAN:Logout()
						ms.ok("Logged Out")
					else
						MESSAGEMAN:Broadcast("TriggerLoginFlow")
					end
					return true
				end

				-- Check Avatar Button
				if virtualX >= compactProfileX - 8 and virtualX <= compactProfileX + 50
				   and virtualY >= compactProfileY - 8 and virtualY <= compactProfileY + 50 then
					SCREENMAN:SetNewScreen("ScreenAssetSettings")
					return true
				end

				-- Check Header `< BACK` Button (0 to 80, 0 to 40)
				if virtualX >= 0 and virtualX <= 80 and virtualY >= 0 and virtualY <= 40 then
					SCREENMAN:GetTopScreen():Cancel()
					return true
				end

				-- Check Header `SEARCH` Bar (Center)
				local searchStartX = SCREEN_WIDTH / 2 - 150
				local searchStartY = 6
				if virtualX >= searchStartX and virtualX <= searchStartX + 300 
				   and virtualY >= searchStartY and virtualY <= searchStartY + 28 then
					MESSAGEMAN:Broadcast("ToggleSearchOverlay")
					return true
				end

				-- Check Footer Tab Buttons
				local footerY = SCREEN_HEIGHT - 40
				local tabW = 80
				local tabs = {"PROFILE", "SCORES", "FILTERS", "PLAYLISTS", "TAGS", "GOALS"}
				
				for i, tabName in ipairs(tabs) do
					local tx = 10 + (i - 1) * tabW
					if virtualX >= tx and virtualX <= tx + tabW and virtualY >= footerY and virtualY <= SCREEN_HEIGHT then
						if tabName == "PROFILE" then
							MESSAGEMAN:Broadcast("ToggleProfileOverlay")
						else
							-- Placeholder for other tabs
							MESSAGEMAN:Broadcast("Toggle" .. tabName .. "Overlay")
						end
						return true
					end
				end
			end
			
			-- 3. Key Presses
			if event.type == "InputEventType_FirstPress" then
				if event.button == "4" and (INPUTFILTER:IsBeingPressed("left ctrl") or INPUTFILTER:IsBeingPressed("right ctrl")) then
					MESSAGEMAN:Broadcast("ToggleSearchOverlay")
					return true
				end
			end
		end)
	end
}


-- ============================================================
-- PROFILE OVERLAY
-- ============================================================

-- ============================================================
-- PROFILE OVERLAY REDESIGN (Sidebar + Main)
-- ============================================================

local sidebarW = 160
local mainPartW = overlayW - sidebarW
local skillsetTabH = 26
local rowH = 30

local profileOverlay = Def.ActorFrame {
	Name = "ProfileOverlay",
	InitCommand = function(self)
		profileOverlayActor = self
		self.topPage = 1
		self.recentPage = 1
		self.currentSkillset = "Overall"
		self.isRecentMode = false
		self.isOnlineMode = true
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(false)
	end,
	-- Dark Background (Dim the rest of the screen)
	Def.Quad {
		InitCommand = function(self) self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,0.85")) end,
		BeginCommand = function(self)
			SCREENMAN:GetTopScreen():AddInputCallback(function(event)
				if profileOverlayActor and profileOverlayActor:GetVisible() then
					local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
					
					-- 1. Handle Closing (Click Outside)
					if event.type == "InputEventType_FirstPress" and IsMouseLeftClick(event.DeviceInput.button) then
						if not IsMouseOverCentered(SCREEN_CENTER_X, SCREEN_CENTER_Y, overlayW, overlayH) then
							MESSAGEMAN:Broadcast("ToggleProfileOverlay")
							return true
						end
					end

					-- 2. Handle Actions (Buttons, Tabs)
					local sidebarX = SCREEN_CENTER_X - overlayW/2
					if event.type == "InputEventType_FirstPress" then
						local mainAreaCenterX = SCREEN_CENTER_X + sidebarW/2
						local headerY = SCREEN_CENTER_Y - overlayH/2 + 35
						
						-- Mode Toggle (TOP / RECENT)
						if IsMouseOverCentered(mainAreaCenterX + (mainPartW/2 - 250), headerY, 100, 24) then
							profileOverlayActor.isRecentMode = not profileOverlayActor.isRecentMode
							profileOverlayActor.topPage = 1
							profileOverlayActor.recentPage = 1
							MESSAGEMAN:Broadcast("UpdateOverlayUI")
							return true
						end
						
						-- Source Toggle (ONLINE / LOCAL) — disabled in recent mode
						if IsMouseOverCentered(mainAreaCenterX + (mainPartW/2 - 140), headerY, 100, 24) then
							if not profileOverlayActor.isRecentMode then
								profileOverlayActor.isOnlineMode = not profileOverlayActor.isOnlineMode
								profileOverlayActor.topPage = 1
								MESSAGEMAN:Broadcast("UpdateOverlayUI")
							end
							return true
						end
						
						-- Upload Button
						if IsMouseOverCentered(mainAreaCenterX + (mainPartW/2 - 40), headerY, 80, 24) then
							if DLMAN:IsLoggedIn() then
								DLMAN:UploadAllScores()
								SCREENMAN:SystemMessage("Uploading all scores...")
							else
								ms.ok("Log in to upload scores.")
							end
							return true
						end

						-- Avatar Click inside overlay
						local overlayAvX = SCREEN_CENTER_X - overlayW/2 + sidebarW/2
						local overlayAvY = SCREEN_CENTER_Y - overlayH/2 + 50
						if IsMouseOverCentered(overlayAvX, overlayAvY, 60, 60) then
							SCREENMAN:SetNewScreen("ScreenAssetSettings")
							return true
						end
						
						-- Skillset Tabs

						local tabsYStart = SCREEN_CENTER_Y - overlayH/2 + 140
						for i, ss in ipairs(skillsets) do
							if IsMouseOver(sidebarX + 10, tabsYStart + (i-1)*skillsetTabH - skillsetTabH/2, sidebarW - 20, skillsetTabH) then
								profileOverlayActor.currentSkillset = ss
								profileOverlayActor.isRecentMode = false
								profileOverlayActor.topPage = 1
								MESSAGEMAN:Broadcast("UpdateOverlayUI")
								return true
							end
						end
						
						-- Score Row Clicks (Left = Find Song, Right = Validate)
						local rowsYStart = SCREEN_CENTER_Y - overlayH/2 + 65
						for i = 1, scorePageSize do
							local rowTop = rowsYStart + (i-1)*rowH - rowH/2
							if IsMouseOver(sidebarX + sidebarW + 10, rowTop, mainPartW - 20, rowH) then
								MESSAGEMAN:Broadcast("OverlayRowClicked", {index = i})
								return true
							end
						end
					end
					
					if event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_right mouse button" then
						local rowsYStart = SCREEN_CENTER_Y - overlayH/2 + 65
						for i = 1, scorePageSize do
							local rowTop = rowsYStart + (i-1)*rowH - rowH/2
							if IsMouseOver(sidebarX + sidebarW + 10, rowTop, mainPartW - 20, rowH) then
								MESSAGEMAN:Broadcast("OverlayRowRightClicked", {index = i})
								return true
							end
						end
					end
					
					-- 3. Handle Pagination (Wheel and Keys)
					if event.type == "InputEventType_FirstPress" then
						local dir = 0
						if event.DeviceInput.button == "DeviceButton_left" or event.DeviceInput.button == "DeviceButton_up" or event.DeviceInput.button == "DeviceButton_mousewheel up" then
							dir = -1
						elseif event.DeviceInput.button == "DeviceButton_right" or event.DeviceInput.button == "DeviceButton_down" or event.DeviceInput.button == "DeviceButton_mousewheel down" then
							dir = 1
						end
						
						if dir ~= 0 then
							if dir == -1 then MESSAGEMAN:Broadcast("PrevScorePage")
							else MESSAGEMAN:Broadcast("NextScorePage") end
							return true
						end
					end
					
					-- 4. Sink all other input
					return true
				end
			end)
		end
	},
	-- Main Panel BG
	Def.Quad { InitCommand = function(self) self:zoomto(overlayW, overlayH):diffuse(bgCard):diffusealpha(0.98) end },
	
	-- Sidebar Construction
	Def.ActorFrame {
		Name = "Sidebar",
		InitCommand = function(self) self:x(-overlayW/2 + sidebarW/2) end,
		Def.Quad { InitCommand = function(self) self:zoomto(sidebarW, overlayH):diffuse(color("0.08,0.08,0.08,1")) end },
		
		-- Avatar / Info
		Def.ActorFrame {
			Name = "PlayerInfo",
			InitCommand = function(self) self:y(-overlayH/2 + 50) end,
			Def.Quad { Name = "Bg", InitCommand = function(self) self:zoomto(54, 54):diffuse(color("0,0,0,0.5")) end },
			Def.Sprite {
				Name = "Avatar",
				InitCommand = function(self) self:zoomto(54, 54):playcommand("UpdateAvatar") end,
				UpdateOverlaySkillsetsMessageCommand = function(self) self:playcommand("UpdateAvatar") end,
				AvatarChangedMessageCommand = function(self) self:playcommand("UpdateAvatar") end,
				UpdateAvatarCommand = function(self)
					local path = getAvatarPath()
					if path and path ~= "" and FILEMAN:DoesFileExist(path) then
						self:Load(path):visible(true)
					else
						self:visible(false)
					end
					self:scaletoclipped(54, 54)
				end
			},

			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:y(40):zoom(0.4):diffuse(brightText) end,
				UpdateOverlaySkillsetsMessageCommand = function(self)
					local name = DLMAN:GetUsername() ~= "" and DLMAN:GetUsername() or (PROFILEMAN:GetProfile(PLAYER_1) and PROFILEMAN:GetProfile(PLAYER_1):GetDisplayName() or "LOCAL PLAYER")
					self:settext(name)
				end
			},
			LoadFont("Common Normal") .. {
				Name = "Rating",
				InitCommand = function(self) self:y(56):zoom(0.35):diffuse(accentColor) end,
				UpdateOverlaySkillsetsMessageCommand = function(self)
					local val = 0
					local prof = PROFILEMAN:GetProfile(PLAYER_1)
					if DLMAN:IsLoggedIn() and profileOverlayActor.isOnlineMode then 
						val = DLMAN:GetSkillsetRating("Overall")
					elseif prof then
						val = prof:GetPlayerRating()
					end
					self:settext(string.format("%.2f", val)):diffuse(HVColor.GetMSDRatingColor(val))
				end
			}
		},

		-- Vertical Skillset Tabs
		(function()
			local tabs = Def.ActorFrame {
				Name = "SkillsetTabs",
				InitCommand = function(self) self:y(-overlayH/2 + 140) end
			}
			for i, ss in ipairs(skillsets) do
				tabs[#tabs+1] = Def.ActorFrame {
					Name = "Tab_" .. ss,
					InitCommand = function(self) self:y((i-1) * skillsetTabH) end,
					Def.Quad {
						Name = "Bg",
						InitCommand = function(self) self:zoomto(sidebarW - 20, skillsetTabH - 4):halign(0):x(-sidebarW/2 + 10):diffuse(bgCard):diffusealpha(0.5) end
					},
					LoadFont("Common Normal") .. {
						Name = "Label",
						InitCommand = function(self) self:halign(0):x(-sidebarW/2 + 20):zoom(0.32):diffuse(subText):settext(ss:upper()) end
					},
					LoadFont("Common Normal") .. {
						Name = "Val",
						InitCommand = function(self) self:halign(1):x(sidebarW/2 - 20):zoom(0.32):diffuse(mainText) end,
						UpdateOverlaySkillsetsMessageCommand = function(self)
							local val = 0
							local prof = PROFILEMAN:GetProfile(PLAYER_1)
							if DLMAN:IsLoggedIn() and profileOverlayActor.isOnlineMode then 
								val = DLMAN:GetSkillsetRating(ss)
							elseif prof then
								if ss == "Overall" then val = prof:GetPlayerRating()
								else val = prof:GetPlayerSkillsetRating(i-2) or 0 end
							end
							self:settext(string.format("%.2f", val)):diffuse(HVColor.GetMSDRatingColor(val))
						end
					},
					SetUpdateFunction = function(af)
						local mouseX = INPUTFILTER:GetMouseX()
						local mouseY = INPUTFILTER:GetMouseY()
						local parent = profileOverlayActor
						if not parent or not parent:GetVisible() then return end
						
						local rx = mouseX - (SCREEN_CENTER_X - overlayW/2)
						local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
						
						local over = rx >= 10 and rx <= sidebarW - 10 
						         and ry >= (140 + (i-1)*skillsetTabH - skillsetTabH/2) 
								 and ry <= (140 + (i-1)*skillsetTabH + skillsetTabH/2)
						
						local bg = af:GetChild("Bg")
						local active = (parent.currentSkillset == ss) and not parent.isRecentMode
						if active then
							bg:diffuse(accentColor):diffusealpha(0.3)
						elseif over then
							bg:diffuse(color("0.3,0.3,0.3,0.5"))
						else
							bg:diffuse(bgCard):diffusealpha(0.5)
						end
					end
				}
			end
			return tabs
		end)(),
	},
	
	-- Main Area
	Def.ActorFrame {
		Name = "MainArea",
		InitCommand = function(self) self:x(sidebarW/2) end,
		-- Area Header
		Def.ActorFrame {
			Name = "MainHeader",
			InitCommand = function(self) self:y(-overlayH/2 + 35) end,
			LoadFont("Common Normal") .. {
				InitCommand = function(self) self:halign(0):x(-mainPartW/2 + 30):zoom(0.5):diffuse(brightText) end,
				UpdateOverlayUIMessageCommand = function(self)
					local p = profileOverlayActor
					if not p then return end
					local modeText
					if p.isRecentMode then
						modeText = "RECENT SCORES (LOCAL)"
					else
						local src = (p.isOnlineMode and DLMAN:IsLoggedIn()) and "ONLINE" or "LOCAL"
						modeText = "TOP SCORES (" .. p.currentSkillset:upper() .. " · " .. src .. ")"
					end
					self:settext(modeText)
				end
			},
			-- Toggle Top/Recent Button
			Def.ActorFrame {
				Name = "ModeToggle",
				InitCommand = function(self) self:x(mainPartW/2 - 250) end,
				Def.Quad {
					Name = "Bg",
					InitCommand = function(self) self:zoomto(100, 24):diffuse(accentColor):diffusealpha(0.2) end
				},
				LoadFont("Common Normal") .. {
					Name = "Txt",
					InitCommand = function(self) self:zoom(0.32):diffuse(brightText):settext("TOP / RECENT") end
				},
				SetUpdateFunction = function(af)
					local mouseX = INPUTFILTER:GetMouseX()
					local mouseY = INPUTFILTER:GetMouseY()
					local parent = profileOverlayActor
					if not parent or not parent:GetVisible() then return end
					local rx = mouseX - (SCREEN_CENTER_X - overlayW/2)
					local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
					local over = rx >= sidebarW + mainPartW - 300 and rx <= sidebarW + mainPartW - 200
					         and ry >= 23 and ry <= 47
					local bg = af:GetChild("Bg")
					if over or parent.isRecentMode then
						bg:diffusealpha(0.5)
					else
						bg:diffusealpha(0.2)
					end
				end
			},
			-- Toggle Online/Local Button
			Def.ActorFrame {
				Name = "SourceToggle",
				InitCommand = function(self) self:x(mainPartW/2 - 140) end,
				Def.Quad {
					Name = "Bg",
					InitCommand = function(self) self:zoomto(100, 24):diffuse(accentColor):diffusealpha(0.2) end
				},
				LoadFont("Common Normal") .. {
					Name = "Txt",
					InitCommand = function(self) self:zoom(0.32) end,
					UpdateOverlayUIMessageCommand = function(self)
						local p = profileOverlayActor
						if p.isRecentMode then
							self:settext("ONLINE/LOCAL"):diffuse(dimText)
						else
							local active = p.isOnlineMode and DLMAN:IsLoggedIn()
							self:settext(active and "ONLINE" or "LOCAL"):diffuse(brightText)
						end
					end
				},
				SetUpdateFunction = function(af)
					local mouseX = INPUTFILTER:GetMouseX()
					local mouseY = INPUTFILTER:GetMouseY()
					local parent = profileOverlayActor
					if not parent or not parent:GetVisible() then return end
					local rx = mouseX - (SCREEN_CENTER_X - overlayW/2)
					local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
					local over = rx >= sidebarW + mainPartW - 190 and rx <= sidebarW + mainPartW - 90
					         and ry >= 23 and ry <= 47
					local bg = af:GetChild("Bg")
					if parent.isRecentMode then
						bg:diffuse(dimText):diffusealpha(0.15)
					elseif over or (parent.isOnlineMode and DLMAN:IsLoggedIn()) then
						bg:diffuse(accentColor):diffusealpha(0.5)
					else
						bg:diffuse(accentColor):diffusealpha(0.2)
					end
				end
			},
			-- Upload All Button
			Def.ActorFrame {
				Name = "UploadBtn",
				InitCommand = function(self) self:x(mainPartW/2 - 40) end,
				Def.Quad {
					Name = "Bg",
					InitCommand = function(self) self:zoomto(80, 24):diffuse(color("0.1,0.4,0.1,0.5")) end
				},
				LoadFont("Common Normal") .. {
					InitCommand = function(self) self:zoom(0.32):diffuse(brightText):settext("UPLOAD ALL") end
				},
				SetUpdateFunction = function(af)
					local mouseX = INPUTFILTER:GetMouseX()
					local mouseY = INPUTFILTER:GetMouseY()
					local parent = profileOverlayActor
					if not parent or not parent:GetVisible() then return end
					local rx = mouseX - (SCREEN_CENTER_X - overlayW/2)
					local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
					local over = rx >= sidebarW + mainPartW - 80 and rx <= sidebarW + mainPartW and ry >= 23 and ry <= 47
					local bg = af:GetChild("Bg")
					if over then
						bg:diffusealpha(0.8)
					else
						bg:diffusealpha(0.5)
					end
				end
			}
		},
		
		-- Score List Rows
		(function()
			local rows = Def.ActorFrame {
				Name = "ScoreListRows",
				InitCommand = function(self) self:y(-overlayH/2 + 65) end
			}
			for i = 1, scorePageSize do
				rows[#rows+1] = Def.ActorFrame {
					Name = "Row_" .. i,
					InitCommand = function(self) self:y((i-1) * rowH) end,
					Def.Quad {
						Name = "Bg",
						InitCommand = function(self) self:zoomto(mainPartW - 40, rowH - 4):diffuse(color("0,0,0,0.3")) end
					},
					LoadFont("Common Normal") .. {
						Name = "SSR",
						InitCommand = function(self) self:halign(0):x(-mainPartW/2 + 30):zoom(0.4) end
					},
					LoadFont("zpix/_zpix 20px") .. {
						Name = "Title",
						InitCommand = function(self) self:halign(0):x(-mainPartW/2 + 90):y(-5):zoom(0.35):diffuse(brightText):maxwidth(400 * 1.5) end
					},
					LoadFont("Common Normal") .. {
						Name = "Details",
						InitCommand = function(self) self:halign(0):x(-mainPartW/2 + 90):y(7):zoom(0.25):diffuse(dimText) end
					},
					LoadFont("Common Normal") .. {
						Name = "Percent",
						InitCommand = function(self) self:halign(1):x(mainPartW/2 - 100):zoom(0.42):diffuse(accentColor) end
					},
					LoadFont("Common Normal") .. {
						Name = "Validation",
						InitCommand = function(self) self:halign(1):x(mainPartW/2 - 30):zoom(0.3) end
					},
					SetUpdateFunction = function(af)
						local parent = profileOverlayActor
						if not parent or not parent:GetVisible() then return end
						local mouseX = INPUTFILTER:GetMouseX()
						local mouseY = INPUTFILTER:GetMouseY()
						local rx = mouseX - (SCREEN_CENTER_X - overlayW/2)
						local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
						local rowTop = 65 + (i-1)*rowH - rowH/2
						local rowBottom = rowTop + rowH
						local over = rx >= sidebarW + 10 and rx <= overlayW - 10 and ry >= rowTop and ry <= rowBottom
						local bg = af:GetChild("Bg")
						local score = af.currentScore
						if score and type(score) ~= "table" and not score:GetEtternaValid() then
							bg:diffuse(color("0.5,0.2,0.2,0.3"))
						else
							bg:diffuse(color("0,0,0,0.3"))
						end
						if over then
							bg:diffusealpha(0.6)
						end
					end,
					OverlayRowClickedMessageCommand = function(self, params)
						if params.index ~= i then return end
						local score = self.currentScore
						if not score then return end
						local ck = (type(score)=="table") and score.chartkey or score:GetChartKey()
						if not ck then return end
						local song = SONGMAN:GetSongByChartKey(ck)
						if song then
							local screen = SCREENMAN:GetTopScreen()
							if screen and screen.GetMusicWheel then
								screen:GetMusicWheel():SelectSong(song)
							end
						end
						MESSAGEMAN:Broadcast("ToggleProfileOverlay")
					end,
					OverlayRowRightClickedMessageCommand = function(self, params)
						if params.index ~= i then return end
						local score = self.currentScore
						if not score or type(score) == "table" then return end
						score:ToggleEtternaValidation()
						if score:GetEtternaValid() then
							ms.ok("Score validated")
						else
							ms.ok("Score invalidated")
						end
						MESSAGEMAN:Broadcast("UpdateOverlayUI")
					end
				}
			end
			return rows
		end)(),
		-- Footer Pagination
		LoadFont("Common Normal") .. {
			InitCommand = function(self) self:y(overlayH/2 - 25):zoom(0.35):diffuse(dimText) end,
			UpdateOverlayUIMessageCommand = function(self)
				local p = profileOverlayActor
				if not p then return end
				local cur = p.isRecentMode and p.recentPage or p.topPage
				self:settext("PAGE " .. cur .. " · CLICK TO FIND SONG · RIGHT-CLICK TO VALIDATE (LOCAL)")
			end
		}
	},

	-- Core Logic Signals
	UpdateOverlayUIMessageCommand = function(self) self:playcommand("UpdateAllScores") end,
	ToggleProfileOverlayMessageCommand = function(self)
		local iv = self:GetVisible()
		self:visible(not iv)
		SCREENMAN:set_input_redirected(PLAYER_1, not iv)
		SCREENMAN:set_input_redirected(PLAYER_2, not iv)
		if not iv then self:playcommand("UpdateAllScores") end
	end,

	UpdateAllScoresCommand = function(self)
		local rows = self:GetChild("MainArea"):GetChild("ScoreListRows")
		local start = ((self.isRecentMode and self.recentPage or self.topPage) - 1) * scorePageSize

		if self.isRecentMode then
			-- Recent scores are always local regardless of isOnlineMode
			SCOREMAN:SortRecentScoresForGame()
		elseif not self.isOnlineMode then
			SCOREMAN:SortSSRsForGame(self.currentSkillset)
		end
		
		for i = 1, scorePageSize do
			local row = rows:GetChild("Row_" .. i)
			local idx = start + i
			local score = nil
			
			if self.isRecentMode then
				-- Recent scores are always local regardless of isOnlineMode
				local ok, res = pcall(function() return SCOREMAN:GetRecentScoreForGame(idx) end)
				score = (ok and res ~= nil) and res or nil
			else
				if self.isOnlineMode and DLMAN:IsLoggedIn() then
					local ok, res = pcall(function() return DLMAN:GetTopSkillsetScore(idx, self.currentSkillset) end)
					score = (ok and res ~= nil) and res or nil
				else
					local ok, res = pcall(function() return SCOREMAN:GetTopSSRHighScoreForGame(idx, self.currentSkillset) end)
					score = (ok and res ~= nil) and res or nil
				end
			end
			
			row.currentScore = score
			if score then
				row:visible(true)
				local title, diff, rate, date, wife, ssr
				if type(score) == "table" then
					title = score.songName or "???"
					diff = ToEnumShortString(score.difficulty or "Beginner")
					rate = score.rate or 1.0
					date = score.date or "N/A"
					wife = score.wife or 0
					ssr = score.ssr or 0
				else
					local ck = score:GetChartKey()
					local thssong = SONGMAN:GetSongByChartKey(ck)
					local thssteps = SONGMAN:GetStepsByChartKey(ck)
					title = thssong and thssong:GetDisplayMainTitle() or "???"
					diff = thssteps and ToEnumShortString(thssteps:GetDifficulty()) or "?"
					rate = score:GetMusicRate()
					date = score:GetDate()
					wife = score:GetWifeScore()
					ssr = score:GetSkillsetSSR(self.isRecentMode and "Overall" or self.currentSkillset)
				end
				
				row:GetChild("SSR"):settext(string.format("%.2f", ssr)):diffuse(HVColor.GetMSDRatingColor(ssr))
				row:GetChild("Title"):settext(title)
				row:GetChild("Details"):settext(string.format("%s · %.2fx · %s", diff, rate, date))
				row:GetChild("Percent"):settext(string.format("%.2f%%", wife * 100))
				
				local vLabel = row:GetChild("Validation")
				if type(score) == "table" then
					vLabel:settext("ONLINE"):diffuse(color("0.5,0.7,1,1"))
				else
					if score:GetEtternaValid() then
						vLabel:settext("VALID"):diffuse(color("0.4,1,0.4,1"))
					else
						vLabel:settext("INVALID"):diffuse(color("1,0.4,0.4,1"))
					end
				end
				row:GetChild("Bg"):diffuse(color("0,0,0,0.3"))
			else
				row:visible(false)
			end
		end
		
		self:playcommand("UpdateOverlaySkillsets")
		self:GetChild("MainArea"):playcommand("UpdateOverlayUI")
		self:GetChild("Sidebar"):playcommand("UpdateOverlayUI")
	end,

	NextScorePageMessageCommand = function(self)
		if self.isRecentMode then self.recentPage = self.recentPage + 1
		else self.topPage = self.topPage + 1 end
		self:playcommand("UpdateAllScores")
	end,
	PrevScorePageMessageCommand = function(self)
		if self.isRecentMode then self.recentPage = math.max(1, self.recentPage - 1)
		else self.topPage = math.max(1, self.topPage - 1) end
		self:playcommand("UpdateAllScores")
	end
}

t[#t + 1] = profileOverlay

-- ============================================================
-- TOP HEADER (Search & Back)
-- ============================================================
local headerH = 40
t[#t + 1] = Def.ActorFrame {
	Name = "HeaderBar",
	InitCommand = function(self)
		self:xy(0, 0)
	end,
	
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
				:zoomto(SCREEN_WIDTH, headerH)
				:diffuse(color("0.04,0.04,0.04,1"))
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(1)
				:xy(0, headerH)
				:zoomto(SCREEN_WIDTH, 2)
				:diffuse(accentColor):diffusealpha(0.5)
		end
	},
	
	-- Back Button
	Def.ActorFrame {
		Name = "BtnBack",
		InitCommand = function(self) self:xy(0, 0) end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(80, headerH):diffuse(color("0,0,0,0"))
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):xy(40, headerH / 2):zoom(0.4):diffuse(mainText):settext("< BACK")
			end
		}
	},
	
	-- Search Bar Frame
	Def.ActorFrame {
		Name = "SearchBar",
		InitCommand = function(self) self:xy(SCREEN_WIDTH / 2 - 150, 6) end,
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(300, 28)
					:diffuse(color("0.1,0.1,0.1,1"))
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0.5):valign(0.5):xy(150, 14):zoom(0.35):diffuse(subText):settext("Click here to Search (or Ctrl + 4)")
			end
		}
	}
}

-- ============================================================
-- BOTTOM FOOTER & TAB BUTTONS
-- ============================================================
local tabs = {"PROFILE", "SCORES", "FILTERS", "PLAYLISTS", "TAGS", "GOALS"}
local tabW = 80
local footerH = 40

t[#t + 1] = Def.ActorFrame {
	Name = "FooterBar",
	InitCommand = function(self)
		self:xy(0, SCREEN_HEIGHT - footerH)
	end,
	
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
				:zoomto(SCREEN_WIDTH, footerH)
				:diffuse(color("0.04,0.04,0.04,1"))
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
				:zoomto(SCREEN_WIDTH, 2)
				:diffuse(accentColor):diffusealpha(0.5)
		end
	},
	
	-- Time Display (Right aligned)
	LoadFont("Common Normal") .. {
		Name = "TimeDisplay",
		InitCommand = function(self)
			self:halign(1):valign(0.5)
				:xy(SCREEN_WIDTH - 20, footerH / 2)
				:zoom(0.35)
				:settext(os.date("%H:%M"))
		end,
		UpdateCommand = function(self)
			self:settext(os.date("%H:%M"))
		end
	}
}

-- Create Tab Buttons on Footer
for i, tabName in ipairs(tabs) do
	t[#t + 1] = Def.ActorFrame {
		Name = "FooterTab_" .. tabName,
		InitCommand = function(self)
			self:xy(10 + (i - 1) * tabW, SCREEN_HEIGHT - footerH)
		end,
		
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:halign(0):valign(0)
					:zoomto(tabW, footerH)
					:diffuse(color("0,0,0,0"))
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0.5):valign(0.5)
					:xy(tabW / 2, footerH / 2)
					:zoom(0.35):diffuse(mainText)
					:settext(tabName)
			end
		}
	}
end

-- ============================================================
-- CHART PREVIEW TRIGGER (Space key)
-- Opens the dedicated ScreenChartPreview screen
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "ChartPreviewInputHandler",
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		-- Store SSM reference (redundant now but kept for compatibility)
		if HV then HV.SSM = screen end
		
		screen:AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end
			local btn = event.DeviceInput.button

			if btn == "DeviceButton_space" then
				if previewActive then
					previewActive = false
					MESSAGEMAN:Broadcast("ChartPreviewOff")
				else
					previewActive = true
					MESSAGEMAN:Broadcast("ChartPreviewOn")
				end
				return true
			end
			
			-- Handle input when preview is active
			if previewActive then
				-- Close preview on Esc or Back
				if event.button == "Back" or event.button == "Start" then
					previewActive = false
					MESSAGEMAN:Broadcast("ChartPreviewOff")
					return true
				end
				
				-- Block all other inputs while preview is active
				return true
			end
		end)
	end
}

-- Load the Chart Preview layer (initially hidden)
t[#t + 1] = LoadActor("../ScreenChartPreview overlay/default.lua") .. {
	InitCommand = function(self)
		self:visible(false)
	end
}

t[#t + 1] = LoadActor("../_cursor")

return t

