--- Holographic Void: ScreenSelectMusic Overlay
-- Restore sequential Til Death-style login flow.

local accentColor = color("#5ABAFF")
local brightText = color("1,1,1,1")

-- Login Button Constants
local btnCX = 8 + (SCREEN_WIDTH * 0.36) / 2
local btnCY = SCREEN_BOTTOM - 24
local btnW, btnH = 180, 28

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

-- Centralized Input Callback (Handles Click, Scroll, etc.)
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end
			local deviceInput = event.DeviceInput or {}
			local btn = deviceInput.button or ""
			
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
				local over = virtualX >= btnCX - btnW/2 and virtualX <= btnCX + btnW/2
						 and virtualY >= btnCY - btnH/2 and virtualY <= btnCY + btnH/2
				if over then
					if DLMAN:IsLoggedIn() then
						DLMAN:Logout()
						ms.ok("Logged Out")
					else
						MESSAGEMAN:Broadcast("TriggerLoginFlow")
					end
					return true
				end
			end
		end)
	end
}

t[#t + 1] = LoadActor("../_cursor")

return t
