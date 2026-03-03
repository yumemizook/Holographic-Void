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
local globalTooltipActor = nil
local previewActive = false
local inputDebugActor = nil

-- Mouse wheel locking to prevent double-moves
local lastWheelMove = 0
local wheelLockTime = 0.05

-- Bottom Footer Config (Top-level for scope)
local tabs = {"PROFILE", "SCORES", "FILTERS", "PLAYLISTS", "TAGS", "GOALS"}
local tabW = 80
local footerH = 40

local main_af = Def.ActorFrame {
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
		HV.ActiveTab = ""
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
	local nr = math.floor((curRate + delta) * 100 + 0.5) / 100
	nr = math.max(0.05, math.min(3.0, nr))
	local songOpts = GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred")
	if songOpts then
		songOpts:MusicRate(nr)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(nr)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(nr)
		MESSAGEMAN:Broadcast("CurrentRateChanged")
	end
end

local function resetRate()
	local songOpts = GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred")
	if songOpts then
		songOpts:MusicRate(1.0)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(1.0)
		GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(1.0)
		MESSAGEMAN:Broadcast("CurrentRateChanged")
	end
end

-- Centralized Input Callback (Handles Click, Scroll, and both-EffectUp/Down reset)
main_af[#main_af + 1] = Def.ActorFrame {
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

		-- Always cleanup any existing callback from a previous load
		if HV.OverlayInputCallback then
			pcall(function() screen:RemoveInputCallback(HV.OverlayInputCallback) end)
		end

		HV.OverlayInputCallback = function(event)
			-- Strict nil checks to prevent script crashes
			if not event or not event.DeviceInput then return false end

			-- Screen state awareness: Only handle input if we are the top screen
			-- This prevents blocking overlays like ScreenTextEntry (naming/login)
			local top = SCREENMAN:GetTopScreen()
			if not top or top:GetName() ~= "ScreenSelectMusic" then return false end
			
			-- Banish inputs processing if chart preview is active so clicks don't leak through
			if previewActive then return false end
			
			local deviceInput = event.DeviceInput
			local btn = deviceInput.button or ""
			local evType = event.type or ""
			
			-- Log to the isolated debugger if it's loaded
			if HV_DEBUG_LOG then
				HV_DEBUG_LOG(string.format("Input: %s (%s)", tostring(btn), tostring(evType)))
			end

			-- 2. Mouse Click
			-- Right-click to pause/unpause sample music
			if btn == "DeviceButton_right mouse button" and evType == "InputEventType_FirstPress" then
				local screen = SCREENMAN:GetTopScreen()
				if screen and screen.PauseSampleMusic then
					screen:PauseSampleMusic()
					MESSAGEMAN:Broadcast("MusicPauseToggled")
				end
				return true
			end
			if btn == "DeviceButton_left mouse button" and evType == "InputEventType_FirstPress" then
				-- Skip general overlay buttons (Login, etc.) if a tab is busy
				if HV.ActiveTab ~= "" then return false end

				local virtualX = INPUTFILTER:GetMouseX()
				local virtualY = INPUTFILTER:GetMouseY()
				
				-- Check Login Button logic (btnCX/btnCY defined above)
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
					screen:Cancel()
					return true
				end

				-- Check Header `SEARCH` Bar (Center)
				local searchStartX = SCREEN_WIDTH / 2 - 150
				local searchStartY = 6
				if virtualX >= searchStartX and virtualX <= searchStartX + 300 
				   and virtualY >= searchStartY and virtualY <= searchStartY + 28 then
					if evType == "InputEventType_FirstPress" then
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = "SEARCH"})
					end
					return true
				end

				-- Check Footer Tab Buttons (Uses top-level 'tabs', 'tabW', 'footerH')
				local footerY = SCREEN_HEIGHT - footerH
				for i, tabName in ipairs(tabs) do
					local tx = 10 + (i - 1) * tabW
					if virtualX >= tx and virtualX <= tx + tabW and virtualY >= footerY and virtualY <= SCREEN_HEIGHT then
						local target = tabName:upper()
						if target == "PROFILE" then target = "SOCIAL" end -- Map profile to SOCIAL internally for theme parity? (Wait, I used PROFILE in decorations)
						
						-- Close if the SAME tab is clicked
						if HV.ActiveTab == tabName:upper() then
							MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
						else
							MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = tabName:upper()})
						end
						return true
					end
				end

				-- 2.5 Music Wheel Click Selection
				-- BLOCKED if an overlay tab is open
				local mwX = SCREEN_WIDTH - 180
				if HV.ActiveTab == "" and virtualX >= mwX - 180 and virtualX <= SCREEN_WIDTH then
					local mw = screen:GetMusicWheel()
					if mw then
						local diffY = virtualY - SCREEN_CENTER_Y
						if math.abs(diffY) <= 20 then
							return false -- Let center click pass to engine for Start
						else
							if evType == "InputEventType_FirstPress" then
								local offset = math.floor(diffY / 40 + 0.5)
								if offset ~= 0 then
									mw:Move(offset)
									mw:Move(0)
								end
							end
							return true
						end
					end
				end

				-- If an overlay is active, we generally want to return false here
				-- so that the decoration tab's own InputCallback can handle the click.
				-- However, we still handle footer/header buttons above.
				if HV.ActiveTab ~= "" then
					return false
				end
			end
			
			-- 2.6 Mouse Wheel & Keyboard Navigation
			-- BLOCKED if an overlay tab is open
			local navigationBtns = {
				["DeviceButton_mousewheel up"] = -1,
				["DeviceButton_mousewheel down"] = 1,
				["DeviceButton_left"] = -1,
				["DeviceButton_right"] = 1,
				["DeviceButton_up"] = -1,
				["DeviceButton_down"] = 1,
			}
			local gameBtnDirs = {
				["MenuLeft"] = -1,
				["MenuRight"] = 1,
				["MenuUp"] = -1,
				["MenuDown"] = 1,
			}
			local logicalBtn = event.button or ""
			
			local dir = navigationBtns[btn] or gameBtnDirs[logicalBtn]
			
			if dir then
				if HV.ActiveTab ~= "" then
					if evType == "InputEventType_FirstPress" or evType == "InputEventType_Repeat" then
						MESSAGEMAN:Broadcast("TabNavigation", {dir = dir})
					end
					return true 
				end
				
				if evType == "InputEventType_FirstPress" or evType == "InputEventType_Repeat" then
					if btn == "DeviceButton_mousewheel up" or btn == "DeviceButton_mousewheel down" then
						local now = (GetTimeSinceStart and GetTimeSinceStart()) or os.clock()
						if now - lastWheelMove < wheelLockTime then return true end
						
						local mw = screen:GetMusicWheel()
						if mw then
							mw:Move(dir)
							mw:Move(0)
							lastWheelMove = now
						end
						return true
					end
					-- Let other nav keys (left/right/up/down) fall through to the engine if no tab is open
				end
			end

			
			-- 3. Key Presses (Global Shortcuts)
			if evType == "InputEventType_FirstPress" then
				local ctrl = INPUTFILTER:IsBeingPressed("left ctrl") or INPUTFILTER:IsBeingPressed("right ctrl")
				if ctrl then
					if btn == "DeviceButton_4" then
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = "SEARCH"})
						return true
					elseif btn == "DeviceButton_0" then
						MESSAGEMAN:Broadcast("ToggleInputDebugger")
						return true
					end
				end
			end
		end -- end of HV.OverlayInputCallback
		screen:AddInputCallback(HV.OverlayInputCallback)
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
local rowH = 26
local rowsYStart = 60

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
							MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""})
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
						local absRowsYStart = SCREEN_CENTER_Y - overlayH/2 + rowsYStart
						for i = 1, scorePageSize do
							local rowTop = absRowsYStart + (i-1)*rowH - rowH/2
							if IsMouseOver(sidebarX + sidebarW + 10, rowTop, mainPartW - 20, rowH) then
								MESSAGEMAN:Broadcast("OverlayRowClicked", {index = i})
								return true
							end
						end
					end
					
					if event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_right mouse button" then
						local absRowsYStart = SCREEN_CENTER_Y - overlayH/2 + rowsYStart
						for i = 1, scorePageSize do
							local rowTop = absRowsYStart + (i-1)*rowH - rowH/2
							if IsMouseOver(sidebarX + sidebarW + 10, rowTop, mainPartW - 20, rowH) then
								MESSAGEMAN:Broadcast("OverlayRowRightClicked", {index = i})
								return true
							end
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
		Def.Quad { InitCommand = function(self) self:zoomto(sidebarW, overlayH):diffuse(color("0.07,0.07,0.07,1")) end },
		
		-- Sidebar Separator with Glow
		Def.Quad {
			InitCommand = function(self) 
				self:halign(1):x(sidebarW/2):zoomto(1, overlayH):diffuse(accentColor):diffusealpha(0.3)
			end
		},
		Def.Quad {
			InitCommand = function(self) 
				self:halign(1):x(sidebarW/2):zoomto(4, overlayH):diffuse(accentColor):diffusealpha(0.1)
			end
		},
		
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
						InitCommand = function(self) self:zoomto(sidebarW - 12, skillsetTabH - 4):halign(0):x(-sidebarW/2 + 6):diffuse(bgCard):diffusealpha(0.4) end
					},
					-- Active bar
					Def.Quad {
						Name = "ActiveBar",
						InitCommand = function(self) self:halign(0):x(-sidebarW/2 + 6):zoomto(3, skillsetTabH - 4):diffuse(accentColor):visible(false) end,
						UpdateOverlayUIActionCommand = function(self)
							local parent = profileOverlayActor
							if not parent then return end
							self:visible(parent.currentSkillset == ss and not parent.isRecentMode)
						end,
						UpdateOverlayUIMessageCommand = function(self) self:playcommand("UpdateOverlayUIAction") end
					},
					LoadFont("Common Normal") .. {
						Name = "Label",
						InitCommand = function(self) self:halign(0):x(-sidebarW/2 + 16):zoom(0.30):diffuse(subText):settext(ss:upper()) end
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
						
						local active = (parent.currentSkillset == ss) and not parent.isRecentMode
						if active then
							bg:diffuse(accentColor):diffusealpha(0.25)
						elseif over then
							bg:diffuse(color("0.3,0.3,0.3,0.3"))
						else
							bg:diffuse(bgCard):diffusealpha(0.4)
						end
						
						-- Handle click
						if over and INPUTFILTER:IsBeingPressed("left mouse button") then
							if parent.currentSkillset ~= ss or parent.isRecentMode then
								parent.currentSkillset = ss
								parent.isRecentMode = false
								parent.topPage = 1
								-- Sort local scores if needed
								if not parent.isOnlineMode then
									SCOREMAN:SortSSRsForGame(ss)
								end
								MESSAGEMAN:Broadcast("UpdateOverlayUI")
							end
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
					InitCommand = function(self) 
						self:zoomto(100, 24):diffuse(accentColor):diffusealpha(0.15)
					end
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
					if parent.isRecentMode then
						bg:diffusealpha(0.4)
					elseif over then
						bg:diffusealpha(0.3)
					else
						bg:diffusealpha(0.15)
					end
				end
			},
			-- Toggle Online/Local Button
			Def.ActorFrame {
				Name = "SourceToggle",
				InitCommand = function(self) self:x(mainPartW/2 - 140) end,
				Def.Quad {
					Name = "Bg",
					InitCommand = function(self) 
						self:zoomto(100, 24):diffuse(accentColor):diffusealpha(0.15)
					end
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
						bg:diffuse(dimText):diffusealpha(0.1)
					elseif (parent.isOnlineMode and DLMAN:IsLoggedIn()) or over then
						bg:diffuse(accentColor):diffusealpha(0.4)
					else
						bg:diffuse(accentColor):diffusealpha(0.15)
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
				InitCommand = function(self) self:y(-overlayH/2 + rowsYStart) end,
			}
			for i = 1, scorePageSize do
				rows[#rows+1] = Def.ActorFrame {
					Name = "Row_" .. i,
					InitCommand = function(self) self:y((i-1) * rowH) end,
					Def.Quad {
						Name = "Bg",
						InitCommand = function(self) 
							self:zoomto(mainPartW - 30, rowH - 4)
								:diffuse(color("0,0,0,0.4"))
								:fadeleft(0.1):faderight(0.1)
						end
					},
					-- Row border accent
					Def.Quad {
						Name = "Border",
						InitCommand = function(self)
							self:zoomto(mainPartW - 30, 1):valign(1):y(rowH/2 - 2)
								:diffuse(accentColor):diffusealpha(0.05)
						end
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
						InitCommand = function(self) self:halign(1):x(mainPartW/2 - 220):zoom(0.42):diffuse(accentColor) end
					},
					LoadFont("Common Normal") .. {
						Name = "Validation",
						InitCommand = function(self) self:halign(1):x(mainPartW/2 - 30):zoom(0.28):diffuse(subText) end
					},
					SetUpdateFunction = function(af)
						local parent = profileOverlayActor
						if not parent or not parent:GetVisible() then return end
						local mouseX = INPUTFILTER:GetMouseX()
						local mouseY = INPUTFILTER:GetMouseY()
						local rx = mouseX - (SCREEN_CENTER_X - overlayW/2)
						local ry = mouseY - (SCREEN_CENTER_Y - overlayH/2)
						local rowTop = rowsYStart + (i-1)*rowH - rowH/2
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
						MESSAGEMAN:Broadcast("SelectMusicTabChanged", {Tab = ""}) -- Close on select
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

	UpdateAllScoresCommand = function(self)
		local rows = self:GetChild("MainArea"):GetChild("ScoreListRows")
		local start = ((self.isRecentMode and self.recentPage or self.topPage) - 1) * scorePageSize

		-- Safe Pagination: Instead of checking totals (which might not exist in all versions),
		-- we'll just allow scrolling up to a reasonble limit or until we hit empty rows.
		local maxPage = 100 -- Large enough safety net
		
		local maxPage = 100 -- Logic clamping below will handle real end
		
		if self.isRecentMode then
			SCOREMAN:SortRecentScoresForGame()
		elseif not self.isOnlineMode then
			SCOREMAN:SortSSRsForGame(self.currentSkillset)
		end
		
		local foundAnyOnPage = false
		for i = 1, scorePageSize do
			local row = rows:GetChild("Row_" .. i)
			local idx = start + i - 1 -- Adjust to 0-based for internal APIs
			local score = nil
			
			if self.isRecentMode then
				-- Recent scores are 0-indexed
				local ok, res = pcall(function() return SCOREMAN:GetRecentScoreForGame(idx) end)
				score = (ok and res ~= nil) and res or nil
			else
				if self.isOnlineMode and DLMAN:IsLoggedIn() then
					-- Online scores are 1-indexed
					local ok, res = pcall(function() return DLMAN:GetTopSkillsetScore(idx + 1, self.currentSkillset) end)
					score = (ok and res ~= nil) and res or nil
				else
					local ok, res = pcall(function() return SCOREMAN:GetTopSSRHighScoreForGame(idx, self.currentSkillset) end)
					score = (ok and res ~= nil) and res or nil
				end
			end
			
			row.currentScore = score
			if score then
				foundAnyOnPage = true
				row:visible(true)
				local title, diff, rate, date, wife, ssr, metadata
				if type(score) == "table" then
					title = score.songName or "???"
					diff = ToEnumShortString(score.difficulty or "Beginner")
					rate = score.rate or 1.0
					date = score.date or "N/A"
					wife = score.wife or 0
					ssr = score.ssr or 0
					metadata = "ONLINE"
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
					
					local ct = getDetailedClearType(score)
					local w1 = score:GetTapNoteScore("TapNoteScore_W1")
					local w2 = score:GetTapNoteScore("TapNoteScore_W2")
					local w3 = score:GetTapNoteScore("TapNoteScore_W3")
					local w4 = score:GetTapNoteScore("TapNoteScore_W4")
					local w5 = score:GetTapNoteScore("TapNoteScore_W5")
					local m = score:GetTapNoteScore("TapNoteScore_Miss")
					metadata = string.format("%s  |  %d/%d/%d/%d/%d/%d", THEME:GetString("ClearTypes", ct), w1, w2, w3, w4, w5, m)
				end
				
				row:GetChild("SSR"):settext(string.format("%.2f", ssr)):diffuse(HVColor.GetMSDRatingColor(ssr))
				row:GetChild("Title"):settext(title)
				row:GetChild("Details"):settext(string.format("%s · %.2fx · %s", diff, rate, date))
				
				local pLabel = row:GetChild("Percent")
				if wife >= 0.997 then
					pLabel:settext(string.format("%.4f%%", wife * 100))
				else
					pLabel:settext(string.format("%.2f%%", wife * 100))
				end
				
				-- Use centralized grade colors
				local grade = getWifeGradeTier(wife * 100)
				pLabel:diffuse(HVColor.GetGradeColor(grade))
				
				row:GetChild("Validation"):settext(metadata)
				row:GetChild("Bg"):diffuse(color("0,0,0,0.3"))
			else
				row:visible(false)
			end
		end

		-- Dynamic Clamping: If page is empty and not page 1, go back
		if not foundAnyOnPage and (self.isRecentMode and self.recentPage > 1 or self.topPage > 1) then
			if self.isRecentMode then self.recentPage = self.recentPage - 1
			else self.topPage = self.topPage - 1 end
			self:playcommand("UpdateAllScores")
			return
		end
		
		self:playcommand("UpdateOverlaySkillsets")
		self:GetChild("MainArea"):playcommand("UpdateOverlayUI")
		self:GetChild("Sidebar"):playcommand("UpdateOverlayUI")
	end,

	-- Core Logic Signals
	UpdateOverlayUIMessageCommand = function(self) self:playcommand("UpdateAllScores") end,
	SelectMusicTabChangedMessageCommand = function(self, params)
		HV.ActiveTab = params and params.Tab or ""
		local targetTab = params and params.Tab or ""
		
		-- Set input redirection for ALL tabs to block the C++ MusicWheel
		local redirected = (targetTab ~= "")
		SCREENMAN:set_input_redirected(PLAYER_1, redirected)
		SCREENMAN:set_input_redirected(PLAYER_2, redirected)

		if targetTab == "PROFILE" then
			self:visible(true)
			self:playcommand("UpdateAllScores")
		else
			self:visible(false)
		end
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

main_af[#main_af + 1] = profileOverlay

-- ============================================================
-- TOP HEADER (Search & Back)
-- ============================================================
local headerH = 40
main_af[#main_af + 1] = Def.ActorFrame {
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
			end,
			SelectMusicTabChangedMessageCommand = function(self, params)
				if params.Tab == "SEARCH" then
					self:diffuse(color("0.12,0.12,0.12,1"))
				else
					self:diffuse(color("0.1,0.1,0.1,1"))
				end
			end
		},
		-- Left accent line (glows when search is active)
		Def.Quad {
			Name = "AccentBorder",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(2, 28)
					:diffuse(accentColor):diffusealpha(0)
			end,
			SelectMusicTabChangedMessageCommand = function(self, params)
				if params.Tab == "SEARCH" then
					self:diffusealpha(0.8)
				else
					self:diffusealpha(0)
				end
			end
		},
		Def.Sprite {
			Texture = THEME:GetPathG("", "search.png"),
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(8, 14):zoom(0.45):diffusealpha(0.7)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "SearchPlaceholder",
			InitCommand = function(self)
				self:halign(0):valign(0.5):xy(32, 14):zoom(0.35):diffuse(subText):settext("Click here to Search (or Ctrl + 4)")
			end,
			SearchQueryUpdatedMessageCommand = function(self, params)
				if params and params.query and params.query ~= "" then
					self:settext("Search: " .. params.query):diffuse(brightText)
				else
					self:settext("Click here to Search (or Ctrl + 4)"):diffuse(subText)
				end
			end
		}
	},

	-- Nth Stage Display (Top Right)
	LoadFont("Common Normal") .. {
		Name = "StageDisplay",
		InitCommand = function(self)
			self:halign(1):valign(0.5):xy(SCREEN_WIDTH - 20, headerH / 2):zoom(0.4):diffuse(accentColor)
		end,
		OnCommand = function(self) self:playcommand("Set") end,
		SetCommand = function(self)
			local stageIdx = GAMESTATE:GetCurrentStageIndex() + 1
			local text = "STAGE " .. stageIdx
			
			-- Safely check for GetCurrentStage as it might be nil in some Etterna contexts
			if GAMESTATE.GetCurrentStage then
				local stage = GAMESTATE:GetCurrentStage()
				if stage == "Stage_Extra1" then text = "EXTRA STAGE"
				elseif stage == "Stage_Extra2" then text = "ENCORE EXTRA"
				end
			end
			self:settext(text)
		end
	}
}

-- ============================================================
-- BOTTOM FOOTER & TAB BUTTONS
-- ============================================================
local tabs = {"PROFILE", "SCORES", "FILTERS", "PLAYLISTS", "TAGS", "GOALS"}
local tabW = 80
local footerH = 40

main_af[#main_af + 1] = Def.ActorFrame {
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
	Def.ActorFrame {
		Name = "TimeFrame",
		InitCommand = function(self) self:xy(SCREEN_WIDTH - 20, footerH / 2) end,

		-- Session Time (Wasted human cycles)
		LoadFont("Common Normal") .. {
			Name = "SessionTime",
			InitCommand = function(self)
				self:halign(1):y(10):zoom(0.32):diffuse(dimText)
			end,
			OnCommand = function(self) self:queuecommand("Tick") end,
			TickCommand = function(self)
				local secs = GetTimeSinceStart()
				local h = math.floor(secs / 3600)
				local m = math.floor((secs % 3600) / 60)
				local s = math.floor(secs % 60)
				self:settextf("Wasted Human Cycles: %02d:%02d:%02d", h, m, s)
				self:sleep(1):queuecommand("Tick")
			end
		},

		-- Real Time Clock
		LoadFont("Common Normal") .. {
			Name = "Clock",
			InitCommand = function(self)
				self:halign(1):y(-6):zoom(0.5):diffuse(mainText)
			end,
			OnCommand = function(self) self:queuecommand("Tick") end,
			TickCommand = function(self)
				self:settext(os.date("%H:%M:%S"))
				self:sleep(1):queuecommand("Tick")
			end
		}
	}
}

-- Create Tab Buttons on Footer
for i, tabName in ipairs(tabs) do
	main_af[#main_af + 1] = Def.ActorFrame {
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
-- MASTER INPUT SINK & TAB MANAGEMENT
-- ============================================================
-- (Relocated to bottom to ensure decoration callbacks are prioritized)

-- Load the Chart Preview layer (initially hidden)
main_af[#main_af + 1] = LoadActor("../ScreenChartPreview overlay/default.lua") .. {
	InitCommand = function(self)
		self:visible(false)
	end
}

-- Load Isolated Input Debugger (Always on top with draworder 9999)
main_af[#main_af + 1] = LoadActor("input_debugger.lua")

-- Sync previewActive state from outside
main_af[#main_af + 1] = Def.Actor {
	ChartPreviewOnMessageCommand = function(self) previewActive = true end,
	ChartPreviewOffMessageCommand = function(self) previewActive = false end,
}

-- Load Decoration Overlays (Initially hidden, using standard Toggle[NAME]Overlay messages)
local decorOverlays = {"search", "scores", "filters", "playlists", "tags", "goals"}
for _, name in ipairs(decorOverlays) do
	main_af[#main_af + 1] = LoadActor("../ScreenSelectMusic decorations/" .. name .. ".lua")
end

main_af[#main_af + 1] = LoadActor("../_cursor")


-- ============================================================
-- MASTER INPUT SINK & TAB MANAGEMENT (LOWER PRIORITY)
-- ============================================================
-- Relocated to ensures decoration input callbacks (search, playlists, etc.) 
-- can capture input FIRST before the global sink takes over.
main_af[#main_af + 1] = Def.ActorFrame {
	Name = "MasterInputSink",
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		
		screen:AddInputCallback(function(event)
			if not event or not event.DeviceInput then return end
			local btn = event.DeviceInput.button

			-- 1. TRACK GLOBAL TAB STATE
			local activeTab = HV.ActiveTab or ""
			
			-- 2. CHART PREVIEW TRIGGER (Space key)
			if btn == "DeviceButton_space" and activeTab == "" then
				if event.type ~= "InputEventType_FirstPress" then return end
				if previewActive then
					previewActive = false
					MESSAGEMAN:Broadcast("ChartPreviewOff")
				else
					previewActive = true
					MESSAGEMAN:Broadcast("ChartPreviewOn")
				end
				return true
			end
			
			-- 3. HANDLE OVERLAY INPUT SINKING
			-- If any tab is active, we generally want to sink all non-mouse input 
			-- from the engine/music wheel. Individual scripts will handle their own keys.
			if activeTab ~= "" then
				-- Let mouse clicks pass through for IsMouseOver checks in scripts
				if btn and btn:match("mouse") then return false end
				
				-- Sink everything else
				return true
			end
			
			-- 3. HANDLE CHART PREVIEW INPUT
			if previewActive then
				-- SINK ALL INPUT while preview is active except mouse
				if btn and btn:match("mouse") then return false end
				
				if event.type ~= "InputEventType_FirstPress" then return true end
				
				-- Let rate preview shortcuts pass through
				if event.button == "EffectUp" or event.button == "EffectDown" then return false end
				
				if event.button == "Back" or event.button == "Start" or btn == "DeviceButton_escape" then
					previewActive = false
					MESSAGEMAN:Broadcast("ChartPreviewOff")
				end
				return true
			end
		end)
	end
}

return main_af

