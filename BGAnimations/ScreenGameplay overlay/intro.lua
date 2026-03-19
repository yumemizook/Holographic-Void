-- this is purely sc-wh. will be changed later.
local bannerWidth = 256
local bannerHeight = 80
local borderWidth = 2
local accentColor = HVColor.Accent or color("#00FF00")

local t = Def.ActorFrame{
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 50)
		self:diffusealpha(0)
	end,
	CurrentSongChangedMessageCommand = function(self)
		self:decelerate(1)
		self:diffusealpha(0.8)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 60)
	end,
	SongStartingMessageCommand = function(self)
		self:stoptweening()
		self:smooth(0.5)
		self:diffusealpha(0)
	end
}

t[#t+1] = Def.Quad{
	InitCommand = function(self)
		self:y(15)
		self:zoomto(bannerWidth + borderWidth * 4, bannerHeight + borderWidth * 4 + 30)
		self:diffuse(color("#000000"))
		self:diffusealpha(0)
	end,
	CurrentSongChangedMessageCommand = function(self)
		if GAMESTATE:GetCurrentSteps() ~= nil then
			self:diffuse(HVColor.GetDifficultyColor(GAMESTATE:GetHardestStepsDifficulty()))
		end
	end
}

t[#t+1] = Def.Quad{
	InitCommand = function(self)
		self:y(15)
		self:zoomto(bannerWidth + borderWidth * 2, bannerHeight + borderWidth * 2 + 30)
		self:diffuse(color("#000000"))
		self:diffusealpha(0.8)
	end
}

t[#t+1] = Def.Sprite {
	CurrentSongChangedMessageCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if song then
			local bnpath = song:GetBannerPath()
			if not bnpath then
				bnpath = THEME:GetPathG("Common", "fallback banner")
			end
			self:LoadBackground(bnpath)
		end
		self:scaletoclipped(bannerWidth, bannerHeight)
	end
}

t[#t+1] = LoadFont("Zpix Normal") .. {
	InitCommand = function(self)
		self:y(50)
		self:zoom(0.6)
		self:diffusealpha(1)
		self:maxwidth(bannerWidth / 0.6)
	end,
	CurrentSongChangedMessageCommand = function(self)
		if GAMESTATE:GetCurrentSong() ~= nil then
			self:settext(GAMESTATE:GetCurrentSong():GetDisplayMainTitle())
		end
	end
}

t[#t+1] = LoadFont("Zpix Normal") .. {
	InitCommand = function(self)
		self:y(65)
		self:zoom(0.4)
		self:diffusealpha(1)
		self:maxwidth(bannerWidth / 0.4)
	end,
	CurrentSongChangedMessageCommand = function(self)
		if GAMESTATE:GetCurrentSong() ~= nil then
			self:settext(GAMESTATE:GetCurrentSong():GetDisplayArtist())
		end
	end
}

return t
