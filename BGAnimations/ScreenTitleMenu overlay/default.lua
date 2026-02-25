--- Holographic Void: ScreenTitleMenu Overlay
-- Login modal was moved to ScreenSelectMusic decorations.
-- Keep only the cursor overlay on title screen.

local t = Def.ActorFrame {}

-- ============================================================
-- MOUSE CURSOR
-- ============================================================
t[#t + 1] = LoadActor("../_cursor")

return t
