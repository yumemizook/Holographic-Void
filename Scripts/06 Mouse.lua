--- Holographic Void: Mouse Support Utilities
-- Provides helper functions for mouse-driven interaction across screens.
-- Loaded globally by the Scripts/ auto-load system.

-- ============================================================
-- MOUSE POSITION HELPERS
-- ============================================================

--- Check if the current mouse position falls within a rectangular hitbox.
-- All coordinates are in screen-space (absolute pixel values).
-- @param x  Left edge of the hitbox
-- @param y  Top edge of the hitbox
-- @param w  Width of the hitbox
-- @param h  Height of the hitbox
-- @return   true if the mouse cursor is inside the rectangle
function IsMouseOver(x, y, w, h)
	local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
	return mx >= x and mx <= x + w and my >= y and my <= y + h
end

--- Check if the current mouse position is over a centered rectangle.
-- The rectangle is defined by its center (cx, cy) and dimensions (w, h).
-- @param cx  Center X
-- @param cy  Center Y
-- @param w   Width
-- @param h   Height
-- @return    true if the mouse cursor is inside
function IsMouseOverCentered(cx, cy, w, h)
	return IsMouseOver(cx - w / 2, cy - h / 2, w, h)
end

--- Determine which item in a vertical list the mouse is hovering.
-- @param baseX  Left edge X of the list area
-- @param baseY  Center Y of the first item
-- @param w      Width of each item hitbox
-- @param h      Height of each item hitbox
-- @param count  Number of items
-- @param spacing  Vertical distance between item centers
-- @return       1-based index of hovered item, or nil if none
function GetMousedOverItem(baseX, baseY, w, h, count, spacing)
	local mx, my = INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY()
	for i = 1, count do
		local iy = baseY + (i - 1) * spacing
		if mx >= baseX and mx <= baseX + w
			and my >= iy - h / 2 and my <= iy + h / 2 then
			return i
		end
	end
	return nil
end

--- Check if a DeviceInput button represents a mouse click.
-- @param btn  The DeviceInput button string
-- @return     true if it is a left mouse button press
function IsMouseLeftClick(btn)
	return btn == "DeviceButton_left mouse button"
end

--- Check if a DeviceInput button represents a mouse wheel scroll.
-- @param btn  The DeviceInput button string
-- @return     -1 for scroll up, 1 for scroll down, 0 otherwise
function GetMouseScrollDirection(btn)
	if btn == "DeviceButton_mousewheel up" then
		return -1
	elseif btn == "DeviceButton_mousewheel down" then
		return 1
	end
	return 0
end

--- Check if the mouse is over a given actor, accounting for its alignment and scale.
-- Highly robust and works for actors with any HAlign/VAlign.
-- @param self The actor to check
-- @return true if the mouse is currently over the actor
function isOver(self)
	if not self or not self:GetVisible() then return false end
	local mx = INPUTFILTER:GetMouseX()
	local my = INPUTFILTER:GetMouseY()
	local x = self:GetTrueX()
	local y = self:GetTrueY()
	local w = self:GetZoomedWidth()
	local h = self:GetZoomedHeight()

	local ha = self:GetHAlign()
	local va = self:GetVAlign()

	return mx >= x - (w * ha) and mx <= x + (w * (1 - ha)) and
	       my >= y - (h * va) and my <= y + (h * (1 - va))
end
