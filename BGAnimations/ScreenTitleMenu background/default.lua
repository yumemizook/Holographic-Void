--- Holographic Void: ScreenTitleMenu Background
-- Futuristic OLED black dashboard with animated grid and accent elements.
-- Includes: Time display, Online status, Detailed Media Player with random song logic.

local t = Def.ActorFrame {}

local accentColor = color("#5ABAFF")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")

-- Centralized State (global via HV namespace for overlay access)
HV.TitleState = {
	login = {
		visible = false,
		focused = "email", -- "email" or "password"
		email = "",
		password = "",
		status = "Tab / Enter to switch fields"
	},
	player = {
		song = nil,
		paused = true,
		offset = 0,
		lastStart = 0,
	},
	mouse = {
		lastHovered = nil,
		prevLMB = false
	}
}

local function GetOnlineStatus()
	local connected = DLMAN:IsLoggedIn()
	if connected then
		return true, "EtternaOnline", "Online"
	else
		return false, "", "Offline"
	end
end

-- Full-screen OLED black
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1"))
	end
}

-- Subtle horizontal grid lines
for i = 1, 8 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i)
				:zoomto(SCREEN_WIDTH, 1)
				:diffuse(color("1,1,1,0.03"))
		end
	}
end

-- Subtle vertical grid lines
for i = 1, 15 do
	t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy((SCREEN_WIDTH / 16) * i, SCREEN_CENTER_Y)
				:zoomto(1, SCREEN_HEIGHT)
				:diffuse(color("1,1,1,0.03"))
		end
	}
end

-- Animated accent line at top
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_TOP + 2):zoomto(0, 2)
	end,
	OnCommand = function(self)
		self:diffuse(accentColor):diffusealpha(0.6)
			:sleep(0.2):linear(0.8):zoomto(SCREEN_WIDTH * 0.6, 2)
	end
}

-- Header: "HOLOGRAPHIC VOID" title
t[#t + 1] = LoadFont("Common Large") .. {
	Text = "HOLOGRAPHIC VOID",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_TOP + 50):zoom(0.75)
	end,
	OnCommand = function(self)
		self:diffuse(brightText):diffusealpha(0)
			:sleep(0.3):linear(0.5):diffusealpha(1)
	end
}

-- Thin separator under title
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_TOP + 72):zoomto(200, 1)
	end,
	OnCommand = function(self)
		self:diffuse(color("1,1,1,0.15"))
			:diffusealpha(0):sleep(0.5):linear(0.3):diffusealpha(0.15)
	end
}

-- ============================================================
-- TIME DISPLAY (top-left corner)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "TimeDisplayFrame",
	InitCommand = function(self)
		self:SetUpdateFunction(function(af)
			af:GetChild("DateDisplay"):settextf("%04d-%02d-%02d",
				Year(), MonthOfYear()+1, DayOfMonth())
			af:GetChild("TimeDisplay"):settextf("%02d:%02d:%02d",
				Hour(), Minute(), Second())
		end)
	end,
	OnCommand = function(self)
		self:diffusealpha(0):sleep(0.6):linear(0.4):diffusealpha(1)
	end,

	LoadFont("Common Normal") .. {
		Name = "DateDisplay",
		InitCommand = function(self)
			self:xy(SCREEN_LEFT + 16, SCREEN_TOP + 14)
				:halign(0):valign(0):zoom(0.5):diffuse(subText)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "TimeDisplay",
		InitCommand = function(self)
			self:xy(SCREEN_LEFT + 16, SCREEN_TOP + 30)
				:halign(0):valign(0):zoom(0.35):diffuse(subText)
		end
	}
}

-- ============================================================
-- PROFILE DISPLAY (top-right corner)
-- ============================================================
local profileBtnX = SCREEN_RIGHT - 16   -- right edge of button (halign 1)
local profileBtnY = SCREEN_TOP + 42     -- center Y of button
local profileBtnW = 110
local profileBtnH = 22

t[#t + 1] = Def.ActorFrame {
	Name = "OnlineStatus",
	InitCommand = function(self)
		self:xy(SCREEN_RIGHT - 16, SCREEN_TOP + 14)
		self:SetUpdateFunction(function(af)
			local connected = DLMAN:IsLoggedIn()
			local btnBg   = af:GetChild("ProfileBtnBg")
			local btnText = af:GetChild("ProfileBtnText")
			if connected then
				local user = DLMAN:GetUsername()
				btnText:settext(user ~= "" and ("PROFILE · " .. user) or "PROFILE")
				btnBg:diffuse(color("0.1,0.28,0.15,1"))
				btnText:diffuse(color("0.65,1,0.72,1"))
			else
				btnText:settext("PROFILE · OFFLINE")
				btnBg:diffuse(color("0.12,0.12,0.12,1"))
				btnText:diffuse(dimText)
			end
		end)
	end,
	OnCommand = function(self)
		self:diffusealpha(0):sleep(0.6):linear(0.4):diffusealpha(1)
	end,

	-- Profile chip background (right-aligned)
	Def.Quad {
		Name = "ProfileBtnBg",
		InitCommand = function(self)
			-- right edge at x=0 (parent is at SCREEN_RIGHT-16), center at (-55, 28)
			self:xy(-profileBtnW / 2, 28):zoomto(profileBtnW, profileBtnH)
				:diffuse(color("0.12,0.12,0.12,1"))
		end
	},
	LoadFont("Common Normal") .. {
		Name = "ProfileBtnText",
		InitCommand = function(self)
			self:xy(-profileBtnW / 2, 28):zoom(0.35)
				:diffuse(dimText):settext("PROFILE · OFFLINE")
		end
	}
}



-- ============================================================
-- MUSIC PLAYER WIDGET (bottom-left corner)
-- ============================================================
local musicPlayerX = SCREEN_LEFT + 16
local musicPlayerY = SCREEN_BOTTOM - 30

t[#t + 1] = Def.ActorFrame {
	Name = "MusicPlayer",
	InitCommand = function(self)
		self:xy(musicPlayerX, musicPlayerY)
	end,
	OnCommand = function(self)
		self:diffusealpha(0):sleep(0.8):linear(0.4):diffusealpha(1)
	end,

	-- Background panel for player
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(1):zoomto(320, 70)
				:diffuse(color("0,0,0,0.6")):diffusealpha(0.8)
		end
	},

	-- Song Info (above buttons)
	Def.ActorFrame {
		Name = "SongInfo",
		InitCommand = function(self)
			self:x(20):y(-45)
		end,

		-- Song title
		LoadFont("Common Normal") .. {
			Name = "NowPlayingTitle",
			InitCommand = function(self)
				self:halign(0):valign(1):zoom(0.35):diffuse(brightText)
					:maxwidth(280 / 0.35)
			end,
			SetCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if song then
					self:settext(song:GetDisplayMainTitle())
				else
					self:settext("No song selected")
				end
			end,
			OnCommand = function(self) self:playcommand("Set") end,
			CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end
		},

		-- Artist
		LoadFont("Common Normal") .. {
			Name = "NowPlayingArtist",
			InitCommand = function(self)
				self:halign(0):valign(1):y(14):zoom(0.28):diffuse(subText)
					:maxwidth(280 / 0.28)
			end,
			SetCommand = function(self)
				local song = GAMESTATE:GetCurrentSong()
				if song then
					self:settext(song:GetDisplayArtist())
				else
					self:settext("")
				end
			end,
			OnCommand = function(self) self:playcommand("Set") end,
			CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end
		}
	},

	-- Buttons Container
	Def.ActorFrame {
		Name = "PlayerControls",
		InitCommand = function(self)
			self:y(-10)
		end,

		-- Prev
		LoadActor("../../Graphics/prev.png") .. {
			Name = "BtnPrev",
			InitCommand = function(self)
				self:x(20):zoom(0.4):diffuse(subText)
			end
		},
		-- Play / Pause icon toggle
		LoadActor("../../Graphics/play.png") .. {
			Name = "BtnPlay",
			InitCommand = function(self)
				self:x(50):zoom(0.4):diffuse(accentColor)
			end,
			SetCommand = function(self)
				-- We could swap textures here if pause.png existed, 
				-- for now just change alpha or color
				self:diffuse(HV.TitleState.player.paused and accentColor or color("0.5,1,0.5,1"))
			end,
			CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
			PlayStatusChangedMessageCommand = function(self) self:playcommand("Set") end
		},
		-- Next
		LoadActor("../../Graphics/next.png") .. {
			Name = "BtnNext",
			InitCommand = function(self)
				self:x(80):zoom(0.4):diffuse(subText)
			end
		},
		-- Stop
		LoadActor("../../Graphics/stop.png") .. {
			Name = "BtnStop",
			InitCommand = function(self)
				self:x(110):zoom(0.4):diffuse(subText)
			end
		}
	}
}

-- Version tag in bottom-right corner
t[#t + 1] = LoadFont("Common Normal") .. {
	Text = "v0.1.0 · Etterna 0.74.4",
	InitCommand = function(self)
		self:xy(SCREEN_RIGHT - 10, SCREEN_BOTTOM - 12)
			:halign(1):valign(1):zoom(0.4)
	end,
	OnCommand = function(self)
		self:diffuse(color("0.35,0.35,0.35,1"))
	end
}

-- Animated corner brackets (top-left)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(SCREEN_LEFT + 20, SCREEN_TOP + 20)
	end,
	OnCommand = function(self)
		self:diffusealpha(0):sleep(0.6):linear(0.4):diffusealpha(0.2)
	end,
	-- Horizontal bracket
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(40, 1):diffuse(accentColor)
		end
	},
	-- Vertical bracket
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0):zoomto(1, 40):diffuse(accentColor)
		end
	}
}

-- Animated corner brackets (bottom-right)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(SCREEN_RIGHT - 20, SCREEN_BOTTOM - 20)
	end,
	OnCommand = function(self)
		self:diffusealpha(0):sleep(0.6):linear(0.4):diffusealpha(0.2)
	end,
	Def.Quad {
		InitCommand = function(self)
			self:halign(1):valign(1):zoomto(40, 1):diffuse(accentColor)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(1):valign(1):zoomto(1, 40):diffuse(accentColor)
		end
	}
}

-- LOGIN OVERLAY has been moved to BGAnimations/ScreenTitleMenu overlay/default.lua
-- so it renders above the engine's scroller/menu items.

local menuChoiceCount = 4
local menuCenterY = SCREEN_CENTER_Y + 40
local menuSpacing = 40
local menuItemW = 300
local menuItemH = 36

local function DeviceBtnToChar(btn, shifted)
	local letter = btn:match("^DeviceButton_([a-z])$")
	if letter then return shifted and letter:upper() or letter end
	local digit = btn:match("^DeviceButton_([0-9])$")
	if digit then
		if shifted then
			local shiftMap = {["1"]="!",["2"]="@",["3"]="#",["4"]="$",["5"]="%",
			                  ["6"]="^",["7"]="&",["8"]="*",["9"]="(",["0"]=")"}
			return shiftMap[digit] or digit
		end
		return digit
	end
	local symMap = {
		["DeviceButton_period"]     = shifted and ">" or ".",
		["DeviceButton_comma"]      = shifted and "<" or ",",
		["DeviceButton_slash"]      = shifted and "?" or "/",
		["DeviceButton_backslash"]  = shifted and "|" or "\\",
		["DeviceButton_minus"]      = shifted and "_" or "-",
		["DeviceButton_equals"]     = shifted and "+" or "=",
		["DeviceButton_semicolon"]  = shifted and ":" or ";",
		["DeviceButton_apostrophe"] = shifted and "\"" or "'",
		["DeviceButton_left bracket"]  = shifted and "{" or "[",
		["DeviceButton_right bracket"] = shifted and "}" or "]",
		["DeviceButton_grave"]      = shifted and "~" or "`",
		["DeviceButton_space"]      = " ",
	}
	return symMap[btn]
end

-- ============================================================
-- REBUILT GLOBAL LOGIC ACTOR
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	OnCommand = function(self)
		self:queuecommand("InitInput")
	end,
	InitInputCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then
			self:sleep(0.05):queuecommand("InitInput")
			return
		end

		-- ── HELPER FUNCTIONS ──────────────────────────────────────────

		local function updateLoginUI()
			MESSAGEMAN:Broadcast("UpdateLoginOverlay")
		end

		local function showLogin()
			HV.TitleState.login.visible = true
			HV.TitleState.login.focused = "email"
			HV.TitleState.login.status = "Tab / Enter to switch fields"
			MESSAGEMAN:Broadcast("ShowLoginOverlay")
			updateLoginUI()
		end

		local function hideLogin()
			HV.TitleState.login.visible = false
			MESSAGEMAN:Broadcast("HideLoginOverlay")
		end

		local function doLogin()
			local l = HV.TitleState.login
			if l.email ~= "" and l.password ~= "" then
				DLMAN:Login(l.email, l.password)
				l.status = "Logging in..."
				updateLoginUI()
				-- We hide after a delay or on success message, but for now:
				self:sleep(1):queuecommand("FinishLogin")
			else
				l.status = "Enter email and password"
				updateLoginUI()
			end
		end

		local function pickAndPlay(offset)
			local p = HV.TitleState.player
			if not p.song then
				p.song = SONGMAN:GetRandomSong()
			end
			if p.song then
				local mp = p.song:GetMusicPath()
				if mp then
					p.offset = offset or 0
					local start = p.song:GetSampleStart() + p.offset
					local len = p.song:GetSampleLength() - p.offset
					if len > 0 then
						SOUND:PlayMusicPart(mp, start, len)
						p.lastStart = GetTimeSinceStart()
						p.paused = false
						GAMESTATE:SetCurrentSong(p.song)
						MESSAGEMAN:Broadcast("PlayStatusChanged")
						MESSAGEMAN:Broadcast("CurrentSongChanged")
					else
						p.song = nil
						pickAndPlay(0)
					end
				end
			end
		end

		local function togglePlay()
			local p = HV.TitleState.player
			if p.paused then
				pickAndPlay(p.offset)
			else
				if p.lastStart > 0 then
					p.offset = p.offset + (GetTimeSinceStart() - p.lastStart)
				end
				SOUND:StopMusic()
				p.paused = true
				MESSAGEMAN:Broadcast("PlayStatusChanged")
			end
		end

		local function seek(delta)
			local p = HV.TitleState.player
			if not p.song then return end
			if not p.paused and p.lastStart > 0 then
				p.offset = p.offset + (GetTimeSinceStart() - p.lastStart)
			end
			p.offset = math.max(0, p.offset + delta)
			pickAndPlay(p.offset)
		end

		-- ── INPUT CALLBACK ──────────────────────────────────────────

		screen:AddInputCallback(function(event)
			local deviceInput = event.DeviceInput or {}
			local btn = deviceInput.button or ""
			local gameBtn = (event.GameInput and event.GameInput.button) or event.button

			-- Login Overlay Keys
			if HV.TitleState.login.visible then
				local l = HV.TitleState.login

				-- Trap ALL non-first-press events while modal is open so no input leaks to title screen.
				if event.type ~= "InputEventType_FirstPress" then
					return true
				end

				-- Ignore modifier-only keys so they cannot disturb modal focus/state.
				if btn == "DeviceButton_left shift" or btn == "DeviceButton_right shift"
					or btn == "DeviceButton_left ctrl" or btn == "DeviceButton_right ctrl"
					or btn == "DeviceButton_left alt" or btn == "DeviceButton_right alt" then
					return true
				end

				-- Process printable text first (including special chars like '@').
				local shifted = INPUTFILTER:IsBeingPressed("DeviceButton_left shift") or
				                INPUTFILTER:IsBeingPressed("DeviceButton_right shift") or
				                (deviceInput.level and deviceInput.level > 1)
				local char = event.char or DeviceBtnToChar(btn, shifted)
				if char and #char == 1 then
					if l.focused == "email" then
						l.email = l.email .. char
					else
						l.password = l.password .. char
					end
					updateLoginUI()
					return true
				end

				-- Some input layouts report Backspace as GameButton Back.
				if gameBtn == "Back" and btn ~= "DeviceButton_escape" then
					if l.focused == "email" then
						l.email = l.email:sub(1, -2)
					else
						l.password = l.password:sub(1, -2)
					end
					updateLoginUI()
					return true
				end

				if btn == "DeviceButton_backspace" then
					if l.focused == "email" then
						l.email = l.email:sub(1, -2)
					else
						l.password = l.password:sub(1, -2)
					end
					updateLoginUI()
				elseif btn == "DeviceButton_tab" then
					l.focused = l.focused == "email" and "password" or "email"
					updateLoginUI()
				elseif btn == "DeviceButton_return" or btn == "DeviceButton_enter" then
					if l.focused == "email" then
						l.focused = "password"
						updateLoginUI()
					else
						doLogin()
					end
				elseif btn == "DeviceButton_escape" then
					hideLogin()
				end
				return true -- Consumes all input while modal is open
			end

			if event.type ~= "InputEventType_FirstPress" then return end

			-- Global Keybinds
			if not HV.TitleState.login.visible then
				if gameBtn == "Select" then
					-- Login modal moved to ScreenSelectMusic.
					return
				elseif btn == "DeviceButton_backslash" then
					togglePlay()
					return
				elseif btn == "DeviceButton_left bracket" then
					seek(-5)
					return
				elseif btn == "DeviceButton_right bracket" then
					seek(5)
					return
				end
			end

			-- Mouse Scroll
			local scroll = GetMouseScrollDirection(btn)
			if scroll ~= 0 then
				local scroller = screen:GetChild("Scroller")
				if scroller then
					local dest = scroller:GetDestinationItem() + scroll
					dest = math.max(0, math.min(menuChoiceCount - 1, dest))
					scroller:SetDestinationItem(dest)
					HV.TitleState.mouse.lastHovered = dest + 1
				end
			end
		end)

		-- ── MOUSE POLLING ───────────────────────────────────────────

		self:SetUpdateFunction(function()
			local mx = INPUTFILTER:GetMouseX()
			local my = INPUTFILTER:GetMouseY()
			local lmb = INPUTFILTER:IsBeingPressed("DeviceButton_left mouse button")
			local clicked = lmb and not HV.TitleState.mouse.prevLMB
			HV.TitleState.mouse.prevLMB = lmb

			if HV.TitleState.login.visible then
				if clicked then
					local cx, cy = SCREEN_CENTER_X, SCREEN_CENTER_Y
					if IsMouseOverCentered(cx, cy - 50, 280, 28) then
						HV.TitleState.login.focused = "email"
						updateLoginUI()
					elseif IsMouseOverCentered(cx, cy - 5, 280, 28) then
						HV.TitleState.login.focused = "password"
						updateLoginUI()
					elseif IsMouseOverCentered(cx - 70, cy + 55, 120, 36) then
						doLogin()
					elseif IsMouseOverCentered(cx + 70, cy + 55, 120, 36) then
						hideLogin()
					end
				end
				return
			end

			-- Normal Hover
			local hovered = nil
			for i = 1, menuChoiceCount do
				local iy = menuCenterY + menuSpacing * ((i - 1) - (menuChoiceCount - 1) / 2)
				if mx >= SCREEN_CENTER_X - menuItemW/2 and mx <= SCREEN_CENTER_X + menuItemW/2 
				   and my >= iy - menuItemH/2 and my <= iy + menuItemH/2 then
					hovered = i
					break
				end
			end

			if hovered ~= HV.TitleState.mouse.lastHovered then
				HV.TitleState.mouse.lastHovered = hovered
				if hovered then
					local scroller = screen:GetChild("Scroller")
					if scroller then scroller:SetDestinationItem(hovered - 1) end
				end
			end

			if clicked then
				-- Profile Button
				local pBtnX = (SCREEN_RIGHT - 16) - profileBtnW / 2
				local pBtnY = (SCREEN_TOP + 14) + 28
				if IsMouseOverCentered(pBtnX, pBtnY, profileBtnW, profileBtnH) then
					-- Login modal moved to ScreenSelectMusic.
					return
				end

				-- Menu Click
				if hovered then
					screen:Input({
						DeviceInput = {button = "DeviceButton_enter", type = "InputEventType_FirstPress"},
						GameInput = {button = "Start", type = "InputEventType_FirstPress"}
					})
					return
				end

				-- Player Controls
				local btnAbsY = musicPlayerY - 10
				if my >= btnAbsY - 15 and my <= btnAbsY + 15 then
					local bx = mx - musicPlayerX
					if bx >= 7 and bx <= 33 then -- Prev
						HV.TitleState.player.song = nil
						pickAndPlay(0)
					elseif bx >= 37 and bx <= 63 then -- Play
						togglePlay()
					elseif bx >= 67 and bx <= 93 then -- Next
						HV.TitleState.player.song = nil
						pickAndPlay(0)
					elseif bx >= 97 and bx <= 123 then -- Stop
						SOUND:StopMusic()
						HV.TitleState.player.paused = true
						HV.TitleState.player.offset = 0
						MESSAGEMAN:Broadcast("PlayStatusChanged")
					end
				end
			end
		end)
	end,
	FinishLoginCommand = function(self)
		HV.TitleState.login.visible = false
		MESSAGEMAN:Broadcast("HideLoginOverlay")
	end
}


return t
