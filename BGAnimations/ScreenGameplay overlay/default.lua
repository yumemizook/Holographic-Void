--- Holographic Void: ScreenGameplay Overlay
-- Full HUD overlay with:
--   - Vertical life bar (right edge)
--   - Player avatar + score (bottom-left)
--   - Judgment tally (right of notefield)
--   - Combo display (center, number + label)
--   - Song progress bar
--   - Proper judgment rendering
--   - Toasty animation

local t = Def.ActorFrame {
	Name = "GameplayOverlay"
}

local accentColor = color("#5ABAFF")
local dimText = color("0.45,0.45,0.45,1")
local subText = color("0.65,0.65,0.65,1")
local mainText = color("0.85,0.85,0.85,1")
local brightText = color("1,1,1,1")

local judgmentColors = {
	color("#FFFFFF"), color("#E0E0A0"), color("#A0E0A0"),
	color("#A0C8E0"), color("#C8A0E0"), color("#E0A0A0")
}
local judgmentLabels = {"Marvelous", "Perfect", "Great", "Good", "Bad", "Miss"}
local judgmentTNS = {
	"TapNoteScore_W1", "TapNoteScore_W2", "TapNoteScore_W3",
	"TapNoteScore_W4", "TapNoteScore_W5", "TapNoteScore_Miss"
}

-- ============================================================
-- FRAME UPDATER (drives all per-frame HUD updates)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(function(s)
			s:GetParent():playcommand("Update")
		end)
		self:SetUpdateRate(1 / 30) -- 30fps update for HUD
	end
}

-- ============================================================
-- VERTICAL LIFE BAR (right edge of screen)
-- ============================================================
local lifeBarW = 8
local lifeBarH = SCREEN_HEIGHT * 0.6
local lifeBarX = SCREEN_RIGHT - 16
local lifeBarY = SCREEN_CENTER_Y

t[#t + 1] = Def.ActorFrame {
	Name = "VerticalLifeBar",
	InitCommand = function(self)
		self:xy(lifeBarX, lifeBarY)
	end,

	-- Track background
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(lifeBarW, lifeBarH)
				:diffuse(color("0.1,0.1,0.1,0.8"))
		end
	},

	-- Life fill (grows from bottom)
	Def.Quad {
		Name = "LifeFill",
		InitCommand = function(self)
			self:valign(1):y(lifeBarH / 2)
				:zoomto(lifeBarW, 0)
				:diffuse(accentColor):diffusealpha(0.8)
		end,
		UpdateCommand = function(self)
			local life = GAMESTATE:GetPlayerState():GetHealthState()
			-- life is an enum; we need the actual life value
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local lifeVal = pss:GetCurrentLife()
				if lifeVal then
					local fillH = lifeBarH * lifeVal
					self:zoomto(lifeBarW, fillH)
					-- Color shift: green when healthy, red when low
					if lifeVal > 0.5 then
						self:diffuse(accentColor):diffusealpha(0.8)
					elseif lifeVal > 0.25 then
						self:diffuse(color("#FFD060")):diffusealpha(0.8)
					else
						self:diffuse(color("#FF5050")):diffusealpha(0.9)
					end
				end
			end
		end
	},

	-- Border
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(lifeBarW + 2, lifeBarH + 2)
				:diffuse(color("0.2,0.2,0.2,0.5"))
				:blend("BlendMode_Add")
		end
	}
}

-- ============================================================
-- PLAYER AVATAR + SCORE (bottom-left)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "PlayerHUD",
	InitCommand = function(self)
		self:xy(12, SCREEN_BOTTOM - 50)
	end,
	OnCommand = function(self)
		self:diffusealpha(0.85)
	end,

	-- Avatar
	Def.Sprite {
		Name = "GameplayAvatar",
		InitCommand = function(self)
			self:halign(0):valign(1)
		end,
		BeginCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local avatarPath = nil
				if profile.GetAvatarPath then
					avatarPath = profile:GetAvatarPath()
				end
				if avatarPath and avatarPath ~= "" and FILEMAN:DoesFileExist(avatarPath) then
					self:Load(avatarPath)
				else
					local fallback = "/Assets/Avatars/_fallback.png"
					if FILEMAN:DoesFileExist(fallback) then
						self:Load(fallback)
					end
				end
				self:scaletoclipped(36, 36)
				self:visible(true)
			else
				self:visible(false)
			end
		end
	},

	-- Player name
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(1):x(42):y(-20):zoom(0.32):diffuse(subText)
		end,
		BeginCommand = function(self)
			local profile = PROFILEMAN:GetProfile(PLAYER_1)
			if profile then
				local name = profile:GetDisplayName()
				if name == "" then name = "Player" end
				self:settext(name)
			end
		end
	},

	-- Wife Score (live-updating)
	LoadFont("Common Normal") .. {
		Name = "LiveScore",
		InitCommand = function(self)
			self:halign(0):valign(1):x(42):y(-2):zoom(0.55):diffuse(brightText)
		end,
		UpdateCommand = function(self)
			local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
			if pss then
				local wifePct = pss:GetWifeScore() * 100
				if wifePct >= 99 then
					self:settext(string.format("%.4f%%", wifePct))
				else
					self:settext(string.format("%.2f%%", wifePct))
				end
			end
		end
	}
}

-- ============================================================
-- COMBO DISPLAY (center of screen, below notefield)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "ComboDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + SCREEN_HEIGHT * 0.28)
		self:visible(false)
	end,

	-- Combo number
	LoadFont("Common Large") .. {
		Name = "ComboNumber",
		InitCommand = function(self)
			self:zoom(0.7):diffuse(brightText):y(-6)
		end
	},

	-- Combo label
	LoadFont("Common Normal") .. {
		Name = "ComboLabel",
		InitCommand = function(self)
			self:zoom(0.28):diffuse(subText):y(16)
			self:settext("COMBO")
		end
	},

	UpdateCommand = function(self)
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if pss then
			local combo = pss:GetCurrentCombo()
			if combo and combo > 0 then
				self:visible(true)
				self:GetChild("ComboNumber"):settext(tostring(combo))
			else
				self:visible(false)
			end
		end
	end
}

-- ============================================================
-- JUDGMENT TALLY (right of notefield)
-- ============================================================
local tallyX = SCREEN_CENTER_X + SCREEN_WIDTH * 0.22
local tallyY = SCREEN_CENTER_Y - 70

t[#t + 1] = Def.ActorFrame {
	Name = "JudgmentTally",
	InitCommand = function(self)
		self:xy(tallyX, tallyY)
	end,
	OnCommand = function(self)
		self:diffusealpha(0.75)
	end
}

for i, label in ipairs(judgmentLabels) do
	t[#t + 1] = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(tallyX, tallyY + (i - 1) * 20)
		end,

		-- Label
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:halign(0):valign(0):zoom(0.26):diffuse(judgmentColors[i]):diffusealpha(0.75)
				self:settext(label)
			end
		},

		-- Count
		LoadFont("Common Normal") .. {
			Name = "TallyCount_" .. label,
			InitCommand = function(self)
				self:halign(1):valign(0):x(120):zoom(0.3):diffuse(mainText):diffusealpha(0.75)
			end,
			UpdateCommand = function(self)
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
				if pss then
					self:settext(pss:GetTapNoteScores(judgmentTNS[i]))
				end
			end
		}
	}
end

-- ============================================================
-- JUDGMENT SPRITE (proper rendering for hit judgments)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "JudgmentDisplay",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + 40)
	end,

	Def.Sprite {
		Name = "JudgmentSprite",
		InitCommand = function(self)
			-- Try to load from Assets/Judgments
			local judgPath = "/Assets/Judgments/default 1x6 (Doubleres).png"
			if FILEMAN:DoesFileExist(judgPath) then
				self:Load(judgPath)
				self:SetAllStateDelays(9999) -- don't auto-animate
				self:animate(false)
				self:pause()
				self:visible(false)
			else
				-- Fallback to normal judgment
				local fallbackPath = "/Themes/_fallback/Graphics/Judgment Normal 1x6.png"
				if FILEMAN:DoesFileExist(fallbackPath) then
					self:Load(fallbackPath)
					self:SetAllStateDelays(9999)
					self:animate(false)
					self:pause()
				end
				self:visible(false)
			end
		end,
		JudgmentMessageCommand = function(self, params)
			if params and params.TapNoteScore then
				local tns = params.TapNoteScore
				local stateMap = {
					["TapNoteScore_W1"] = 0,
					["TapNoteScore_W2"] = 1,
					["TapNoteScore_W3"] = 2,
					["TapNoteScore_W4"] = 3,
					["TapNoteScore_W5"] = 4,
					["TapNoteScore_Miss"] = 5
				}
				local frame = stateMap[tns]
				if frame then
					self:visible(true)
					self:setstate(frame)
					self:stoptweening()
					self:diffusealpha(1):zoom(0.5)
					self:decelerate(0.05):zoom(0.45)
					self:sleep(0.6):linear(0.2):diffusealpha(0)
				end
			end
		end
	}
}

-- ============================================================
-- SONG PROGRESS BAR (bottom of screen)
-- ============================================================
local barW = SCREEN_WIDTH * 0.35
local barH = 3
local barY = SCREEN_BOTTOM - 8

t[#t + 1] = Def.ActorFrame {
	Name = "ProgressBar",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, barY)
	end,

	-- Track background
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(barW, barH):diffuse(color("0.15,0.15,0.15,1"))
		end
	},

	-- Progress fill
	Def.Quad {
		Name = "ProgressFill",
		InitCommand = function(self)
			self:halign(0):x(-barW / 2)
				:zoomto(0, barH):diffuse(accentColor):diffusealpha(0.7)
		end,
		UpdateCommand = function(self)
			local songPos = GAMESTATE:GetSongPercent()
			if songPos then
				self:zoomto(barW * songPos, barH)
			end
		end
	},

	-- Time remaining text
	LoadFont("Common Normal") .. {
		Name = "TimeRemaining",
		InitCommand = function(self)
			self:x(barW / 2 + 8):zoom(0.3):halign(0):diffuse(dimText)
		end,
		UpdateCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local songLen = song:MusicLengthSeconds()
				local curTime = GAMESTATE:GetSongPosition():GetMusicSeconds()
				local remaining = math.max(0, songLen - curTime)
				local mins = math.floor(remaining / 60)
				local secs = math.floor(remaining % 60)
				self:settext(string.format("-%d:%02d", mins, secs))
			end
		end
	}
}

-- ============================================================
-- SONG INFO (top-left corner, minimal)
-- ============================================================
t[#t + 1] = Def.ActorFrame {
	Name = "SongInfoHUD",
	InitCommand = function(self)
		self:xy(10, 10)
	end,
	OnCommand = function(self)
		self:diffusealpha(0.6)
	end,

	-- Song title
	LoadFont("Zpix Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.35):diffuse(mainText)
		end,
		BeginCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:settext(song:GetDisplayMainTitle())
			end
		end
	},

	-- Difficulty / MSD
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):y(16):zoom(0.3):diffuse(subText)
		end,
		BeginCommand = function(self)
			local steps = GAMESTATE:GetCurrentSteps()
			if steps then
				local diff = steps:GetDifficulty()
				local msd = steps:GetMSD(getCurRateValue(), 1)
				local diffStr = ToEnumShortString(diff)
				if msd and msd > 0 then
					self:settext(diffStr .. " · " .. string.format("%.2f", msd))
				else
					self:settext(diffStr)
				end
			end
		end
	},

	-- Rate display
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):valign(0):y(30):zoom(0.25):diffuse(dimText)
		end,
		BeginCommand = function(self)
			local rate = getCurRateString()
			if rate and rate ~= "1x" and rate ~= "1.0x" then
				self:settext(rate)
			else
				self:settext("")
			end
		end
	}
}

-- ============================================================
-- TOASTY (fires at combo 250, 500, 750, 1000, ...)
-- ============================================================
local lastToastyCombo = 0

t[#t + 1] = Def.ActorFrame {
	Name = "Toasty",
	InitCommand = function(self)
		lastToastyCombo = 0
	end,

	-- Toasty image
	Def.Sprite {
		Name = "ToastySprite",
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH + 100, SCREEN_CENTER_Y)
			-- Try loading the toasty image asset
			local toastyImg = getToastyAssetPath("image")
			if toastyImg and FILEMAN:DoesFileExist(toastyImg) then
				self:Load(toastyImg)
			end
			self:diffusealpha(0)
		end,
		StartTransitioningCommand = function(self)
			self:stoptweening()
			self:diffusealpha(1)
			self:decelerate(0.25):x(SCREEN_WIDTH - 100)
			self:sleep(1.75)
			self:accelerate(0.5):x(SCREEN_WIDTH + 100)
			self:linear(0):diffusealpha(0)
		end
	},

	-- Toasty sound
	Def.Sound {
		Name = "ToastySound",
		InitCommand = function(self)
			local toastySnd = getToastyAssetPath("sound")
			if toastySnd and FILEMAN:DoesFileExist(toastySnd) then
				self:load(toastySnd)
			end
		end,
		StartTransitioningCommand = function(self)
			self:play()
		end
	},

	-- Check combo each update
	UpdateCommand = function(self)
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()
		if pss then
			local combo = pss:GetCurrentCombo()
			if combo and combo >= 250 then
				-- Fire at 250, 500, 750, ...
				local milestone = math.floor(combo / 250)
				local lastMilestone = math.floor(lastToastyCombo / 250)
				if milestone > lastMilestone then
					self:playcommand("StartTransitioning")
				end
			end
			if combo then
				lastToastyCombo = combo
			end
		end
	end
}

return t
