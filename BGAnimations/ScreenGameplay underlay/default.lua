--- Holographic Void: ScreenGameplay Underlay (Lane Filter)
-- Localized dimming for the notefield area.

local loadingScreen = Var "LoadingScreen" or ""
local miniSizePct = tonumber(ThemePrefs.Get("HV_Mini")) or 100
local miniModValue = 2 - (miniSizePct / 50)

for _, player in ipairs(GAMESTATE:GetEnabledPlayers()) do
	local ps = GAMESTATE:GetPlayerState(player)
	if ps then
		for _, level in ipairs({
			loadingScreen == "ScreenEditOptions" and "ModsLevel_Stage" or "ModsLevel_Preferred",
			"ModsLevel_Stage",
			"ModsLevel_Current",
		}) do
			local po = ps:GetPlayerOptions(level)
			if po and po.Mini then
				po:Mini(miniModValue)
			end
		end
	end
end

local t = Def.ActorFrame {
	EndCommand = function(self)
		unsetMovableKeymode()
	end
}

setMovableKeymode(getCurrentKeyMode())

local function getLaneFilterWidth()
	local baseColumnWidth = 64
	local columns = 4
	local style = GAMESTATE:GetCurrentStyle()
	if style and style.ColumnsPerPlayer then
		local ok, value = pcall(function() return style:ColumnsPerPlayer() end)
		if ok and tonumber(value) then
			columns = math.max(1, tonumber(value))
		end
	end

	local widthScale = (MovableValues and tonumber(MovableValues.NotefieldWidth)) or getDefaultGameplaySize("NotefieldWidth") or 1
	local spacing = (MovableValues and tonumber(MovableValues.NotefieldSpacing)) or getDefaultGameplaySize("NotefieldSpacing") or 0
	local receptorScale = HV.Clamp((tonumber(ThemePrefs.Get("HV_Mini")) or 100) / 100, 0.01, 2.5)

	local filterWidth = ((columns * baseColumnWidth * widthScale) + ((columns - 1) * spacing)) * receptorScale
	return math.max(baseColumnWidth, filterWidth)
end

local filterW = getLaneFilterWidth()

t[#t + 1] = Def.Quad {
	Name = "LaneFilter",
	InitCommand = function(self)
		local filterVal = HV.GetScreenFilter()
		self:Center():zoomto(filterW, SCREEN_HEIGHT)
			:diffuse(color("0,0,0,1")):diffusealpha(filterVal)
	end,
	OnCommand = function(self)
		-- Ensure it stays visible if changed (though normally it's static during gameplay)
	end
}

return t
