-- Global State Initialization
HV.TitleState = HV.TitleState or {}
HV.TitleState.player = HV.TitleState.player or { song = nil, paused = true, offset = 0, lastStart = 0, duration = 0, history = {} }
HV.TitleState.mouse = HV.TitleState.mouse or { lastHovered = nil }
HV.TitleState.selectedProfile = HV.TitleState.selectedProfile or 0
HV.TitleState.showEffectsPopup = HV.TitleState.showEffectsPopup or false

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local brightText = color("1,1,1,1")

-- Preferences and Effects Logic
local PREF_DEFS = {
	HV_BGAnimIntensity = { Values = {"0", "1", "2"}, Choices = {"Off", "Subtle", "Full"} },
	HV_BackgroundEffect = { Values = {"Grid", "Hex", "Scanlines", "Flow", "Rays", "None"}, Choices = {"Grid", "Hex", "Scanlines", "Flow", "Rays", "None"} },
	HV_EnableGlow = { Values = {"false", "true"}, Choices = {"Off", "On"} },
	HV_Particles = { Values = {"false", "true"}, Choices = {"Off", "On"} },
}

local rows = {
	{ Name = "Animations", Pref = "HV_BGAnimIntensity" },
	{ Name = "Style", Pref = "HV_BackgroundEffect" },
	{ Name = "Glow", Pref = "HV_EnableGlow" },
	{ Name = "Particles", Pref = "HV_Particles" },
}

local function cyclePref(name)
	local pref = PREF_DEFS[name]
	if not pref then return end
	local current = tostring(ThemePrefs.Get(name))
	local idx = 1
	for i, v in ipairs(pref.Values) do
		if tostring(v) == current then idx = i break end
	end
	idx = (idx % #pref.Values) + 1
	ThemePrefs.Set(name, pref.Values[idx])
	ThemePrefs.Save()
	MESSAGEMAN:Broadcast("ThemePrefChanged", {Name = name})
end

-- Visual Elements State
local intensityMode = ThemePrefs.Get("HV_BGAnimIntensity")
local bgEffect = ThemePrefs.Get("HV_BackgroundEffect")
local isGlowEnabled = tostring(ThemePrefs.Get("HV_EnableGlow")) == "true"

local function getIntensityAlpha(base)
	local mode = tostring(intensityMode)
	if mode == "0" then return base * 0.3 end -- Static but visible
	if mode == "1" then return base * 0.6 end
	return base
end

local function getIntensitySpeed(base)
	if intensityMode == "0" then return 0 end
	if intensityMode == "1" then return base * 0.4 end
	return base
end

-- Hitbox Constants
local pBtnW = 240
local pBtnH = 70
local pBtnCX = (SCREEN_RIGHT - 10) - pBtnW/2
local pBtnCY = 10 + pBtnH/2

-- Media Player Constants
local mpBarH = 40
local mpBarY = SCREEN_BOTTOM - mpBarH/2
local mpBtnSize = 24
local mpPrevX = SCREEN_LEFT + 28
local mpPlayX = SCREEN_LEFT + 60
local mpNextX = SCREEN_LEFT + 92
local mpBtnY = mpBarY
local mpPlayPath = THEME:GetPathG("", "mp_play")
local mpPausePath = THEME:GetPathG("", "mp_pause")
local mpPrevPath = THEME:GetPathG("", "mp_prev")
local mpNextPath = THEME:GetPathG("", "mp_next")

local t = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(function(af)
			local virtualX = INPUTFILTER:GetMouseX()
			local virtualY = INPUTFILTER:GetMouseY()

			-- Profile Chip Hover
			local overProfile = virtualX >= pBtnCX - pBtnW/2 and virtualX <= pBtnCX + pBtnW/2
							and virtualY >= pBtnCY - pBtnH/2 and virtualY <= pBtnCY + pBtnH/2
			
			local prof = af:GetChild("ProfileChip")
			if prof then
				local bg = prof:GetChild("Bg")
				if overProfile and isGlowEnabled then
					bg:glow(accentColor)
				else
					bg:glow(color("0,0,0,0"))
				end
			end

			-- Title Menu Hover (5 items)
			local hovered = nil
			for i = 1, 5 do
				local static_iy = (SCREEN_CENTER_Y + 20) + 44 * (i - 3)
				if virtualX >= SCREEN_CENTER_X-150 and virtualX <= SCREEN_CENTER_X+150 
				   and virtualY >= static_iy-22 and virtualY <= static_iy+22 then
					hovered = i break
				end
			end

			-- Selection Glow
			local selGlow = af:GetChild("SelectionGlow")
			if selGlow then
				if hovered then
					local selY = (SCREEN_CENTER_Y + 20) + 44 * (hovered - 3)
					selGlow:stoptweening():linear(0.05):y(selY):diffusealpha(isGlowEnabled and 0.4 or 0)
				else
					selGlow:stoptweening():linear(0.1):diffusealpha(0)
				end
			end

			if hovered ~= HV.TitleState.mouse.lastHovered then
				HV.TitleState.mouse.lastHovered = hovered
				local screen = SCREENMAN:GetTopScreen()
				if screen and hovered then
					-- 1. Sync scroller (visual)
					if screen:GetChild("Scroller") then
						screen:GetChild("Scroller"):SetDestinationItem(hovered - 1)
					end
					-- 2. Sync selection (engine)
					if screen.SetCurrentChoice then
						local choiceNames = {"Start", "ColorTheme", "PackDownloader", "Options", "Exit"}
						screen:SetCurrentChoice(choiceNames[hovered])
					end
				end
			end
		end)
	end,
	ThemePrefChangedMessageCommand = function(self)
		self:playcommand("Refresh")
	end,
	-- ... (rest of the system commands)
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
		-- Clear song history on screen exit
		if HV.TitleState and HV.TitleState.player then
			HV.TitleState.player.history = {}
		end
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
		ms.ok(THEME:GetString("ScreenTitleMenu", "LoginFailed"))
	end,
	LogOutMessageCommand = function(self)
		-- Only clear username on manual logout to preserve auto-login token
	end,
	TriggerLoginFlowMessageCommand = function(self)
		Trace("[HV] TriggerLoginFlow received in Title")
		easyInputStringOKCancel(
			THEME:GetString("ScreenTitleMenu", "EmailPrompt"), 255, false,
			function(email)
				if email ~= "" then
					self.tempEmail = email
					self:sleep(0.02):queuecommand("LoginStep2")
				else
					ms.ok(THEME:GetString("ScreenTitleMenu", "LoginCanceled"))
				end
			end,
			function() ms.ok(THEME:GetString("ScreenTitleMenu", "LoginCanceled")) end
		)
	end,
	
	LoginStep2Command = function(self)
		easyInputStringOKCancel(
			THEME:GetString("ScreenTitleMenu", "PasswordPrompt"), 255, true,
			function(password)
				if password ~= "" then
					Trace("[HV] Attempting DLMAN:Login for " .. tostring(self.tempEmail))
					DLMAN:Login(self.tempEmail, password)
				else
					ms.ok(THEME:GetString("ScreenTitleMenu", "LoginCanceled"))
				end
			end,
			function() ms.ok(THEME:GetString("ScreenTitleMenu", "LoginCanceled")) end
		)
	end
}


-- Jukebox Helper Functions
local function jukeboxPlaySong(song)
	local p = HV.TitleState.player
	if not song then return end
	local mp = song:GetMusicPath()
	if not mp then return end
	p.song = song
	p.offset = 0
	p.duration = song:MusicLengthSeconds()
	local start = 0
	SOUND:PlayMusicPart(mp, start, p.duration)
	p.lastStart = GetTimeSinceStart()
	p.paused = false
	MESSAGEMAN:Broadcast("PlayStatusChanged")
end

local function jukeboxPause()
	local p = HV.TitleState.player
	if p.paused or not p.song then return end
	p.offset = p.offset + (GetTimeSinceStart() - p.lastStart)
	SOUND:StopMusic()
	p.paused = true
	MESSAGEMAN:Broadcast("PlayStatusChanged")
end

local function jukeboxResume()
	local p = HV.TitleState.player
	if not p.paused or not p.song then return end
	local mp = p.song:GetMusicPath()
	if not mp then return end
	local start = p.offset
	local len = p.duration - p.offset
	if len <= 0 then len = p.duration; p.offset = 0; start = 0 end
	SOUND:PlayMusicPart(mp, start, len)
	p.lastStart = GetTimeSinceStart()
	p.paused = false
	MESSAGEMAN:Broadcast("PlayStatusChanged")
end

local function jukeboxNext()
	local p = HV.TitleState.player
	-- Push current song to history
	if p.song then
		p.history[#p.history + 1] = p.song
	end

	local allSongs = SONGMAN:GetAllSongs()
	if #allSongs > 0 then
		local newSong = allSongs[math.random(#allSongs)]
		if newSong then jukeboxPlaySong(newSong) end
	end
end

local function jukeboxPrev()
	local p = HV.TitleState.player
	if #p.history == 0 then return end
	local prevSong = table.remove(p.history)
	if prevSong then jukeboxPlaySong(prevSong) end
end

-- Visual Elements
-- Background Effects (Controlled by HV_BackgroundEffect and HV_BGAnimIntensity)
local baseAlpha = 0.03

local bgEffectsFrame = Def.ActorFrame {
	Name = "BGEffects",
	ThemePrefChangedMessageCommand = function(self, params)
		local name = (type(params) == "table") and params.Name or params
		if name == "HV_BGAnimIntensity" or name == "HV_BackgroundEffect" or name == "HV_EnableGlow" then
			self:playcommand("Refresh")
		end
	end,
	OnCommand = function(self)
		self:playcommand("Refresh")
	end,
	RefreshCommand = function(self)
		-- Sync local variables for children to use
		intensityMode = ThemePrefs.Get("HV_BGAnimIntensity")
		bgEffect = ThemePrefs.Get("HV_BackgroundEffect")
		isGlowEnabled = tostring(ThemePrefs.Get("HV_EnableGlow")) == "true"

		self:GetChild("Grid"):visible(bgEffect == "Grid")
		self:GetChild("Hex"):visible(bgEffect == "Hex")
		self:GetChild("Scanlines"):visible(bgEffect == "Scanlines")
		self:GetChild("Flow"):visible(bgEffect == "Flow")
		self:GetChild("Rays"):visible(bgEffect == "Rays")
		
		local alpha = 1
		if bgEffect == "None" then alpha = 0 end
		self:finishtweening():diffusealpha(alpha)
		
		local selGlow = self:GetChild("SelectionGlow")
		if selGlow then
			selGlow:glow(accentColor):diffuse(accentColor)
		end

		self:playcommand("UpdateAlpha")
		self:playcommand("UpdateSpeed")
	end,
	UpdateAlphaCommand = function(self)
		-- Alpha is handled by parent AF and individual children
	end,
}

t[#t + 1] = Def.Quad {
	Name = "SelectionGlow",
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):zoomto(300, 40):diffusealpha(0):fadetop(0.2):fadebottom(0.2) end
}

-- GRID EFFECT
local grid = Def.ActorFrame { 
	Name = "Grid", 
	InitCommand = function(self) 
		self:visible(bgEffect == "Grid") 
		self:SetUpdateFunction(function(af, dt)
			local speed = getIntensitySpeed(20)
			if speed <= 0 then return end
			for i=1, 12 do
				local child = af:GetChild("HLine"..i)
				if child then
					local newY = child:GetY() + speed * dt * 2
					if newY > SCREEN_BOTTOM + 40 then newY = SCREEN_TOP - 40 end
					child:y(newY)
				end
			end
		end)
	end
}
-- Horizontal lines (Scrolling)
local spaceY = SCREEN_HEIGHT / 10
for i = 1, 12 do 
	grid[#grid + 1] = Def.Quad { 
		Name = "HLine"..i,
		InitCommand=function(self) self:xy(SCREEN_CENTER_X, (spaceY * (i-1)) - 40):zoomto(SCREEN_WIDTH, 1) end, 
		UpdateAlphaCommand=function(self) self:diffusealpha(getIntensityAlpha(0.04)) end 
	} 
end
-- Vertical lines (Static)
local spaceX = SCREEN_WIDTH / 16
for i = 1, 15 do 
	grid[#grid + 1] = Def.Quad { 
		InitCommand=function(self) self:xy(spaceX * i, SCREEN_CENTER_Y):zoomto(1, SCREEN_HEIGHT) end, 
		UpdateAlphaCommand=function(self) self:diffusealpha(getIntensityAlpha(0.04)) end 
	} 
end
bgEffectsFrame[#bgEffectsFrame + 1] = grid

-- HEX EFFECT
local hex = Def.ActorFrame { Name = "Hex", InitCommand = function(self) self:visible(bgEffect == "Hex") end }
local hexSize = 60
for y = 0, SCREEN_HEIGHT, hexSize * 1.5 do
	for x = 0, SCREEN_WIDTH + hexSize, hexSize * 1.5 do
		hex[#hex + 1] = Def.ActorFrame {
			InitCommand = function(self) self:xy(x, y) end,
			Def.ActorFrame {
				Name = "Spinner",
				InitCommand = function(self) self:playcommand("UpdateSpeed") end,
				UpdateSpeedCommand = function(self)
					self:stopeffect():spin():effectmagnitude(0, 0, getIntensitySpeed(20))
				end,
				Def.Quad {
					InitCommand = function(self) self:zoomto(hexSize/2.5, hexSize/2.5):rotationz(45) end,
					UpdateAlphaCommand = function(self) self:diffusealpha(getIntensityAlpha(0.04)) end,
				}
			}
		}
	end
end
bgEffectsFrame[#bgEffectsFrame + 1] = hex

-- SCANLINES EFFECT (Redesigned as rolling highlights)
local scanlines = Def.ActorFrame { Name = "Scanlines", InitCommand = function(self) self:visible(bgEffect == "Scanlines") end }
for i = 1, 3 do
	scanlines[#scanlines + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, -200):zoomto(SCREEN_WIDTH, 120):diffuse(accentColor)
		end,
		UpdateAlphaCommand = function(self) self:diffusealpha(getIntensityAlpha(0.08)) end,
		OnCommand = function(self) self:playcommand("Scroll") end,
		ScrollCommand = function(self)
			local speed = getIntensitySpeed(1)
			if speed <= 0 then 
				self:stoptweening():y(SCREEN_CENTER_Y + (i-2)*200)
				return 
			end
			self:stoptweening():y(SCREEN_TOP - 100):sleep(i * 1.5):linear(4 / speed):y(SCREEN_BOTTOM + 100):sleep(math.random(1, 3)):queuecommand("Scroll")
		end
	}
end
scanlines.RefreshCommand = function(self) self:playcommand("Scroll") end
bgEffectsFrame[#bgEffectsFrame + 1] = scanlines

-- FLOW EFFECT (Redesigned with thicker digital streaks)
local flow = Def.ActorFrame { Name = "Flow", InitCommand = function(self) self:visible(bgEffect == "Flow") end }
for i = 1, 15 do
	local baseSpeed = math.random(400, 1000)
	flow[#flow + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(math.random(SCREEN_WIDTH), math.random(SCREEN_HEIGHT))
				:zoomto(math.random(150, 500), math.random(2, 4)):diffuse(accentColor)
		end,
		UpdateAlphaCommand = function(self) self:diffusealpha(getIntensityAlpha(0.18)) end,
		OnCommand = function(self) self:queuecommand("Move") end,
		RefreshCommand = function(self) self:stoptweening():queuecommand("Move") end,
		MoveCommand = function(self)
			local speed = getIntensitySpeed(baseSpeed)
			if speed <= 0 then 
				self:stoptweening():x(math.random(SCREEN_WIDTH))
				return 
			end
			self:stoptweening():x(SCREEN_RIGHT + 300):linear(SCREEN_WIDTH/speed):x(SCREEN_LEFT - 300):sleep(math.random(0, 5)/10):queuecommand("Move")
		end
	}
end
bgEffectsFrame[#bgEffectsFrame + 1] = flow

-- RAYS EFFECT (Renamed from 4DCube)
local rays = Def.ActorFrame { 
	Name = "Rays", 
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):visible(bgEffect == "Rays") end 
}
for i = 1, 2 do
	rays[#rays + 1] = Def.ActorFrame {
		InitCommand = function(self) self:playcommand("UpdateSpeed") end,
		UpdateSpeedCommand = function(self)
			self:stopeffect():spin():effectmagnitude(getIntensitySpeed(20), getIntensitySpeed(15), getIntensitySpeed(10))
		end,
		Def.ActorFrame {
			Name = "Inner",
			InitCommand = function(self) self:playcommand("UpdateSpeed") end,
			UpdateSpeedCommand = function(self)
				self:stopeffect():spin():effectmagnitude(getIntensitySpeed(10), getIntensitySpeed(-8), getIntensitySpeed(5))
			end,
			Def.Quad { 
				InitCommand=function(self) self:zoomto(400, 2) end,
				UpdateAlphaCommand=function(self) self:diffuse(accentColor):diffusealpha(getIntensityAlpha(0.15)) end
			},
			Def.Quad { 
				InitCommand=function(self) self:zoomto(2, 400) end,
				UpdateAlphaCommand=function(self) self:diffuse(accentColor):diffusealpha(getIntensityAlpha(0.15)) end
			},
		}
	}
end
bgEffectsFrame[#bgEffectsFrame + 1] = rays

t[#t + 1] = bgEffectsFrame

t[#t + 1] = Def.Quad { 
	Name = "TopBar",
	InitCommand=function(self) self:xy(SCREEN_CENTER_X, SCREEN_TOP+2):zoomto(SCREEN_WIDTH*0.6, 2):diffuse(accentColor):diffusealpha(0.6) end, 
	ThemePrefChangedMessageCommand=function(self, params) 
		if params.Name == "HV_BGAnimIntensity" or params.Name == "HV_EnableGlow" then 
			self:playcommand("Refresh") 
		end 
	end, 
	RefreshCommand=function(self)
		local alpha = 0.6
		if tostring(ThemePrefs.Get("HV_BGAnimIntensity")) == "0" then alpha = 0 end
		self:finishtweening():diffusealpha(alpha)
		
		local glow = color("0,0,0,0")
		if tostring(ThemePrefs.Get("HV_EnableGlow")) == "true" then glow = accentColor end
		self:glow(glow)
	end,
	OnCommand=function(self) self:playcommand("Refresh") end
}

t[#t + 1] = Def.ActorFrame {
	Name = "LogoContainer",
	InitCommand=function(self) self:xy(SCREEN_CENTER_X, SCREEN_TOP+50) end,
	-- Persistent Glow Layer
	LoadFont("Common Large") .. { 
		Text="HOLOGRAPHIC VOID", 
		InitCommand=function(self) self:zoom(0.75):diffuse(accentColor):diffusealpha(0) end,
		RefreshCommand=function(self)
			self:stopeffect():stoptweening()
			if tostring(ThemePrefs.Get("HV_EnableGlow")) == "true" then
				self:diffusealpha(0.4):glow(accentColor)
				self:thump():effectmagnitude(1.02, 1.02, 1.02):effectperiod(2)
			else
				self:diffusealpha(0)
			end
		end,
		OnCommand=function(self) self:playcommand("Refresh") end,
		ThemePrefChangedMessageCommand=function(self, params) if params.Name == "HV_EnableGlow" then self:playcommand("Refresh") end end
	},
	-- Main Text
	LoadFont("Common Large") .. { 
		Text="HOLOGRAPHIC VOID", 
		InitCommand=function(self) self:zoom(0.75):diffuse(brightText) end 
	}
}

-- Load Shared Background Particles
t[#t + 1] = LoadActor("../_particles.lua")

t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self) self:SetUpdateFunction(function(af)
		af:GetChild("D"):settextf("%04d-%02d-%02d", Year(), MonthOfYear()+1, DayOfMonth())
		af:GetChild("T"):settextf("%02d:%02d:%02d", Hour(), Minute(), Second())
		
		local srv = af:GetChild("S")
		if IsNetSMOnline() then
			srv:settext(THEME:GetString("ScreenTitleMenu", "Server") .. " · " .. (GetServerName() or THEME:GetString("ScreenTitleMenu", "Connected"))):diffuse(color("0.65,1,0.72,1"))
		else
			srv:settext(THEME:GetString("ScreenTitleMenu", "Server") .. " · " .. THEME:GetString("ScreenTitleMenu", "Offline")):diffuse(dimText)
		end
	end) end,
	LoadFont("Common Normal") .. { Name="D", InitCommand=function(self) self:xy(SCREEN_LEFT+16, SCREEN_TOP+14):halign(0):zoom(0.5):diffuse(subText) end },
	LoadFont("Common Normal") .. { Name="T", InitCommand=function(self) self:xy(SCREEN_LEFT+16, SCREEN_TOP+30):halign(0):zoom(0.35):diffuse(subText) end },
	LoadFont("Common Normal") .. { Name="S", InitCommand=function(self) self:xy(SCREEN_LEFT+16, SCREEN_TOP+44):halign(0):zoom(0.3):diffuse(dimText) end }
}

-- Profile chip (Top right) + Inline Profile List
local maxCompactProfiles = 4  -- max compact rows to show
local compactRowH = 28
local compactRowW = pBtnW

t[#t + 1] = Def.ActorFrame {
	Name = "ProfileChip",
	InitCommand = function(self)
		self:xy(SCREEN_RIGHT - 10, 10 + pBtnH/2)
		self:SetUpdateFunction(function(af)
			if not af then return end
			local loggedIn = DLMAN:IsLoggedIn()
			local status = af:GetChild("Status")
			local name = af:GetChild("Name")
			local rating = af:GetChild("Rating")
			local rank = af:GetChild("Rank")
			local avatar = af:GetChild("Avatar")
			local bg = af:GetChild("Bg")

			-- Skip update if essential children are missing
			if not status or not name or not rating or not rank or not avatar then return end

			local numLocal = PROFILEMAN:GetNumLocalProfiles()
			local selIdx = HV.TitleState.selectedProfile or 0
			-- Clamp selection
			if selIdx >= numLocal then selIdx = 0; HV.TitleState.selectedProfile = 0 end

			if loggedIn then
				status:settext(THEME:GetString("ScreenTitleMenu", "Online")):diffuse(color("0.65,1,0.72,1"))
				name:settext(DLMAN:GetUsername())
				local r = DLMAN:GetSkillsetRating("Overall")
				local showStats = HV.ShowProfileStats()
				rating:visible(showStats):settextf("%.2f", r):diffuse(HVColor.GetMSDRatingColor(r))
				rank:visible(showStats):settextf("#%d", DLMAN:GetSkillsetRank("Overall")):diffuse(subText)
				if bg then bg:diffuse(color("0.1,0.28,0.15,0.85")) end

				local path = getAvatarPath()
				if path and path ~= avatar.lastPath then
					avatar:Load(path)
					avatar:scaletoclipped(50, 50)
					avatar.lastPath = path
				end
				avatar:visible(true)
			else
				status:settext(THEME:GetString("ScreenTitleMenu", "Offline")):diffuse(dimText)

				if numLocal > 0 then
					local profile = PROFILEMAN:GetLocalProfileFromIndex(selIdx)
					local profileID = PROFILEMAN:GetLocalProfileIDFromIndex(selIdx)
					if profile then
						name:settext(profile:GetDisplayName())
						local r = profile:GetPlayerRating()
						local showStats = HV.ShowProfileStats()
						rating:visible(showStats):settextf("%.2f", r):diffuse(HVColor.GetMSDRatingColor(r))
						rank:visible(false)

						local path = getAssetPathFromProfileID("avatar", profileID)
						if path and path ~= avatar.lastPath then
							avatar:Load(path)
							avatar:scaletoclipped(50, 50)
							avatar.lastPath = path
						end
						avatar:visible(true)
					else
						name:settext(THEME:GetString("ScreenTitleMenu", "NoProfile"))
						rating:visible(false)
						rank:visible(false)
						avatar:visible(false)
					end
				else
					name:settext(THEME:GetString("ScreenTitleMenu", "GuestPlayer"))
					rating:visible(false)
					rank:visible(false)
					avatar:visible(false)
				end
				if bg then bg:diffuse(color("0.12,0.12,0.12,0.85")) end
			end

			-- Update compact profile rows
			for ci = 0, maxCompactProfiles - 1 do
				local row = af:GetChild("CompactRow_" .. ci)
				if row then
					if loggedIn or numLocal <= 1 then
						row:visible(false)
					else
						-- Map compact row index to profile index (skip selected)
						local profileIdx = ci
						if profileIdx >= selIdx then profileIdx = profileIdx + 1 end
						if profileIdx < numLocal then
							row:visible(true)
							local p = PROFILEMAN:GetLocalProfileFromIndex(profileIdx)
							local pid = PROFILEMAN:GetLocalProfileIDFromIndex(profileIdx)
							local cName = row:GetChild("CName")
							local cRating = row:GetChild("CRating")
							local cAvatar = row:GetChild("CAvatar")
							local cBg = row:GetChild("CBg")
							if cName and p then cName:settext(p:GetDisplayName()) end
							if cRating and p then
								local r = p:GetPlayerRating()
								local showStats = HV.ShowProfileStats()
								cRating:visible(showStats):settextf("%.2f", r):diffuse(HVColor.GetMSDRatingColor(r))
							end
							if cAvatar and pid then
								local apath = getAssetPathFromProfileID("avatar", pid)
								if apath and apath ~= cAvatar.lastPath then
									cAvatar:Load(apath)
									cAvatar:scaletoclipped(22, 22)
									cAvatar.lastPath = apath
								end
							end
							-- Store the actual profile index for click handling
							row.profileIdx = profileIdx
						else
							row:visible(false)
						end
					end
				end
			end
		end)
	end,
	Def.Quad { Name="Bg", InitCommand=function(self) self:x(-pBtnW/2):zoomto(pBtnW, pBtnH) end },
	LoadFont("Common Normal") .. { Name="Status", InitCommand=function(self) self:xy(-pBtnW + 10, -22):halign(0):zoom(0.3) end },
	LoadFont("Common Normal") .. { Name="Name", InitCommand=function(self) self:xy(-pBtnW + 10, -5):halign(0):zoom(0.45):diffuse(brightText) end },
	LoadFont("Common Large") .. { Name="Rating", InitCommand=function(self) self:xy(-pBtnW + 10, 18):halign(0):zoom(0.4) end },
	LoadFont("Common Normal") .. { Name="Rank", InitCommand=function(self) self:xy(-110, 18):halign(0):zoom(0.4) end },
	Def.Sprite { Name="Avatar", InitCommand=function(self) self:xy(-35, 0):zoomto(50, 50) end }
}

-- Add compact profile rows below the main chip
local chipRef = t[#t]  -- reference to ProfileChip
for ci = 0, maxCompactProfiles - 1 do
	local rowY = pBtnH/2 + compactRowH/2 + 4 + ci * (compactRowH + 2)
	chipRef[#chipRef + 1] = Def.ActorFrame {
		Name = "CompactRow_" .. ci,
		InitCommand = function(self) self:y(rowY):visible(false) end,
		-- Row background
		Def.Quad {
			Name = "CBg",
			InitCommand = function(self)
				self:x(-pBtnW/2):zoomto(pBtnW, compactRowH)
					:diffuse(color("0.08,0.08,0.08,0.9"))
			end
		},
		-- Compact avatar
		Def.Sprite {
			Name = "CAvatar",
			InitCommand = function(self) self:xy(-pBtnW + 18, 0):zoomto(22, 22) end
		},
		-- Compact name
		LoadFont("Common Normal") .. {
			Name = "CName",
			InitCommand = function(self)
				self:xy(-pBtnW + 36, -4):halign(0):zoom(0.32):diffuse(subText)
					:maxwidth((pBtnW - 90) / 0.32)
			end
		},
		-- Compact rating
		LoadFont("Common Normal") .. {
			Name = "CRating",
			InitCommand = function(self)
				self:xy(-pBtnW + 36, 8):halign(0):zoom(0.26):diffuse(dimText)
			end
		}
	}
end


-- Custom Message Handlers
t[#t + 1] = Def.Actor {
	TriggerJukeboxPauseMessageCommand = function(self)
		local p = HV.TitleState.player
		if p.paused then
			if not p.song then jukeboxNext() else jukeboxResume() end
		else
			jukeboxPause()
		end
	end
}

-- Media Player Bar
t[#t + 1] = Def.ActorFrame {
	Name = "MediaPlayer",
	InitCommand = function(self)
		local lastPausedState = nil
		self:SetUpdateFunction(function(af)
			local p = HV.TitleState.player
			-- Update song text
			local songTxt = af:GetChild("SongText")
			if songTxt then
				if p.song then
					local artist = p.song:GetDisplayArtist() or "?"
					local title = p.song:GetDisplayMainTitle() or "?"
					songTxt:settext(artist .. " — " .. title)
					songTxt:diffuse(subText)
				else
					songTxt:settext(THEME:GetString("ScreenTitleMenu", "JukeboxNoTrack"))
					songTxt:diffuse(dimText)
				end
			end
			-- Update elapsed time
			local timeTxt = af:GetChild("ElapsedTime")
			if timeTxt then
				if p.song and not p.paused then
					local elapsed = p.offset + (GetTimeSinceStart() - p.lastStart)
					timeTxt:settext(SecondsToMSS(elapsed))
					timeTxt:diffuse(subText)
				elseif p.song and p.paused then
					timeTxt:settext(SecondsToMSS(p.offset))
					timeTxt:diffuse(dimText)
				else
					timeTxt:settext("—:——")
					timeTxt:diffuse(dimText)
				end
			end
			-- Update progress bar
			local bar = af:GetChild("ProgressBar")
			if bar then
				if p.song and p.duration > 0 then
					local elapsed = p.offset
					if not p.paused then
						elapsed = p.offset + (GetTimeSinceStart() - p.lastStart)
					end
					local percent = math.max(0, math.min(1, elapsed / p.duration))
					bar:zoomto(SCREEN_WIDTH * percent, 2)
				else
					bar:zoomto(0, 2)
				end
			end

			-- Swap play/pause icon only when state changes
			if lastPausedState ~= p.paused then
				lastPausedState = p.paused
				local playBtn = af:GetChild("PlayBtn")
				if playBtn then
					if p.paused then
						playBtn:Load(mpPlayPath)
					else
						playBtn:Load(mpPausePath)
					end
					playBtn:zoomto(mpBtnSize, mpBtnSize)
				end
			end
		end)
	end,
	-- Bar background
	Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, mpBarY):zoomto(SCREEN_WIDTH, mpBarH)
			self:diffuse(color("0.06,0.06,0.06,0.92"))
		end
	},
	-- Top edge accent line (Progress Bar)
	Def.Quad {
		Name = "ProgressBar",
		InitCommand = function(self)
			self:xy(SCREEN_LEFT, mpBarY - mpBarH/2):halign(0):zoomto(0, 2)
			self:diffuse(accentColor):diffusealpha(0.6)
		end
	},
	-- Prev button
	UIElements.SpriteButton(1, 1, mpPrevPath) .. {
		Name = "PrevBtn",
		InitCommand = function(self)
			self:xy(mpPrevX, mpBtnY):zoomto(mpBtnSize, mpBtnSize):diffusealpha(0.5)
		end,
		MouseOverCommand = function(self) self:stoptweening():linear(0.1):diffusealpha(1) end,
		MouseOutCommand = function(self) self:stoptweening():linear(0.1):diffusealpha(0.5) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				jukeboxPrev()
			end
		end
	},
	-- Play/Pause button
	UIElements.SpriteButton(1, 1, mpPlayPath) .. {
		Name = "PlayBtn",
		InitCommand = function(self)
			self:xy(mpPlayX, mpBtnY):zoomto(mpBtnSize, mpBtnSize):diffusealpha(0.7)
		end,
		MouseOverCommand = function(self) self:stoptweening():linear(0.1):diffusealpha(1) end,
		MouseOutCommand = function(self) self:stoptweening():linear(0.1):diffusealpha(0.7) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				local p = HV.TitleState.player
				if p.paused then
					if not p.song then jukeboxNext() else jukeboxResume() end
				else
					jukeboxPause()
				end
			end
		end
	},
	-- Next button
	UIElements.SpriteButton(1, 1, mpNextPath) .. {
		Name = "NextBtn",
		InitCommand = function(self)
			self:xy(mpNextX, mpBtnY):zoomto(mpBtnSize, mpBtnSize):diffusealpha(0.5)
		end,
		MouseOverCommand = function(self) self:stoptweening():linear(0.1):diffusealpha(1) end,
		MouseOutCommand = function(self) self:stoptweening():linear(0.1):diffusealpha(0.5) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				jukeboxNext()
			end
		end
	},
	-- Song text
	LoadFont("Common Normal") .. {
		Name = "SongText",
		Text = "NO TRACK",
		InitCommand = function(self)
			self:xy(SCREEN_LEFT + 120, mpBtnY):halign(0):zoom(0.35)
			self:diffuse(dimText):maxwidth((SCREEN_WIDTH - 200) / 0.35)
		end
	},
	-- Elapsed time
	LoadFont("Common Normal") .. {
		Name = "ElapsedTime",
		Text = "—:——",
		InitCommand = function(self)
			self:xy(SCREEN_RIGHT - 16, mpBtnY):halign(1):zoom(0.3)
			self:diffuse(dimText)
		end
	}
}

t[#t + 1] = Def.ActorFrame { Name="CB", OnCommand=function(self) self:diffusealpha(0.2) end,
	Def.ActorFrame { InitCommand=function(self) self:xy(SCREEN_LEFT+20, SCREEN_TOP+20) end, Def.Quad { InitCommand=function(self) self:halign(0):valign(0):zoomto(40,1):diffuse(accentColor) end }, Def.Quad { InitCommand=function(self) self:halign(0):valign(0):zoomto(1,40):diffuse(accentColor) end } },
	Def.ActorFrame { InitCommand=function(self) self:xy(SCREEN_RIGHT-20, SCREEN_BOTTOM-20) end, Def.Quad { InitCommand=function(self) self:halign(1):valign(1):zoomto(40,1):diffuse(accentColor) end }, Def.Quad { InitCommand=function(self) self:halign(1):valign(1):zoomto(1,40):diffuse(accentColor) end } }
}

-- Standalone Effects Button (Bottom Right)
t[#t + 1] = Def.ActorFrame {
	Name = "EffectsButton",
	InitCommand = function(self) self:xy(SCREEN_RIGHT - 20, SCREEN_BOTTOM - 60) end,
	
	-- Toggleable Panel
	Def.ActorFrame {
		Name = "PopupPanel",
		InitCommand = function(self) self:y(-100):visible(false):diffusealpha(0) end,
		ShowEffectsPopupMessageCommand = function(self)
			if self:GetVisible() then
				self:playcommand("Hide")
			else
				self:visible(true):stoptweening():decelerate(0.2):diffusealpha(1):y(-110)
			end
		end,
		HideEffectsPopupMessageCommand = function(self) self:playcommand("Hide") end,
		HideCommand = function(self)
			self:stoptweening():accelerate(0.2):diffusealpha(0):y(-100):sleep(0):queuecommand("Off")
		end,
		OffCommand = function(self) self:visible(false) end,
		
		-- Panel BG
		Def.Quad {
			InitCommand = function(self) 
				self:halign(1):zoomto(220, 150):diffuse(color("0.05,0.05,0.05,0.98")):diffusebottomedge(color("0,0,0,1"))
			end
		},
		-- Header
		LoadFont("Common Normal") .. {
			Text = "VISUAL EFFECTS",
			InitCommand = function(self) self:xy(-110, -60):zoom(0.4):diffuse(accentColor):playcommand("RefreshGlow") end,
			ThemePrefChangedMessageCommand = function(self) self:playcommand("RefreshGlow") end,
			RefreshGlowCommand = function(self)
				if isGlowEnabled then self:glow(accentColor) else self:glow(color("0,0,0,0")) end
			end
		},
		-- Option Rows
		(function()
			local r = Def.ActorFrame { InitCommand = function(self) self:y(-10) end }
			for i, row in ipairs(rows) do
				local ry = (i - 2.5) * 26
				r[#r+1] = Def.ActorFrame {
					InitCommand = function(self) self:y(ry) end,
					-- Row Label
					LoadFont("Common Normal") .. {
						Text = row.Name,
						InitCommand = function(self) self:x(-205):halign(0):zoom(0.35):diffuse(color("0.6,0.6,0.6,1")) end
					},
					-- Row Value
					LoadFont("Common Normal") .. {
						Name = "Val",
						InitCommand = function(self) self:x(-15):halign(1):zoom(0.35) end,
						ThemePrefChangedMessageCommand = function(self, params) if params.Name == row.Pref then self:playcommand("Refresh") end end,
						RefreshCommand = function(self)
							local val = tostring(ThemePrefs.Get(row.Pref))
							local def = PREF_DEFS[row.Pref]
							local display = val
							for j, v in ipairs(def.Values) do if tostring(v) == val then display = def.Choices[j] break end end
							self:settext(display:upper())
						end,
						OnCommand = function(self) self:playcommand("Refresh") end
					},
					-- Invisible Row Button
					UIElements.QuadButton(1) .. {
						InitCommand = function(self) self:x(-110):zoomto(210, 24):diffusealpha(0) end,
						MouseDownCommand = function(self, params)
							if params.event == "DeviceButton_left mouse button" then
								cyclePref(row.Pref)
								SOUND:PlayOnce(THEME:GetPathS("Common", "value"))
							end
						end
					}
				}
			end
			return r
		end)()
	},

	-- Interactive Toggle Button
	UIElements.QuadButton(1) .. {
		InitCommand = function(self) self:zoomto(100, 30):halign(1):diffusealpha(0) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				MESSAGEMAN:Broadcast("ShowEffectsPopup")
				SOUND:PlayOnce(THEME:GetPathS("Common", "value"))
			end
		end,
		MouseOverCommand = function(self) 
			local txt = self:GetParent():GetChild("BtnText")
			if txt then 
				txt:stoptweening():linear(0.1):diffuse(accentColor)
				if isGlowEnabled then txt:glow(accentColor) end
			end
		end,
		MouseOutCommand = function(self) 
			local txt = self:GetParent():GetChild("BtnText")
			if txt then txt:stoptweening():linear(0.1):diffuse(subText):glow(color("0,0,0,0")) end
		end
	},
	LoadFont("Common Normal") .. {
		Name = "BtnText",
		Text = "EFFECTS",
		InitCommand = function(self) self:halign(1):zoom(0.4):diffuse(subText) end
	}
}

return t
