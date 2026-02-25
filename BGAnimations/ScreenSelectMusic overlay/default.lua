--- Holographic Void: ScreenSelectMusic Overlay
-- Keep cursor in overlay layer so it renders above decorations.

local t = Def.ActorFrame {}

-- Define shared state
HV = HV or {}
HV.LoginState = HV.LoginState or {
	visible = false,
	focused = "email",
	email = "",
	password = "",
	status = "Tab / Enter to switch fields"
}
local loginState = HV.LoginState

local accentColor = color("#5ABAFF")
local subText = color("0.65,0.65,0.65,1")
local brightText = color("1,1,1,1")

local panelX = 8                      -- Left panel left edge
local panelW = SCREEN_WIDTH * 0.36   -- Panel width
local loginBtnW = 180
local loginBtnH = 28
local loginBtnCX = panelX + panelW / 2
local loginBtnCY = SCREEN_BOTTOM - 24

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
-- LOGIN OVERLAY (Modal)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "LoginOverlay",
	InitCommand = function(self)
		self:Center():diffusealpha(0):visible(false)
	end,
	ShowLoginOverlayMessageCommand = function(self)
		self:stoptweening():visible(true):diffusealpha(0):linear(0.2):diffusealpha(1)
	end,
	HideLoginOverlayMessageCommand = function(self)
		self:stoptweening():linear(0.2):diffusealpha(0):sleep(0):queuecommand("HideFinish")
	end,
	HideFinishCommand = function(self)
		self:visible(false)
	end,

	Def.Quad {
		InitCommand = function(self)
			self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,0.6"))
		end
	},
	Def.ActorFrame {
		Name = "Panel",
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(402, 252):diffuse(accentColor):diffusealpha(0.6)
			end
		},
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(400, 250):diffuse(color("0,0,0,0.95"))
			end
		},

		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(0, -100):zoom(0.6):diffuse(brightText):settext("Login to EtternaOnline")
			end
		},

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-150, -50):halign(0):zoom(0.4):diffuse(subText):settext("Email:")
			end
		},
		Def.Quad {
			Name = "EmailField",
			InitCommand = function(self)
				self:xy(0, -50):zoomto(280, 28):diffuse(color("0.15,0.15,0.15,1"))
			end,
			FocusEmailMessageCommand = function(self) self:diffuse(color("0.2,0.2,0.3,1")) end,
			FocusPasswordMessageCommand = function(self) self:diffuse(color("0.1,0.1,0.1,1")) end
		},
		LoadFont("Common Normal") .. {
			Name = "EmailText",
			InitCommand = function(self)
				self:xy(-138, -50):halign(0):zoom(0.35):diffuse(brightText)
			end,
			FocusEmailMessageCommand = function(self) self:diffuse(color("1,1,0.6,1")) end,
			FocusPasswordMessageCommand = function(self) self:diffuse(brightText) end
		},

		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-150, -5):halign(0):zoom(0.4):diffuse(subText):settext("Password:")
			end
		},
		Def.Quad {
			Name = "PasswordField",
			InitCommand = function(self)
				self:xy(0, -5):zoomto(280, 28):diffuse(color("0.15,0.15,0.15,1"))
			end,
			FocusPasswordMessageCommand = function(self) self:diffuse(color("0.2,0.2,0.3,1")) end,
			FocusEmailMessageCommand = function(self) self:diffuse(color("0.1,0.1,0.1,1")) end
		},
		LoadFont("Common Normal") .. {
			Name = "PasswordText",
			InitCommand = function(self)
				self:xy(-138, -5):halign(0):zoom(0.35):diffuse(brightText)
			end,
			FocusPasswordMessageCommand = function(self) self:diffuse(color("1,1,0.6,1")) end,
			FocusEmailMessageCommand = function(self) self:diffuse(brightText) end
		},

		Def.Quad {
			InitCommand = function(self)
				self:xy(-70, 55):zoomto(120, 36):diffuse(accentColor)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-70, 55):zoom(0.4):diffuse(color("0,0,0,1")):settext("Login")
			end
		},
		Def.Quad {
			InitCommand = function(self)
				self:xy(70, 55):zoomto(120, 36):diffuse(color("0.35,0.35,0.35,1"))
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(70, 55):zoom(0.4):diffuse(brightText):settext("Cancel")
			end
		},

		LoadFont("Common Normal") .. {
			Name = "LoginStatus",
			InitCommand = function(self)
				self:xy(0, 90):zoom(0.35):diffuse(subText)
			end,
			UpdateLoginOverlayMessageCommand = function(self)
				self:settext(loginState.status)
			end
		}
	},
	Def.Actor {
		UpdateLoginOverlayMessageCommand = function(self)
			local root = self:GetParent()
			if not root then return end
			local panel = root:GetChild("Panel")
			if not panel then return end
			local emailText = panel:GetChild("EmailText")
			local passwordText = panel:GetChild("PasswordText")
			if emailText then emailText:settext(loginState.email) end
			if passwordText then passwordText:settext(string.rep("*", #loginState.password)) end
			MESSAGEMAN:Broadcast(loginState.focused == "email" and "FocusEmail" or "FocusPassword")
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

		local prevLMB = false
		local dbg = self:GetParent():GetChild("ClickDebug")
		if dbg then dbg:settext("ClickDebug active") end

		local function updateLoginUI()
			MESSAGEMAN:Broadcast("UpdateLoginOverlay")
		end

		local function showLogin()
			loginState.visible = true
			loginState.focused = "email"
			loginState.status = "Tab / Enter to switch fields"
			MESSAGEMAN:Broadcast("ShowLoginOverlay")
			updateLoginUI()
		end

		local function hideLogin()
			loginState.visible = false
			MESSAGEMAN:Broadcast("HideLoginOverlay")
			prevLMB = false -- reset click edge so next click triggers
			if dbg then
				dbg:settext("Login hidden")
				dbg:stoptweening():diffusealpha(1):sleep(1.5):linear(0.3):diffusealpha(0.15)
			end
		end

		local function doLogin()
			if loginState.email ~= "" and loginState.password ~= "" then
				DLMAN:Login(loginState.email, loginState.password)
				loginState.status = "Logging in..."
				updateLoginUI()
			else
				loginState.status = "Enter email and password"
				updateLoginUI()
			end
		end

		-- Per-frame hover tracking and click polling
		self:SetUpdateFunction(function()
			local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
			local lmb = INPUTFILTER:IsBeingPressed("DeviceButton_left mouse button")
			local clicked = lmb and not prevLMB
			prevLMB = lmb

			if loginState.visible then
				if clicked then
					local cx, cy = SCREEN_CENTER_X, SCREEN_CENTER_Y
					if IsMouseOverCentered(cx, cy - 50, 280, 28) then
						loginState.focused = "email"
						updateLoginUI()
					elseif IsMouseOverCentered(cx, cy - 5, 280, 28) then
						loginState.focused = "password"
						updateLoginUI()
					elseif IsMouseOverCentered(cx - 70, cy + 55, 120, 36) then
						doLogin()
					elseif IsMouseOverCentered(cx + 70, cy + 55, 120, 36) then
						hideLogin()
					else
						-- Clicked outside modal completely: dismiss
						hideLogin()
					end
				end
				return true
			end

			if clicked then
				if IsMouseOverCentered(loginBtnCX, loginBtnCY, loginBtnW, loginBtnH) then
					showLogin()
					if dbg then
						dbg:settext(string.format("Click: LOGIN button hit (%.0f,%.0f)", mx, my))
						dbg:stoptweening():diffusealpha(1):sleep(2):linear(0.3):diffusealpha(0.15)
					end
					return
				end
			end
			
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

			if clicked then
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
							-- CRITICAL: Ensure wheel is stopped with Move(0) before Select()
							mw:Move(0)
							mw:Select()
						end
					end
					if dbg then
						dbg:settext(string.format("Click: wheel hovered=%s mx=%.0f my=%.0f", tostring(lastHoveredWheelItem), mx, my))
						dbg:stoptweening():diffusealpha(1):sleep(2):linear(0.3):diffusealpha(0.15)
					end
				end
			end

			if clicked then
				if dbg then
					dbg:settext(string.format("Click: no hit mx=%.0f my=%.0f", mx, my))
					dbg:stoptweening():diffusealpha(1):sleep(2):linear(0.3):diffusealpha(0.15)
				end
			end
		end)

		-- AddInputCallback handles login modal keyboard + wheel scroll.
		screen:AddInputCallback(function(event)
			local deviceInput = event.DeviceInput or {}
			local btn = deviceInput.button or ""
			local gameBtn = (event.GameInput and event.GameInput.button) or event.button
			local dbg = self:GetParent():GetChild("ClickDebug")

			-- Raw mouse click debug (FirstPress) so we can see clicks even if polling misses them
			if event.type == "InputEventType_FirstPress" and btn == "DeviceButton_left mouse button" then
				local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
				local hitLogin = IsMouseOverCentered(loginBtnCX, loginBtnCY, loginBtnW, loginBtnH)
				if dbg then
					dbg:settext(string.format("Click(FP): %s mx=%.0f my=%.0f", hitLogin and "LOGIN" or "no hit", mx, my))
					dbg:stoptweening():diffusealpha(1):sleep(2):linear(0.3):diffusealpha(0.15)
				end
				if hitLogin and not loginState.visible then
					loginState.visible = true
					loginState.focused = "email"
					loginState.status = "Tab / Enter to switch fields"
					MESSAGEMAN:Broadcast("ShowLoginOverlay")
					MESSAGEMAN:Broadcast("UpdateLoginOverlay")
					return true
				end
			end

			if loginState.visible then
				if event.type ~= "InputEventType_FirstPress" then return true end

				if btn == "DeviceButton_left shift" or btn == "DeviceButton_right shift"
					or btn == "DeviceButton_left ctrl" or btn == "DeviceButton_right ctrl"
					or btn == "DeviceButton_left alt" or btn == "DeviceButton_right alt" then
					return true
				end

				local shifted = INPUTFILTER:IsBeingPressed("DeviceButton_left shift") or
					INPUTFILTER:IsBeingPressed("DeviceButton_right shift") or
					(deviceInput.level and deviceInput.level > 1)
				local char = event.char or DeviceBtnToChar(btn, shifted)
				if char and #char == 1 then
					if loginState.focused == "email" then
						loginState.email = loginState.email .. char
					else
						loginState.password = loginState.password .. char
					end
					updateLoginUI()
					return true
				end

				if btn == "DeviceButton_backspace" then
					if loginState.focused == "email" then
						loginState.email = loginState.email:sub(1, -2)
					else
						loginState.password = loginState.password:sub(1, -2)
					end
					updateLoginUI()
				-- Some input layouts report Backspace as GameButton Back.
				elseif gameBtn == "Back" and btn ~= "DeviceButton_escape" then
					if loginState.focused == "email" then
						loginState.email = loginState.email:sub(1, -2)
					else
						loginState.password = loginState.password:sub(1, -2)
					end
					updateLoginUI()
				elseif btn == "DeviceButton_tab" then
					loginState.focused = loginState.focused == "email" and "password" or "email"
					updateLoginUI()
				elseif btn == "DeviceButton_return" or btn == "DeviceButton_enter" then
					if loginState.focused == "email" then
						loginState.focused = "password"
						updateLoginUI()
					else
						doLogin()
					end
				elseif btn == "DeviceButton_escape" then
					hideLogin()
				end
				return true
			end

			if event.type == "InputEventType_Release" then return end

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
		end)
	end
}

t[#t + 1] = LoadActor("../_cursor")

return t
