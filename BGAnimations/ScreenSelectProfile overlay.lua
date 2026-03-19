-- Holographic Void: Custom ScreenSelectProfile
-- Displays available local profiles as sleek dark-themed cards.

local accentColor = HVColor.Accent
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local brightText = color("1,1,1,1")

local cardW = 320
local cardH = 100
local cardSpacing = 20

local numProfiles = PROFILEMAN:GetNumLocalProfiles()
if numProfiles == 0 then
	-- No profiles? Engine shouldn't bring us here, but just in case:
	return Def.ActorFrame {
		OnCommand = function() SCREENMAN:GetTopScreen():Finish() end
	}
end

-- Center the list of cards
local totalWidth = (numProfiles * cardW) + ((numProfiles - 1) * cardSpacing)
local startX = SCREEN_CENTER_X - totalWidth / 2 + cardW / 2

local t = Def.ActorFrame {
	InitCommand = function(self)
		self:diffusealpha(0)
	end,
	OnCommand = function(self)
		self:linear(0.2):diffusealpha(1)
	end,
	OffCommand = function(self)
		self:linear(0.2):diffusealpha(0)
	end,
	
	-- Dark background overlay
	Def.Quad {
		InitCommand = function(self)
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			self:diffuse(color("0,0,0,0.8"))
		end
	},
	
	-- Title
	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - cardH - 40)
			self:zoom(0.6):diffuse(brightText)
			self:settext(THEME:GetString("ScreenSelectProfile", "Title"))
			self:shadowlength(1)
		end
	}
}

local cards = Def.ActorFrame { Name = "Cards" }

for i = 0, numProfiles - 1 do
	local profile = PROFILEMAN:GetLocalProfileFromIndex(i)
	local profileID = PROFILEMAN:GetLocalProfileIDFromIndex(i)
	local cx = startX + i * (cardW + cardSpacing)
	local cy = SCREEN_CENTER_Y
	
	local card = Def.ActorFrame {
		Name = "Card_" .. i,
		InitCommand = function(self)
			self:xy(cx, cy)
		end,
		
		-- Background
		Def.Quad {
			Name = "Bg",
			InitCommand = function(self)
				self:zoomto(cardW, cardH)
				self:diffuse(color("0.08,0.08,0.08,0.95"))
				self:fadeleft(0.1):faderight(0.1)
			end
		},
		-- Border / Glow (invisible by default, shown on hover/select)
		Def.Quad {
			Name = "Glow",
			InitCommand = function(self)
				self:zoomto(cardW + 4, cardH + 4)
				self:diffuse(accentColor):diffusealpha(0)
			end
		},
		
		-- Avatar
		Def.Sprite {
			Name = "Avatar",
			InitCommand = function(self)
				self:xy(-cardW/2 + 50, 0):zoomto(80, 80)
				local path = getAssetPathFromProfileID("avatar", profileID)
				if path then
					self:Load(path)
					self:scaletoclipped(80, 80)
				end
			end
		},
		
		-- Name
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(-cardW/2 + 105, -15):halign(0):zoom(0.5):diffuse(brightText)
				self:settext(profile:GetDisplayName() or THEME:GetString("ScreenSelectProfile", "Unknown"))
				self:maxwidth((cardW - 120) / 0.5)
			end
		},
		
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-cardW/2 + 105, 12):halign(0):zoom(0.4)
				if not HV.ShowMSD() then
					self:visible(false)
					return
				end
				local r = profile:GetPlayerRating()
				self:settextf(THEME:GetString("ScreenSelectProfile", "RatingFormatted"), r)
				self:diffuse(HVColor.GetMSDRatingColor(r))
			end
		},
		
		-- Songs Played
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(-cardW/2 + 105, 28):halign(0):zoom(0.35):diffuse(subText)
				self:settextf(THEME:GetString("ScreenSelectProfile", "SongsPlayedFormatted"), profile:GetNumTotalSongsPlayed())
			end
		}
	}
	cards[#cards + 1] = card
end

t[#t + 1] = cards

-- Input Handling
t[#t + 1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		self.selection = 0 -- currently highlighted index
		
		local function updateHighlight()
			local cFrame = self:GetParent():GetChild("Cards")
			if cFrame then
				for i = 0, numProfiles - 1 do
					local c = cFrame:GetChild("Card_" .. i)
					if c then
						local glow = c:GetChild("Glow")
						local bg = c:GetChild("Bg")
						if i == self.selection then
							glow:stoptweening():linear(0.1):diffusealpha(0.8)
							bg:stoptweening():linear(0.1):diffuse(color("0.12,0.12,0.12,0.95"))
						else
							glow:stoptweening():linear(0.1):diffusealpha(0)
							bg:stoptweening():linear(0.1):diffuse(color("0.08,0.08,0.08,0.95"))
						end
					end
				end
			end
		end

		updateHighlight()

		-- Mouse movement tracking
		self:SetUpdateFunction(function(af)
			local virtualX = INPUTFILTER:GetMouseX()
			local virtualY = INPUTFILTER:GetMouseY()
			
			for i = 0, numProfiles - 1 do
				local cx = startX + i * (cardW + cardSpacing)
				local cy = SCREEN_CENTER_Y
				if virtualX >= cx - cardW/2 and virtualX <= cx + cardW/2
				   and virtualY >= cy - cardH/2 and virtualY <= cy + cardH/2 then
					if self.selection ~= i then
						self.selection = i
						updateHighlight()
						SOUND:PlayOnce(THEME:GetPathS("Common", "value"))
					end
					break
				end
			end
		end)

		screen:AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end
			local btn = event.DeviceInput.button or ""
			
			if event.button == "MenuLeft" or event.button == "Left" then
				self.selection = (self.selection - 1) % numProfiles
				updateHighlight()
				SOUND:PlayOnce(THEME:GetPathS("Common", "value"))
				return true
			elseif event.button == "MenuRight" or event.button == "Right" then
				self.selection = (self.selection + 1) % numProfiles
				updateHighlight()
				SOUND:PlayOnce(THEME:GetPathS("Common", "value"))
				return true
			elseif event.button == "Start" or event.button == "Center" or btn == "DeviceButton_enter" then
				SOUND:PlayOnce(THEME:GetPathS("Common", "start"))
				SCREENMAN:GetTopScreen():SetProfileIndex(PLAYER_1, self.selection + 1)
				if HV and HV.TitleState then HV.TitleState.selectedProfile = self.selection end
				SCREENMAN:GetTopScreen():Finish()
				return true
			elseif btn == "DeviceButton_left mouse button" then
				local virtualX = INPUTFILTER:GetMouseX()
				local virtualY = INPUTFILTER:GetMouseY()
				local cx = startX + self.selection * (cardW + cardSpacing)
				local cy = SCREEN_CENTER_Y
				if virtualX >= cx - cardW/2 and virtualX <= cx + cardW/2
				   and virtualY >= cy - cardH/2 and virtualY <= cy + cardH/2 then
					SOUND:PlayOnce(THEME:GetPathS("Common", "start"))
					SCREENMAN:GetTopScreen():SetProfileIndex(PLAYER_1, self.selection + 1)
					if HV and HV.TitleState then HV.TitleState.selectedProfile = self.selection end
					SCREENMAN:GetTopScreen():Finish()
					return true
				end
			elseif event.button == "Back" then
				SOUND:PlayOnce(THEME:GetPathS("Common", "cancel"))
				SCREENMAN:GetTopScreen():Cancel()
				return true
			end
			return false
		end)
	end
}


-- Sounds
t[#t+1] = LoadActor(THEME:GetPathS("Common", "value")) .. { Name="HoverSound" }
t[#t+1] = LoadActor(THEME:GetPathS("Common", "start")) .. { Name="StartSound" }
t[#t+1] = LoadActor(THEME:GetPathS("Common", "cancel")) .. { Name="CancelSound" }

return t
