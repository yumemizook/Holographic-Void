--- Holographic Void: Branching Logic
-- Handles redirection between screens based on game state (e.g. no songs).

Branch.AfterInit = function()
	-- If zero songs found (and no downloads in progress), redirect to core bundle selector
	if SONGMAN:GetNumSongs() == 0 and SONGMAN:GetNumAdditionalSongs() == 0 and #DLMAN:GetDownloads() == 0 then
		return "ScreenCoreBundleSelect"
	end
	
	-- Normal flow
	return "ScreenTitleMenu"
end

Branch.TitleMenu = function()
	return "ScreenTitleMenu"
end

Branch.AfterTitleMenu = function()
	return "ScreenSelectProfile"
end

Branch.AfterSelectProfile = function()
	return "ScreenSelectMusic"
end

Trace("Holographic Void: 09 Branch.lua loaded.")
