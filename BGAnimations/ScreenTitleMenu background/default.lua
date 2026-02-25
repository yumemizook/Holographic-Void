--- Holographic Void: ScreenTitleMenu Background
-- Futuristic OLED black dashboard with animated grid and accent elements.
-- Includes: Time display, Online status, Detailed Media Player with random song logic.

local t = Def.ActorFrame {}

local accentColor = color("#5ABAFF")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")

-- Login overlay state (managed by MouseHandler)
local loginVisible = false
local loginFocused = "email"  -- "email" or "password"
local loginEmailText = ""
local loginPasswordText = ""  -- actual password chars

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
-- PROFILE WIDGET (top-right corner)
-- Status text + Login button (offline) or username (online)
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
			local connected, server, status = GetOnlineStatus()
			-- Status line
			local statusText = af:GetChild("StatusText")
			if connected then
				statusText:settextf("%s  %s", server, status)
				statusText:diffuse(subText)
			else
				statusText:settext(status)
				statusText:diffuse(dimText)
			end
			-- Button label + colour
			local btnBg   = af:GetChild("ProfileBtnBg")
			local btnText = af:GetChild("ProfileBtnText")
			if connected then
				local user = DLMAN:GetUsername()
				btnText:settext(user ~= "" and user or "Profile")
				btnBg:diffuse(color("0.1,0.3,0.1,1"))
				btnText:diffuse(color("0.5,1,0.5,1"))
			else
				btnText:settext("Login")
				btnBg:diffuse(accentColor)
				btnText:diffuse(color("0,0,0,1"))
			end
		end)
	end,
	OnCommand = function(self)
		self:diffusealpha(0):sleep(0.6):linear(0.4):diffusealpha(1)
	end,

	-- Status line (right-aligned, top)
	LoadFont("Common Normal") .. {
		Name = "StatusText",
		InitCommand = function(self)
			self:halign(1):valign(0):zoom(0.35):diffuse(subText)
		end
	},

	-- Profile / Login button background (right-aligned)
	Def.Quad {
		Name = "ProfileBtnBg",
		InitCommand = function(self)
			-- right edge at x=0 (parent is at SCREEN_RIGHT-16), center at (-55, 28)
			self:xy(-profileBtnW / 2, 28):zoomto(profileBtnW, profileBtnH)
				:diffuse(accentColor)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "ProfileBtnText",
		InitCommand = function(self)
			self:xy(-profileBtnW / 2, 28):zoom(0.35)
				:diffuse(color("0,0,0,1")):settext("Login")
		end
	}
}

-- ============================================================
-- LOGIN OVERLAY
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "LoginOverlay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
		self:diffusealpha(0)
	end,
	ShowLoginOverlayMessageCommand = function(self)
		self:diffusealpha(0):linear(0.3):diffusealpha(1)
	end,
	HideLoginOverlayMessageCommand = function(self)
		self:linear(0.3):diffusealpha(0)
	end,

	-- Background panel
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(400, 250):diffuse(color("0,0,0,0.92"))
		end
	},

	-- Border
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(402, 252):diffuse(accentColor):diffusealpha(0.8)
		end
	},

	-- Title
	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:xy(0, -100):zoom(0.6):diffuse(brightText)
				:settext("Login to EtternaOnline")
		end
	},

	-- Email label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-150, -50):halign(0):zoom(0.4):diffuse(subText)
				:settext("Email:")
		end
	},
	-- Email input box
	Def.Quad {
		Name = "EmailField",
		InitCommand = function(self)
			self:xy(0, -50):zoomto(280, 28)
				:diffuse(color("0.15,0.15,0.15,1"))
		end,
		FocusEmailMessageCommand = function(self)
			self:diffuse(color("0.2,0.2,0.35,1"))
		end,
		FocusPasswordMessageCommand = function(self)
			self:diffuse(color("0.15,0.15,0.15,1"))
		end
	},
	LoadFont("Common Normal") .. {
		Name = "EmailText",
		InitCommand = function(self)
			self:xy(-138, -50):halign(0):zoom(0.35):diffuse(brightText)
		end,
		FocusEmailMessageCommand = function(self)
			self:diffuse(color("1,1,0.6,1"))
		end,
		FocusPasswordMessageCommand = function(self)
			self:diffuse(brightText)
		end
	},

	-- Password label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-150, -5):halign(0):zoom(0.4):diffuse(subText)
				:settext("Password:")
		end
	},
	-- Password input box
	Def.Quad {
		Name = "PasswordField",
		InitCommand = function(self)
			self:xy(0, -5):zoomto(280, 28)
				:diffuse(color("0.15,0.15,0.15,1"))
		end,
		FocusPasswordMessageCommand = function(self)
			self:diffuse(color("0.2,0.2,0.35,1"))
		end,
		FocusEmailMessageCommand = function(self)
			self:diffuse(color("0.15,0.15,0.15,1"))
		end
	},
	LoadFont("Common Normal") .. {
		Name = "PasswordText",
		InitCommand = function(self)
			self:xy(-138, -5):halign(0):zoom(0.35):diffuse(brightText)
		end,
		FocusPasswordMessageCommand = function(self)
			self:diffuse(color("1,1,0.6,1"))
		end,
		FocusEmailMessageCommand = function(self)
			self:diffuse(brightText)
		end
	},

	-- Login button
	Def.Quad {
		Name = "LoginBtn",
		InitCommand = function(self)
			self:xy(-70, 55):zoomto(120, 36):diffuse(accentColor)
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(-70, 55):zoom(0.4):diffuse(color("0,0,0,1")):settext("Login")
		end
	},

	-- Cancel button
	Def.Quad {
		Name = "CancelBtn",
		InitCommand = function(self)
			self:xy(70, 55):zoomto(120, 36):diffuse(color("0.35,0.35,0.35,1"))
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(70, 55):zoom(0.4):diffuse(brightText):settext("Cancel")
		end
	},

	-- Status message line
	LoadFont("Common Normal") .. {
		Name = "LoginStatus",
		InitCommand = function(self)
			self:xy(0, 90):zoom(0.35):diffuse(subText):settext("")
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
		-- Play
		LoadActor("../../Graphics/play.png") .. {
			Name = "BtnPlay",
			InitCommand = function(self)
				self:x(50):zoom(0.4):diffuse(accentColor)
			end
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

-- ============================================================
-- MOUSE SUPPORT
-- ============================================================
local menuChoiceCount = 4 -- GameStart, PackDownloader, Options, Exit
local menuCenterY = SCREEN_CENTER_Y + 40
local menuSpacing = 40
local menuItemW = 300
local menuItemH = 36
local lastMousedItem = nil

-- Map DeviceButton_ names to printable characters for text input
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
		["DeviceButton_period"]    = shifted and ">" or ".",
		["DeviceButton_minus"]     = shifted and "_" or "-",
		["DeviceButton_underscore"]= "_",
		["DeviceButton_equals"]    = shifted and "+" or "=",
		["DeviceButton_space"]     = " ",
	}
	return symMap[btn]
end

t[#t + 1] = Def.ActorFrame {
	Name = "MouseHandler",
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		local prevLMB    = false   -- left mouse button state last frame
		local prevScroll = 0       -- scroll wheel not edge-triggered, track separately

		local function updateOverlayText()
			local scr = SCREENMAN:GetTopScreen()
			if not scr then return end
			local ov = scr:GetChild("LoginOverlay")
			if not ov then return end
			ov:GetChild("EmailText"):settext(loginEmailText)
			ov:GetChild("PasswordText"):settext(string.rep("*", #loginPasswordText))
			MESSAGEMAN:Broadcast(loginFocused == "email" and "FocusEmail" or "FocusPassword")
		end

		local function showOverlay()
			local scr = SCREENMAN:GetTopScreen()
			if not scr then return end
			loginVisible      = true
			loginFocused      = "email"
			loginEmailText    = ""
			loginPasswordText = ""
			local ov = scr:GetChild("LoginOverlay")
			if ov then
				ov:GetChild("EmailText"):settext("")
				ov:GetChild("PasswordText"):settext("")
				ov:GetChild("LoginStatus"):settext("Tab / Enter to switch fields")
				MESSAGEMAN:Broadcast("ShowLoginOverlay")
				MESSAGEMAN:Broadcast("FocusEmail")
			end
		end

		local function hideOverlay()
			loginVisible = false
			MESSAGEMAN:Broadcast("HideLoginOverlay")
		end

		local function doLogin()
			local scr = SCREENMAN:GetTopScreen()
			if loginEmailText ~= "" and loginPasswordText ~= "" then
				DLMAN:Login(loginEmailText, loginPasswordText)
				if scr then
					local ov = scr:GetChild("LoginOverlay")
					if ov then ov:GetChild("LoginStatus"):settext("Logging in...") end
				end
				hideOverlay()
			else
				if scr then
					local ov = scr:GetChild("LoginOverlay")
					if ov then ov:GetChild("LoginStatus"):settext("Enter email and password") end
				end
			end
		end

		local function pickAndPlay()
			local song = SONGMAN:GetRandomSong()
			if song then
				GAMESTATE:SetCurrentSong(song)
				local mp = song:GetMusicPath()
				if mp then
					SOUND:PlayMusicPart(mp, song:GetSampleStart(), song:GetSampleLength())
				end
			end
		end

		-- All click and hover logic polled every frame
		self:SetUpdateFunction(function()
			local mx  = INPUTFILTER:GetMouseX()
			local my  = INPUTFILTER:GetMouseY()
			local lmb = INPUTFILTER:IsBeingPressed("DeviceButton_left mouse button")

			-- Edge-detect: only fire on the frame the button transitions down
			local clicked = lmb and not prevLMB
			prevLMB = lmb

			-- ── LOGIN OVERLAY ────────────────────────────────────────────
			if loginVisible then
				if clicked then
					local cx, cy = SCREEN_CENTER_X, SCREEN_CENTER_Y
					if IsMouseOverCentered(cx, cy - 50, 280, 28) then
						loginFocused = "email"
						MESSAGEMAN:Broadcast("FocusEmail")
					elseif IsMouseOverCentered(cx, cy - 5, 280, 28) then
						loginFocused = "password"
						MESSAGEMAN:Broadcast("FocusPassword")
					elseif IsMouseOverCentered(cx - 70, cy + 55, 120, 36) then
						doLogin()
					elseif IsMouseOverCentered(cx + 70, cy + 55, 120, 36) then
						hideOverlay()
					end
				end
				return  -- skip normal hover/click while overlay open
			end

			-- ── NORMAL ───────────────────────────────────────────────────
			local scr = SCREENMAN:GetTopScreen()

			-- Menu hover
			local hoveredItem = nil
			for i = 1, menuChoiceCount do
				local iy = menuCenterY + menuSpacing * ((i - 1) - (menuChoiceCount - 1) / 2)
				if mx >= SCREEN_CENTER_X - menuItemW / 2 and mx <= SCREEN_CENTER_X + menuItemW / 2
					and my >= iy - menuItemH / 2 and my <= iy + menuItemH / 2 then
					hoveredItem = i
					break
				end
			end
			if hoveredItem and hoveredItem ~= lastMousedItem then
				lastMousedItem = hoveredItem
				if scr then
					local scrollerFrame = scr:GetChild("ScrollerFrame")
					if scrollerFrame then
						local scroller = scrollerFrame:GetChild("Scroller")
						if scroller then scroller:SetDestinationItem(hoveredItem - 1) end
					end
				end
			end
			if not hoveredItem then lastMousedItem = nil end

			if not clicked then return end

			-- Profile / Login button
			-- Parent actor sits at (SCREEN_RIGHT-16, SCREEN_TOP+14)
			-- Button quad is at local xy(-profileBtnW/2, 28) -> screen center:
			local btnCX = (SCREEN_RIGHT - 16) - profileBtnW / 2
			local btnCY = (SCREEN_TOP + 14) + 28
			if IsMouseOverCentered(btnCX, btnCY, profileBtnW, profileBtnH) then
				if not GetOnlineStatus() then
					showOverlay()
				end
				return
			end

			-- Main menu click
			if lastMousedItem then
				MESSAGEMAN:Broadcast("MenuStart")
				return
			end

			-- Music player buttons
			-- Player frame at (musicPlayerX, musicPlayerY); controls sub-frame y(-10)
			-- Button icon centers at local x = 20/50/80/110, zoom 0.4 (~13px hit radius)
			local btnAbsY = musicPlayerY - 10
			if my >= btnAbsY - 13 and my <= btnAbsY + 13 then
				local bx = mx - musicPlayerX
				if     bx >= 7  and bx <= 33  then  -- Prev  (x=20)
					-- no-op
				elseif bx >= 37 and bx <= 63  then  -- Play  (x=50)
					pickAndPlay()
				elseif bx >= 67 and bx <= 93  then  -- Next  (x=80)
					pickAndPlay()
				elseif bx >= 97 and bx <= 123 then  -- Stop  (x=110)
					SOUND:StopMusic()
				end
			end
		end)

		-- AddInputCallback kept ONLY for keyboard text entry in login overlay
		screen:AddInputCallback(function(event)
			if not loginVisible then return end
			if event.type ~= "InputEventType_FirstPress" then return end
			local btn = event.DeviceInput.button

			-- Ignore mouse buttons (handled by polling above)
			if btn:find("mouse") then return end

			local scr = SCREENMAN:GetTopScreen()

			if btn == "DeviceButton_backspace" then
				if loginFocused == "email" then
					loginEmailText = loginEmailText:sub(1, -2)
				else
					loginPasswordText = loginPasswordText:sub(1, -2)
				end
				updateOverlayText()
			elseif btn == "DeviceButton_tab" then
				loginFocused = loginFocused == "email" and "password" or "email"
				MESSAGEMAN:Broadcast(loginFocused == "email" and "FocusEmail" or "FocusPassword")
			elseif btn == "DeviceButton_return" or btn == "DeviceButton_enter" then
				if loginFocused == "email" then
					loginFocused = "password"
					MESSAGEMAN:Broadcast("FocusPassword")
				else
					doLogin()
				end
			else
				local shifted = INPUTFILTER:IsBeingPressed("DeviceButton_left shift")
				             or INPUTFILTER:IsBeingPressed("DeviceButton_right shift")
				local ch = DeviceBtnToChar(btn, shifted)
				if ch then
					if loginFocused == "email" then
						loginEmailText = loginEmailText .. ch
					else
						loginPasswordText = loginPasswordText .. ch
					end
					updateOverlayText()
				end
			end
		end)

		-- Scroll wheel still via AddInputCallback (not consumed by title menu)
		screen:AddInputCallback(function(event)
			if loginVisible then return end
			if event.type == "InputEventType_Release" then return end
			local scroll = GetMouseScrollDirection(event.DeviceInput.button)
			if scroll == 0 then return end
			local scr = SCREENMAN:GetTopScreen()
			if not scr then return end
			local scrollerFrame = scr:GetChild("ScrollerFrame")
			if scrollerFrame then
				local scroller = scrollerFrame:GetChild("Scroller")
				if scroller then
					local dest = scroller:GetDestinationItem() + scroll
					dest = math.max(0, math.min(menuChoiceCount - 1, dest))
					scroller:SetDestinationItem(dest)
					lastMousedItem = dest + 1
				end
			end
		end)
	end
}

return t
