--- Holographic Void: ScreenTitleMenu Overlay
-- Rebuilt to focus only on custom cursor and jukebox shortcuts.

local t = Def.ActorFrame {}

-- Cursor stays on top
t[#t+1] = LoadActor("../_cursor")

-- Combined Input Controller
t[#t+1] = Def.ActorFrame {
	BeginCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end
		screen:AddInputCallback(function(event)
			-- Background shortcuts (Jukebox Pause)
			if event.type == "InputEventType_FirstPress" then
				local btn = event.DeviceInput.button
				if btn == "DeviceButton_backslash" then
					MESSAGEMAN:Broadcast("TriggerJukeboxPause")
					return true
				end
			end
			return false
		end)
	end
}

return t
