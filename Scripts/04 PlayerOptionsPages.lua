-- Tab display labels and mapping to screen names
HV.PlayerOptionsTabs = {
	{ key = "Main",   label = "Player Options",       screen = "ScreenPlayerOptions" },
	{ key = "Theme",  label = "Quick Theme Options", screen = "ScreenPlayerOptionsTheme" },
	{ key = "Effect", label = "Effect Options",      screen = "ScreenPlayerOptionsEffect" },
}

-- Helper to get the current tab key based on the screen name
function HV.GetCurrentPlayerOptionsTabKey()
	local screen = SCREENMAN:GetTopScreen()
	if not screen then return "Main" end
	local name = screen:GetName()
	for _, t in ipairs(HV.PlayerOptionsTabs) do
		if t.screen == name then return t.key end
	end
	return "Main"
end

-- Override PONextScreen: shows tab nav with "Gameplay" as the leftmost choice.
-- @param currentKey The key of the page we are currently on (passed from metrics.ini)
function PONextScreen(currentKey)
	local tabs = HV.PlayerOptionsTabs
	local choices = { "Gameplay" } -- Gameplay is now the first choice
	for _, t in ipairs(tabs) do
		table.insert(choices, t.label)
	end

	return {
		Name = "PONextScreen",
		LayoutType = "ShowAllInRow",
		SelectType = "SelectOne",
		OneChoiceForAllPlayers = true,
		ExportOnChange = false,
		Choices = choices,
		LoadSelections = function(self, list, pn)
			-- Highlight 'Gameplay' by default (index 1)
			list[1] = true
		end,
		SaveSelections = function(self, list, pn)
			for i, selected in ipairs(list) do
				if selected then
					if i == 1 then
						-- "Gameplay" — exit to gameplay
						SCREENMAN:GetTopScreen():SetNextScreenName(ToGameplay())
					else
						-- Navigate to the specific screen for that tab (offset by 1 due to Gameplay)
						local targetScreen = tabs[i - 1].screen
						SCREENMAN:GetTopScreen():SetNextScreenName(targetScreen)
					end
					return
				end
			end
		end,
	}
end

Trace("Holographic Void: 04 PlayerOptionsPages.lua loaded.")
