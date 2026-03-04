-- Holographic Void: Avatar / Profile Display (adapted from Fatigue)
-- Shows player avatar, name, MSD, difficulty, mods, judge/scoring info,
-- life bar, and real-time DP / Wife% during gameplay.

local pn = GAMESTATE:GetEnabledPlayers()[1]
local profile = GetPlayerOrMachineProfile(pn)
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats()

local avatarSize = 56
local panelX = 10
local panelY = SCREEN_HEIGHT - 66
local panelW = 240
local panelH = 60

-- HV accent color
local accentColor = HVColor.Accent or color("#00CFFF")
local dimText = color("0.5,0.5,0.5,1")
local fontZoom = 0.55
local fontZoomSmall = 0.45

-- Life helper
local function PLife()
	local life = STATSMAN:GetCurStageStats():GetPlayerStageStats():GetCurrentLife() or 0
	return math.max(0, life)
end

-- DP tracking
local actual_dp = 0
local total_max = 0

local t = Def.ActorFrame {
	Name = "AvatarDisplay",
	InitCommand = function(self)
		self:xy(panelX, panelY)
		actual_dp = 0
		total_max = 0
		local steps = GAMESTATE:GetCurrentSteps()
		if steps then
			total_max = steps:GetRadarValues(PLAYER_1):GetValue("RadarCategory_Notes") * 2
		end
	end,

	-- Panel background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
			self:zoomto(panelW, panelH)
			self:diffuse(0.03, 0.03, 0.03, 0.8)
		end,
	},

	-- Avatar border accent
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0)
			self:xy(-2, -2)
			self:zoomto(avatarSize + 4, avatarSize + 4)
			self:diffuse(accentColor)
			self:diffusealpha(0.5)
		end,
	},

	-- Avatar sprite
	Def.Sprite {
		InitCommand = function(self)
			self:halign(0):valign(0)
		end,
		BeginCommand = function(self)
			self:finishtweening()
			self:Load(getAvatarPath(PLAYER_1))
			self:zoomto(avatarSize, avatarSize)
		end
	},

	-- Profile name
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			local name = profile:GetDisplayName()
			self:xy(avatarSize + 6, 5):zoom(fontZoom):halign(0):maxwidth(130 / fontZoom)
			self:settext(name)
			self:diffuse(color("1,1,1,1"))
		end
	},

	-- MSD value
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(avatarSize + 8, 22):zoom(fontZoom * 1.1):halign(0):maxwidth(65 / fontZoom)
		end,
		BeginCommand = function(self) self:queuecommand("Set") end,
		SetCommand = function(self)
			local steps = GAMESTATE:GetCurrentSteps()
			local meter = steps:GetMSD(getCurRateValue(), 1)
			meter = meter == 0 and steps:GetMeter() or meter
			self:settextf("%5.2f", meter)
			self:diffuse(HVColor.GetMSDRatingColor(meter))
		end,
		CurrentRateChangedMessageCommand = function(self) self:queuecommand("Set") end,
		PracticeModeReloadMessageCommand = function(self) self:queuecommand("Set") end,
	},

	-- Difficulty name
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(avatarSize + 60, 22):zoom(fontZoomSmall):halign(0):maxwidth(150 / fontZoomSmall)
		end,
		BeginCommand = function(self) self:queuecommand("Set") end,
		SetCommand = function(self)
			local steps = GAMESTATE:GetCurrentSteps()
			local diff = ToEnumShortString(steps:GetDifficulty())
			self:settext(getDifficulty(steps:GetDifficulty()))
			self:diffuse(HVColor.GetDifficultyColor(diff))
		end,
	},

	-- Mods string
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(avatarSize + 8, 38):halign(0):zoom(fontZoomSmall * 0.9):maxwidth(panelW * 0.75 / (fontZoomSmall * 0.9))
			self:diffuse(dimText)
		end,
		BeginCommand = function(self)
			self:settext(getModifierTranslations(GAMESTATE:GetPlayerState():GetPlayerOptionsString("ModsLevel_Current")))
		end
	},

	-- Judge info
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(avatarSize + 8, 52):halign(0):zoom(fontZoomSmall * 0.9)
			self:diffuse(dimText)
		end,
		BeginCommand = function(self)
			self:settextf("J%d", GetTimingDifficulty())
		end
	},

	-- Life bar background
	Def.Quad {
		InitCommand = function(self)
			self:halign(0)
			self:xy(avatarSize + 40, 52)
			self:zoomto(panelW - avatarSize - 44, 6)
			self:diffuse(0.15, 0.15, 0.15, 1)
		end
	},

	-- Life bar fill
	Def.Quad {
		InitCommand = function(self)
			self:halign(0)
			self:xy(avatarSize + 40, 52)
			self:zoomto(0, 6)
			self:diffuse(accentColor)
			self:queuecommand("Set")
		end,
		JudgmentMessageCommand = function(self, params)
			self:playcommand("Set", params)
		end,
		SetCommand = function(self, params)
			if params ~= nil and params.TapNoteScore == "TapNoteScore_AvoidMine" then
				return
			end
			self:finishtweening()
			self:smooth(0.1)
			local barMaxW = panelW - avatarSize - 44
			self:zoomx(PLife() * barMaxW)
			-- Color shift for low life
			local life = PLife()
			if life < 0.3 and life > 0 then
				self:diffuse(color("#FF4444"))
			elseif life <= 0 then
				self:diffuse(color("#440000"))
			else
				self:diffuse(accentColor)
			end
		end
	},

	-- Fatigue DP & Incremental Wife% Tracker
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(avatarSize + 4, -12):halign(0):zoom(0.45)
			self:settext("0.00 DP (0.00%)")
			self:diffuse(color("#b3b3b3"))
		end,
		JudgmentMessageCommand = function(self, msg)
			self:stoptweening()
			
			if msg.TapNoteScore and msg.TapNoteScore ~= "TapNoteScore_AvoidMine" and msg.TapNoteScore ~= "TapNoteScore_CheckpointHit" then
				if msg.TapNoteOffset then
					local ts = ms.JudgeScalers[PREFSMAN:GetPreference("TimingWindowScale")]
					actual_dp = actual_dp + wife3(math.abs(msg.TapNoteOffset) * 1000, ts, "Wife3")
				elseif msg.TapNoteScore == "TapNoteScore_Miss" then
					actual_dp = actual_dp - 5.5
				elseif msg.TapNoteScore == "TapNoteScore_HitMine" then
					actual_dp = actual_dp - 7.0
				end
			elseif msg.HoldNoteScore == "HoldNoteScore_MissedHold" then
				actual_dp = actual_dp - 4.5
			end
			
			local current_perc = pss:GetWifeScore() * 100
			if total_max > 0 then
				current_perc = math.max(0, (actual_dp / total_max) * 100)
			end
			
			self:settextf("%.2f DP (%.2f%%)", actual_dp, current_perc)
		end
	},
}

return t
