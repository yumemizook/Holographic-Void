--- Etternity: ScreenTitleMenu Overlay
-- Rebuilt to focus only on custom cursor and jukebox shortcuts.
local choiceNames = {"Start", "ColorTheme", "Options", "Exit"}

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

-- Menu Click Handler
t[#t+1] = UIElements.QuadButton(1) .. {
    InitCommand = function(self)
        -- zoomto adjusted slightly for 4 items instead of 5
        self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + 20):zoomto(300, 180):diffusealpha(0)
    end,
    MouseDownCommand = function(self, params)
        if params.event == "DeviceButton_left mouse button" then
            local virtualX = INPUTFILTER:GetMouseX()
            local virtualY = INPUTFILTER:GetMouseY()
            local hovered = nil
            
            -- Changed loop to 4 for the new item count
			for i = 1, 4 do
				local static_iy = (SCREEN_CENTER_Y + 20) + 44 * (i - 2.5)
				if virtualX >= SCREEN_CENTER_X-150 and virtualX <= SCREEN_CENTER_X+150 
				and virtualY >= static_iy-22 and virtualY <= static_iy+22 then
					hovered = i break
				end
			end
            
            if hovered then
                local screen = SCREENMAN:GetTopScreen()
                if screen then
                    local name = choiceNames[hovered]
                    
                    if screen:GetChild("Scroller") then
                        screen:GetChild("Scroller"):SetDestinationItem(hovered - 1)
                    end
                    
                    if name == "Start" then
                        GAMESTATE:JoinPlayer()
                    end
                    
                    screen:playcommand("MadeChoicePlayer_1")
                    screen:playcommand("Choose")
                    
                    local command = THEME:GetMetric("ScreenTitleMenu", "Choice" .. name)
                    if command then
                        GAMESTATE:ApplyGameCommand(command)
                        SOUND:PlayOnce(THEME:GetPathS("Common", "start"))
                    end
                end
            end
        end
    end
}

return t