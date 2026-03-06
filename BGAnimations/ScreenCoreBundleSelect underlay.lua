-- Holographic Void: ScreenCoreBundleSelect underlay
-- Ported from Til Death, styled for Holographic Void

local minidoots = {"Beginner", "Novice", "Intermediate", "Advanced", "Expert"}
local diffcolors = {"#66ccff", "#099948", "#ddaa00", "#ff6666", "#c97bff"}
local bundleDesc = {
	"For players completely new to rhythm games (1-5 MSD)",
	"For players with some experience (5-10 MSD)",
	"For experienced players (10-15 MSD)",
	"For very experienced players (15-20 MSD)",
	"For top tier players (20+ MSD)"
}
local packspacing = 54
local ind = 3
local accentColor = HVColor.Accent

local translated_info = {
	Alert = THEME:GetString("ScreenCoreBundleSelect", "Alert"),
	Task = THEME:GetString("ScreenCoreBundleSelect", "Task"),
	Explanation = THEME:GetString("ScreenCoreBundleSelect", "Explanation"),
	RefreshSongs = THEME:GetString("GeneralInfo", "DifferentialReloadTrigger")
}

local o = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH / 2, 50):halign(0.5)
	end,
	BeginCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_FirstPress" then
				if event.button == "MenuUp" or event.button == "Up" then
					ind = ind - 1
					if ind < 1 or ind > 5 then
						ind = 5
					end
					self:queuecommand("SelectionChanged")
					return true
				elseif event.button == "MenuDown" or event.button == "Down" then
					ind = ind + 1
					if ind > 5 then
						ind = 1
					end
					self:queuecommand("SelectionChanged")
					return true
				elseif event.button == "Start" or event.DeviceInput.button == "DeviceButton_enter" then
					if ind < 6 and ind > 0 then
						DLMAN:DownloadCoreBundle(minidoots[ind]:lower())
						SCREENMAN:SystemMessage("Downloading " .. minidoots[ind] .. " bundle...")
					end
					return true
				elseif event.DeviceInput.button == "DeviceButton_escape" or event.button == "Back" then
					SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToPrevScreen")
					return true
				end
			end
			return false
		end)
	end,
	-- Background Quad
	Def.Quad {
		InitCommand = function(self)
			self:xy(0, SCREEN_CENTER_Y - 50):zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("0.05,0.05,0.05,0.9")):strokeColor(color("0.18,0.18,0.18,1")):strokeWidth(1)
		end
	},
	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:zoom(0.5):diffuse(accentColor)
		end,
		OnCommand = function(self)
			self:settext(translated_info["Alert"])
		end
	},
	LoadFont("Common normal") .. {
		InitCommand = function(self)
			self:y(24):zoom(0.5):diffuse(color("0.85,0.85,0.85,1"))
		end,
		OnCommand = function(self)
			self:settext(translated_info["Task"])
		end
	},
	LoadFont("Common normal") .. {
		InitCommand = function(self)
			self:y(330):zoom(0.4):diffuse(color("0.65,0.65,0.65,1"))
		end,
		OnCommand = function(self)
			self:settext(translated_info["Explanation"])
		end
	},
	LoadFont("Common normal") .. {
		InitCommand = function(self)
			self:y(360):zoom(0.4):diffuse(color("0.85,0.85,0.85,1"))
		end,
		OnCommand = function(self)
			self:queuecommand("SelectionChanged")
		end,
		SelectionChangedCommand = function(self)
			self:settext(bundleDesc[ind])
		end
	},
	LoadFont("Common normal") .. {
		InitCommand = function(self)
			self:y(380):zoom(0.35):diffuse(color("0.5,0.5,0.5,1"))
		end,
		OnCommand = function(self)
			self:settext("Press ENTER to download  ·  Press ESC to exit")
		end
	}
}

local function makedoots(i)
	local t = Def.ActorFrame {
		InitCommand = function(self)
			self:y(packspacing * i)
		end,
		UIElements.QuadButton(1, 1) .. {
			Name = "Doot",
			InitCommand = function(self)
				self:y(-12):zoomto(400, 48):valign(0):diffuse(color(diffcolors[i]))
			end,
			OnCommand = function(self)
				self:queuecommand("SelectionChanged")
			end,
			SelectionChangedCommand = function(self)
				if i == ind then
					self:diffusealpha(1):zoomto(410, 52)
				else
					self:diffusealpha(0.5):zoomto(400, 48)
				end
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and ind == i then
					DLMAN:DownloadCoreBundle(minidoots[i]:lower())
					SCREENMAN:SystemMessage("Downloading " .. minidoots[i] .. " bundle...")
				elseif params.event == "DeviceButton_right mouse button" then
					SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToPrevScreen")
				elseif isOver(self) then
					ind = i
					self:GetParent():GetParent():playcommand("SelectionChanged")
				end
			end,
			MouseOverCommand = function(self)
				if ind ~= i then
					self:diffusealpha(0.75)
				end
			end,
			MouseOutCommand = function(self)
				if ind ~= i then
					self:diffusealpha(0.5)
				end
			end,
		},
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:zoom(0.5)
			end,
			OnCommand = function(self)
				self:settext(minidoots[i])
			end
		},
		LoadFont("Common normal") .. {
			InitCommand = function(self)
				self:y(24):zoom(0.5)
			end,
			OnCommand = function(self)
				local bundle = DLMAN:GetCoreBundle(minidoots[i]:lower())
				if bundle then
					self:settextf("(%dMB)", bundle["TotalSize"])
				else
					self:settext("(--MB)")
				end
			end
		}
	}
	return t
end

o[#o + 1] = Def.ActorFrame {
    UIElements.TextToolTip(1, 1, "Common Normal") .. {
		Name = "refreshbutton",
		InitCommand = function(self)
			self:xy(0, 410):zoom(0.5):diffuse(accentColor)
		end,
		BeginCommand = function(self)
			self:queuecommand("Set")
		end,
		SetCommand = function(self)
			self:settextf(translated_info["RefreshSongs"])
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(0.6)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				SONGMAN:DifferentialReload()
                SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
			end
		end
	}
}

for i = 1, #minidoots do
	o[#o + 1] = makedoots(i)
end

return o
