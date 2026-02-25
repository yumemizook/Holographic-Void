--- Holographic Void: Custom Mouse Cursor
-- Adapted from Til Death's _cursor.lua pattern.
-- Should be loaded from screen overlays via LoadActor("_cursor").
-- Uses the _fallback TOOLTIP system for positioning + tooltip text.

local screenName = Var("LoadingScreen") or ...

local function UpdateLoop()
	local mouseX = INPUTFILTER:GetMouseX()
	local mouseY = INPUTFILTER:GetMouseY()
	TOOLTIP:SetPosition(mouseX, mouseY)
	return false
end

local function cursorCheck()
	-- Show custom cursor in fullscreen (system cursor hidden)
	-- In windowed mode, the system cursor is visible so hide ours
	if not PREFSMAN:GetPreference("Windowed") and not PREFSMAN:GetPreference("FullscreenIsBorderlessWindow") then
		TOOLTIP:ShowPointer()
	else
		TOOLTIP:HidePointer()
	end
end

local t = Def.ActorFrame {
	OnCommand = function(self)
		self:SetUpdateFunction(UpdateLoop)
		-- Match display refresh rate for smooth cursor tracking
		local refreshRate = DISPLAY:GetDisplayRefreshRate()
		if refreshRate and refreshRate > 0 then
			self:SetUpdateFunctionInterval(1 / refreshRate)
		end
		cursorCheck()
	end,
	OffCommand = function(self)
		TOOLTIP:Hide()
	end,
	CancelCommand = function(self)
		self:playcommand("Off")
	end,
	WindowedChangedMessageCommand = function(self)
		cursorCheck()
	end,
	ReloadedScriptsMessageCommand = function(self)
		cursorCheck()
	end,
}

-- Create tooltip + pointer + click wave actors from the _fallback system
local tooltip, pointer, clickwave = TOOLTIP:New()
t[#t + 1] = tooltip
t[#t + 1] = pointer
t[#t + 1] = clickwave

return t
