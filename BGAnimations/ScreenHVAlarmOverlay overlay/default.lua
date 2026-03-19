-- Global Alarm Overlay
-- Handles checking current time or decrementing timer
-- Displaying non-intrusive notifications across the theme
-- Needs testing, please do.

local lastMinute = -1
local triggeredThisSession = false
HV.AlarmTimerSeconds = HV.AlarmTimerSeconds or 0
local alarmActive = false

-- Audio/Visual constants
local accentColor = HVColor.Accent
local brightText = color("1,1,1,1")
local subText = color("0.65,0.65,0.65,1")

local function resetAlarm()
	ThemePrefs.Set("HV_AlarmActive", false)
	ThemePrefs.Save()
	MESSAGEMAN:Broadcast("ThemePrefChanged", {Name = "HV_AlarmActive"})
	HV.AlarmTimerSeconds = 0
	HV.AlarmTimerEndTime = 0
	alarmActive = false
	triggeredThisSession = false
end

local t = Def.ActorFrame {
	Name = "AlarmOverlay",
	
	InitCommand = function(self)
		self:SetUpdateFunction(function(af, dt)
			local active = ThemePrefs.Get("HV_AlarmActive")
			if active == "false" or active == false then 
				alarmActive = false
				return 
			end
			
			local alarmType = ThemePrefs.Get("HV_AlarmType")
			if alarmType == "Time" then
				local curHour = Hour()
				local curMin = Minute()
				local target = ThemePrefs.Get("HV_AlarmTime") or "12:00"
				local th, tm = target:match("(%d+):(%d+)")
				th = tonumber(th)
				tm = tonumber(tm)
				
				if th == curHour and tm == curMin then
					if not alarmActive then
						alarmActive = true
						af:playcommand("Trigger")
					end
				else
					alarmActive = false
				end
			
			-- Timer-based Alarm
			elseif alarmType == "Timer" then
				if HV.AlarmTimerEndTime > 0 then
					local now = os.clock()
					local remaining = HV.AlarmTimerEndTime - now
					HV.AlarmTimerSeconds = math.max(0, remaining) -- Sync for UI
					
					if remaining <= 0 then
						HV.AlarmTimerEndTime = 0
						HV.AlarmTimerSeconds = 0
						af:playcommand("Trigger")
					end
				end
			end
		end)
	end,
	
	TriggerCommand = function(self)
		SOUND:PlayOnce(THEME:GetPathS("Common", "value"))
		self:GetChild("VisualAlert"):playcommand("Show")
		
		-- Also show gameplay alert if enabled and in gameplay
		local screen = SCREENMAN:GetTopScreen()
		if screen and screen:GetName() == "ScreenGameplay" then
			if ThemePrefs.Get("HV_AlarmShowInGameplay") then
				self:GetChild("GameplayAlert"):playcommand("Show")
			end
		end
	end,
	
	-- Main Menu / Global Alert
	Def.ActorFrame {
		Name = "VisualAlert",
		InitCommand = function(self) self:xy(SCREEN_CENTER_X, SCREEN_TOP - 100):diffusealpha(0) end,
		ShowCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			-- Don't show the BIG alert in gameplay, only the small one
			if screen and screen:GetName() == "ScreenGameplay" then return end
			
			self:stoptweening():y(SCREEN_TOP - 100):diffusealpha(0)
				:decelerate(0.3):y(SCREEN_TOP + 40):diffusealpha(1)
				:sleep(5):accelerate(0.3):y(SCREEN_TOP - 100):diffusealpha(0)
				:queuecommand("Finish")
		end,
		FinishCommand = function(self)
			resetAlarm()
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				self:stoptweening():accelerate(0.2):y(SCREEN_TOP - 100):diffusealpha(0):queuecommand("Finish")
			end
		end,
		
		Def.Quad {
			InitCommand = function(self) self:zoomto(300, 50):diffuse(color("0.05,0.05,0.05,0.95")):diffuseleftedge(accentColor) end
		},
		LoadFont("Common Large") .. {
			Text = "ALARM TRIGGERED!",
			InitCommand = function(self) self:zoom(0.4):diffuse(brightText):y(-5) end
		},
		LoadFont("Common Normal") .. {
			Text = "Click to dismiss",
			InitCommand = function(self) self:zoom(0.3):diffuse(subText):y(12) end
		},
		UIElements.QuadButton(1) .. {
			InitCommand = function(self) self:zoomto(300, 50):diffusealpha(0) end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then
					self:GetParent():stoptweening():accelerate(0.2):y(SCREEN_TOP - 100):diffusealpha(0):queuecommand("Finish")
				end
			end
		}
	},
	
	-- Non-Intrusive Gameplay Alert
	Def.ActorFrame {
		Name = "GameplayAlert",
		InitCommand = function(self) self:xy(SCREEN_RIGHT - 40, SCREEN_TOP + 40):diffusealpha(0) end,
		ShowCommand = function(self)
			self:stoptweening():diffusealpha(0):zoom(0.5)
				:linear(0.2):diffusealpha(1):zoom(1)
				:glow(accentColor):sleep(0.5):glow(color("0,0,0,0")):sleep(0.5)
				:glow(accentColor):sleep(0.5):glow(color("0,0,0,0")):sleep(0.5)
				:glow(accentColor):sleep(0.5):glow(color("0,0,0,0")):sleep(0.5)
				:linear(0.5):diffusealpha(0)
				:queuecommand("Finish")
		end,
		FinishCommand = function(self)
			resetAlarm()
		end,
		
		-- Mini Icon / Text
		Def.ActorFrame {
			Def.Quad { InitCommand = function(self) self:zoomto(60, 30):diffuse(color("0,0,0,0.6")):diffusebottomedge(accentColor) end },
			LoadFont("Common Normal") .. {
				Text = "ALARM",
				InitCommand = function(self) self:zoom(0.4):diffuse(accentColor) end
			}
		}
	}
}

return t
