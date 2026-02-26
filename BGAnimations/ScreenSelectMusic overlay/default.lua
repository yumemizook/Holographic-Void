--- Holographic Void: ScreenSelectMusic Overlay
-- Restore sequential Til Death-style login flow.

local accentColor = color("#5ABAFF")
local brightText = color("1,1,1,1")

-- Login Button Constants
local btnCX = 8 + (SCREEN_WIDTH * 0.36) / 2
local btnCY = SCREEN_BOTTOM - 24
local btnW, btnH = 180, 28

-- Profile Overlay Constants
local overlayW, overlayH = SCREEN_WIDTH * 0.8, SCREEN_HEIGHT * 0.7
local colW, scorePageSize = overlayW / 3, 10
local skillsets = {"Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"}
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local dimText = color("0.45,0.45,0.45,1")
local bgCard = color("0.06,0.06,0.06,0.9")

local profileOverlayActor = nil

local t = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(function(af)
			-- Hover Logic
			local virtualX = INPUTFILTER:GetMouseX()
			local virtualY = INPUTFILTER:GetMouseY()
			
			local over = virtualX >= btnCX - btnW/2 and virtualX <= btnCX + btnW/2
					 and virtualY >= btnCY - btnH/2 and virtualY <= btnCY + btnH/2

			local btn = af:GetChild("LoginButtonUI")
			if btn then
				local bg = btn:GetChild("Bg")
				if over then
					bg:stoptweening():linear(0.1):diffusealpha(1.0):glow(accentColor)
				else
					bg:stoptweening():linear(0.1):diffusealpha(0.8):glow(color("0,0,0,0"))
				end
			end
		end)
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
	LogOutMessageCommand = function(self)
		ThemePrefs.Set("HV_Username", "")
		ThemePrefs.Set("HV_PasswordToken", "")
		ThemePrefs.Save()
	end,
	TriggerLoginFlowMessageCommand = function(self)
		-- Sequential Til Death flow with frame delay to avoid overlaps
		local tempEmail = ""
		easyInputStringOKCancel(
			"Email or Username:", 255, true,
			function(email)
				if email ~= "" then
					tempEmail = email
					self:sleep(0.02):queuecommand("LoginStep2")
				else
					ms.ok("Login Canceled")
				end
			end,
			function() ms.ok("Login Canceled") end
		)

		-- Step 2 Handler
		self:addcommand("LoginStep2", function(self)
			easyInputStringOKCancel(
				"Password:", 255, true,
				function(password)
					if password ~= "" then
						Trace("[HV] Attempting DLMAN:Login for " .. tempEmail)
						DLMAN:Login(tempEmail, password)
					else
						ms.ok("Login Canceled")
					end
				end,
				function() ms.ok("Login Canceled") end
			)
		end)
	end
}

-- Login Button Visuals
t[#t + 1] = Def.ActorFrame {
	Name = "LoginButtonUI",
	InitCommand = function(self)
		self:xy(btnCX, btnCY)
		self:SetUpdateFunction(function(af)
			local loggedIn = DLMAN:IsLoggedIn()
			local bg = af:GetChild("Bg")
			local txt = af:GetChild("Txt")
			if loggedIn then
				txt:settext("LOG OUT")
				bg:diffuse(color("0.1,0.28,0.15,0.8"))
				txt:diffuse(color("0.65,1,0.72,1"))
			else
				txt:settext("LOG IN")
				bg:diffuse(accentColor):diffusealpha(0.8)
				txt:diffuse(brightText)
			end
		end)
	end,
	Def.Quad { Name = "Bg", InitCommand = function(self) self:zoomto(btnW, btnH) end },
	LoadFont("Common Normal") .. { Name = "Txt", InitCommand = function(self) self:zoom(0.4) end }
}

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
						DLMAN:Logout()
						ms.ok("Logged Out")
					else
						MESSAGEMAN:Broadcast("TriggerLoginFlow")
					end
					return true
				end

				-- Check Avatar Click (x=24, y=SCREEN_HEIGHT-90, w=40, h=40)
				local avX, avY, avW, avH = 24, SCREEN_HEIGHT - 90, 40, 40
				local avOver = virtualX >= avX and virtualX <= avX + avW
				           and virtualY >= avY and virtualY <= avY + avH
				if avOver then
					MESSAGEMAN:Broadcast("ToggleProfileOverlay")
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
					local path = nil
					local prof = PROFILEMAN:GetProfile(PLAYER_1)
					if prof and prof.GetAvatarPath then path = prof:GetAvatarPath() end
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
				UpdateOverlaySkillsetsMessageCommand = function(self) self:settext(DLMAN:GetUsername() ~= "" and DLMAN:GetUsername() or "LOCAL PLAYER") end
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
-- CHART PREVIEW TRIGGER (Space key)
-- Opens the dedicated ScreenChartPreview screen
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "ChartPreviewInputHandler",
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end
			local btn = event.DeviceInput.button

			if btn == "DeviceButton_space" then
				-- Pause music before entering preview to avoid double audio overlap
				local ok, _ = pcall(function() SCREENMAN:GetTopScreen():PauseSampleMusic() end)
				SCREENMAN:AddNewScreenToTop("ScreenChartPreview")
				return true
			end
		end)
	end
}

t[#t + 1] = LoadActor("../_cursor")

return t

