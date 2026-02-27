--- Holographic Void: ScreenTitleMenu Background
-- Futuristic OLED black dashboard with animated grid and accent elements.

local accentColor = color("#5ABAFF")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local brightText = color("1,1,1,1")

-- Hitbox Constants
local pBtnW = 110
local pBtnCX = (SCREEN_RIGHT - 16) - pBtnW/2
local pBtnCY = (SCREEN_TOP + 14) + 28

local t = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(function(af)
			local virtualX = INPUTFILTER:GetMouseX()
			local virtualY = INPUTFILTER:GetMouseY()

			-- Profile Chip Hover
			local overProfile = virtualX >= pBtnCX - pBtnW/2 and virtualX <= pBtnCX + pBtnW/2
							and virtualY >= pBtnCY - 11 and virtualY <= pBtnCY + 11

			local prof = af:GetChild("ProfileChip")
			if prof then
				local bg = prof:GetChild("Bg")
				if overProfile then bg:glow(accentColor) else bg:glow(color("0,0,0,0")) end
			end

			-- Title Menu Hover
			local hovered = nil
			for i = 1, 4 do
				local static_iy = (SCREEN_CENTER_Y + 60) + 50 * (i - 1)
				if virtualX >= SCREEN_CENTER_X-150 and virtualX <= SCREEN_CENTER_X+150 
				   and virtualY >= static_iy-25 and virtualY <= static_iy+25 then
					hovered = i break
				end
			end
			if hovered ~= HV.TitleState.mouse.lastHovered then
				HV.TitleState.mouse.lastHovered = hovered
				local screen = SCREENMAN:GetTopScreen()
				if screen then
					local s = screen:GetChild("Scroller")
					if s and hovered then s:SetDestinationItem(hovered-1) end
				end
			end
		end)
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
		Trace("[HV] TriggerLoginFlow received in Title")
		easyInputStringOKCancel(
			"Email or Username:", 255, false,
			function(email)
				if email ~= "" then
					easyInputStringOKCancel(
						"Password:", 255, true,
						function(password)
							if password ~= "" then
								Trace("[HV] Attempting DLMAN:Login for " .. email)
								DLMAN:Login(email, password)
							else
								ms.ok("Login Canceled")
							end
						end,
						function() ms.ok("Login Canceled") end
					)
				else
					ms.ok("Login Canceled")
				end
			end,
			function() ms.ok("Login Canceled") end
		)
	end
}

HV.TitleState = HV.TitleState or {
	player = { song = nil, paused = true, offset = 0, lastStart = 0 },
	mouse = { lastHovered = nil }
}

-- Visual Elements
t[#t + 1] = Def.Quad { InitCommand=function(self) self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0,0,0,1")) end }
for i = 1, 8 do t[#t + 1] = Def.Quad { InitCommand=function(self) self:xy(SCREEN_CENTER_X, (SCREEN_HEIGHT / 9) * i):zoomto(SCREEN_WIDTH, 1):diffuse(color("1,1,1,0.03")) end } end
for i = 1, 15 do t[#t + 1] = Def.Quad { InitCommand=function(self) self:xy((SCREEN_WIDTH / 16) * i, SCREEN_CENTER_Y):zoomto(1, SCREEN_HEIGHT):diffuse(color("1,1,1,0.03")) end } end
t[#t + 1] = Def.Quad { InitCommand=function(self) self:xy(SCREEN_CENTER_X, SCREEN_TOP+2):zoomto(SCREEN_WIDTH*0.6, 2):diffuse(accentColor):diffusealpha(0.6) end }
t[#t + 1] = LoadFont("Common Large") .. { Text="HOLOGRAPHIC VOID", InitCommand=function(self) self:xy(SCREEN_CENTER_X, SCREEN_TOP+50):zoom(0.75):diffuse(brightText) end }

t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:SetUpdateFunction(function(af)
		af:GetChild("D"):settextf("%04d-%02d-%02d", Year(), MonthOfYear()+1, DayOfMonth())
		af:GetChild("T"):settextf("%02d:%02d:%02d", Hour(), Minute(), Second())
		
		local srv = af:GetChild("S")
		if IsNetSMOnline() then
			srv:settext("SERVER · " .. (GetServerName() or "CONNECTED")):diffuse(color("0.65,1,0.72,1"))
		else
			srv:settext("SERVER · OFFLINE"):diffuse(dimText)
		end
	end) end,
	LoadFont("Common Normal") .. { Name="D", InitCommand=function(self) self:xy(SCREEN_LEFT+16, SCREEN_TOP+14):halign(0):zoom(0.5):diffuse(subText) end },
	LoadFont("Common Normal") .. { Name="T", InitCommand=function(self) self:xy(SCREEN_LEFT+16, SCREEN_TOP+30):halign(0):zoom(0.35):diffuse(subText) end },
	LoadFont("Common Normal") .. { Name="S", InitCommand=function(self) self:xy(SCREEN_LEFT+16, SCREEN_TOP+44):halign(0):zoom(0.3):diffuse(dimText) end }
}

-- Profile chip (Top right, similar to spawncamping-wallhack)
t[#t + 1] = Def.ActorFrame {
	Name = "ProfileChip",
	InitCommand = function(self)
		self:xy(SCREEN_RIGHT - 10, 10):halign(1):valign(0)
		
		-- Auto-login persistence
		if not DLMAN:IsLoggedIn() then
			local user = ThemePrefs.Get("HV_Username")
			local token = ThemePrefs.Get("HV_PasswordToken")
			if user ~= "" and token ~= "" then
				Trace("[HV] Attempting Auto-Login for " .. user)
				DLMAN:LoginWithToken(user, token)
			end
		end
		self:SetUpdateFunction(function(af)
			local loggedIn = DLMAN:IsLoggedIn()
			local bg = af:GetChild("Bg")
			local txt = af:GetChild("Txt")
			if loggedIn then
				local name = DLMAN:GetUsername()
				local rank = DLMAN:GetSkillsetRank("Overall")
				local rating = DLMAN:GetSkillsetRating("Overall")
				txt:settextf("PROFILE · %s · #%d (%.2f)", name, rank, rating)
				txt:diffuse(color("0.65,1,0.72,1"))
				bg:diffuse(color("0.1,0.28,0.15,1"))
				
				-- Dynamically resize bg based on text width
				local w = math.max(110, txt:GetWidth() * txt:GetZoom() + 16)
				bg:zoomto(w, 22):x(-w/2)
				txt:x(-w/2)
			else
				txt:settext("PROFILE · OFFLINE"):diffuse(dimText)
				bg:diffuse(color("0.12,0.12,0.12,1"))
				bg:zoomto(110, 22):x(-110/2)
				txt:x(-110/2)
			end
		end)
	end,
	Def.Quad { Name="Bg", InitCommand=function(self) self:xy(-pBtnW/2, 28):zoomto(pBtnW, 22) end },
	LoadFont("Common Normal") .. { Name="Txt", InitCommand=function(self) self:xy(-pBtnW/2, 28):zoom(0.35) end }
}

-- Input Callback
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		screen:AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end
			local devInput = event.DeviceInput or {}
			local btn = devInput.button or ""

			if btn == "DeviceButton_backslash" then
				local p = HV.TitleState.player
				if p.paused then 
					if not p.song then p.song = SONGMAN:GetRandomSong() end
					if p.song then
						local mp = p.song:GetMusicPath()
						if mp then
							local start = p.song:GetSampleStart() + p.offset
							local len = p.song:GetSampleLength() - p.offset
							SOUND:PlayMusicPart(mp, start, len)
							p.lastStart = GetTimeSinceStart()
							p.paused = false
							MESSAGEMAN:Broadcast("PlayStatusChanged")
						end
					end
				else
					p.offset = p.offset + (GetTimeSinceStart() - p.lastStart)
					SOUND:StopMusic() p.paused = true
					MESSAGEMAN:Broadcast("PlayStatusChanged")
				end
				return true
			end

			if btn == "DeviceButton_left mouse button" then
				local virtualX = INPUTFILTER:GetMouseX()
				local virtualY = INPUTFILTER:GetMouseY()
				
				-- Profile Click
				if virtualX >= pBtnCX - pBtnW/2 and virtualX <= pBtnCX + pBtnW/2
				   and virtualY >= pBtnCY - 11 and virtualY <= pBtnCY + 11 then
					Trace("[HV] Profile chip clicked (Event-based)")
					if DLMAN:IsLoggedIn() then
						DLMAN:Logout()
						ms.ok("Logged Out")
					else
						MESSAGEMAN:Broadcast("TriggerLoginFlow")
					end
					return true
				end

				-- Menu Click
				local hovered = nil
				for i = 1, 4 do
					local iy = (SCREEN_CENTER_Y + 60) + 50 * (i - 1)
					if virtualX >= SCREEN_CENTER_X-150 and virtualX <= SCREEN_CENTER_X+150 
					   and virtualY >= iy-25 and virtualY <= iy+25 then
						hovered = i break
					end
				end
				if hovered then
					screen:Input({DeviceInput={button="DeviceButton_enter",type="InputEventType_FirstPress"},GameInput={button="Start",type="InputEventType_FirstPress"}})
					return true
				end
			end
		end)
	end
}

t[#t + 1] = Def.ActorFrame { Name="CB", OnCommand=function(self) self:diffusealpha(0.2) end,
	Def.ActorFrame { InitCommand=function(self) self:xy(SCREEN_LEFT+20, SCREEN_TOP+20) end, Def.Quad { InitCommand=function(self) self:halign(0):valign(0):zoomto(40,1):diffuse(accentColor) end }, Def.Quad { InitCommand=function(self) self:halign(0):valign(0):zoomto(1,40):diffuse(accentColor) end } },
	Def.ActorFrame { InitCommand=function(self) self:xy(SCREEN_RIGHT-20, SCREEN_BOTTOM-20) end, Def.Quad { InitCommand=function(self) self:halign(1):valign(1):zoomto(40,1):diffuse(accentColor) end }, Def.Quad { InitCommand=function(self) self:halign(1):valign(1):zoomto(1,40):diffuse(accentColor) end } }
}

return t
