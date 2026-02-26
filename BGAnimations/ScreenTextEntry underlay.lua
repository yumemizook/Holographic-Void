--- Holographic Void: ScreenTextEntry Underlay
-- Provides the themed background and "Censor" toggle for native prompts.

local accentColor = color("#5ABAFF")
local bgCard = color("0.06,0.06,0.06,0.95")
local dimText = color("0.45,0.45,0.45,1")
local brightText = color("1,1,1,1")

local boxWidth = SCREEN_WIDTH / 2.5
local boxHeight = SCREEN_HEIGHT / 3

return Def.ActorFrame {
	Name = "TextEntryUnderlay",
	InitCommand = function(self) self:diffusealpha(0) end,
	OffCommand = function(self) self:stoptweening():smooth(0.1):diffusealpha(0) end,
	OnCommand = function(self)
		self:smooth(0.1):diffusealpha(1)
		
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		-- Capture right-click to cancel (like Til Death)
		screen:AddInputCallback(function(event)
			if event.DeviceInput.button == "DeviceButton_right mouse button" then
				SCREENMAN:GetTopScreen():End(true) -- true = cancelled
			end
		end)

		-- Limit widths and ensure visibility of native elements
		local question = self:GetParent():GetChild("Question")
		local answer = self:GetParent():GetChild("Answer")
		if question then 
			question:maxwidth(boxWidth - 40):diffusealpha(1):DrawOrder(100)
		end
		if answer then 
			answer:maxwidth(boxWidth - 40):diffusealpha(1):DrawOrder(100)
		end
	end,

	-- Dim background
	Def.Quad {
		InitCommand = function(self) self:FullScreen():diffuse(color("0,0,0,0.8")) end
	},

	-- Dialog Box
	Def.ActorFrame {
		InitCommand = function(self) self:Center() end,

		-- Main Background
		Def.Quad {
			InitCommand = function(self) self:zoomto(boxWidth, boxHeight):diffuse(bgCard) end
		},
		-- Accent Borders
		Def.Quad {
			InitCommand = function(self) self:zoomto(boxWidth, 1):y(-boxHeight/2):diffuse(accentColor) end
		},
		Def.Quad {
			InitCommand = function(self) self:zoomto(boxWidth, 1):y(boxHeight/2):diffuse(accentColor):diffusealpha(0.3) end
		},

		-- Censor / Unhide Button
		Def.ActorFrame {
			Name = "UnhideButton",
			InitCommand = function(self)
				self:xy(-boxWidth/2 + 60, boxHeight/2 - 25)
				self.isHeld = false
			end,
			BeginCommand = function(self)
				local screen = SCREENMAN:GetTopScreen()
				if screen and not screen:IsInputHidden() then self:visible(false) end
				
				-- Handle manual mouse detection for the toggle
				screen:AddInputCallback(function(event)
					if event.DeviceInput.button ~= "DeviceButton_left mouse button" then return end
					
					local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
					local ax, ay = self:GetTrueX(), self:GetTrueY()
					-- Use a more generous hitbox for the button
					local over = mx >= ax-60 and mx <= ax+60 and my >= ay-20 and my <= ay+20

					if event.type == "InputEventType_FirstPress" then
						if over then
							SCREENMAN:GetTopScreen():ToggleInputHidden()
							self:playcommand("Update")
							MESSAGEMAN:Broadcast("UpdateUnhideText")
						end
					end
				end)
			end,
			OnCommand = function(self)
				self:playcommand("Update")
			end,
			UpdateUnhideTextMessageCommand = function(self) self:playcommand("Update") end,
			UpdateCommand = function(self)
				local screen = SCREENMAN:GetTopScreen()
				if screen then
					self:visible(true) -- Always show the button once we are in a text entry screen that supports it
					-- If the screen doesn't support input hiding, the engine might not reveal anything, 
					-- but for Login it definitely does.
				end
			end,
			
			Def.Quad {
				InitCommand = function(self) self:zoomto(100, 24):diffuse(color("1,1,1,0.05")) end,
				UpdateCommand = function(self) self:stoptweening():linear(0.1):diffusealpha(self:GetParent().isHeld and 0.4 or 0.1) end
			},
			-- Outer Border for button
			Def.Quad {
				InitCommand = function(self) self:zoomto(100, 1):y(-12):diffuse(accentColor):diffusealpha(0.5) end
			},
			Def.Quad {
				InitCommand = function(self) self:zoomto(100, 1):y(12):diffuse(accentColor):diffusealpha(0.2) end
			},
			LoadFont("Common Normal") .. {
				Text = "UNHIDE",
				InitCommand = function(self) self:zoom(0.4):diffuse(accentColor):shadowlength(1) end,
				UpdateUnhideTextMessageCommand = function(self) self:playcommand("Update") end,
				UpdateCommand = function(self) 
					local screen = SCREENMAN:GetTopScreen()
					local isMasked = screen and screen:IsInputHidden()
					if not isMasked then
						self:settext("HIDE")
						self:diffuse(brightText):glow(accentColor)
					else
						self:settext("UNHIDE")
						self:diffuse(accentColor):glow(color("0,0,0,0"))
					end
				end
			}
		},

		-- Help Text
		LoadFont("Common Normal") .. {
			Text = "RIGHT-CLICK TO CANCEL",
			InitCommand = function(self) self:xy(boxWidth/2 - 80, boxHeight/2 - 25):zoom(0.3):diffuse(dimText) end
		}
	}
}
