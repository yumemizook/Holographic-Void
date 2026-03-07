--- Holographic Void: Utility Functions
-- Ported and adapted from Til Death for consistent engine-level interactions.

-- ms fallback for notifications
ms = ms or {}
function ms.ok(text)
	SCREENMAN:SystemMessage(text)
end

--- Open a ScreenTextEntry popup with OK and Cancel callbacks.
-- @param question   The question/prompt to display
-- @param maxLength  Maximum input character length
-- @param isPassword Boolean to mask the input
-- @param funcOK     Function(answer) to call on OK
-- @param funcCancel Function() to call on Cancel or Esc
function easyInputStringOKCancel(question, maxLength, isPassword, funcOK, funcCancel)
	SCREENMAN:AddNewScreenToTop("ScreenTextEntry")
	local settings = {
		Question = question,
		MaxInputLength = maxLength,
		Password = isPassword,
		OnOK = function(answer)
			local top = SCREENMAN:GetTopScreen()
			if top and top:GetName() == "ScreenTextEntry" then top:Cancel() end
			funcOK(answer)
		end,
		OnCancel = function()
			local top = SCREENMAN:GetTopScreen()
			if top and top:GetName() == "ScreenTextEntry" then top:Cancel() end
			if funcCancel then funcCancel() end
		end,
	}
	SCREENMAN:GetTopScreen():Load(settings)
end

--- Wrapper for simple text entry with only an OK callback.
-- @param question   The question/prompt to display
-- @param maxLength  Maximum input character length
-- @param isPassword Boolean to mask the input
-- @param func       Function(answer) to call on OK
function easyInputStringWithFunction(question, maxLength, isPassword, func)
	easyInputStringOKCancel(
		question,
		maxLength,
		isPassword,
		function(answer)
			func(answer)
		end,
		nil
	)
end

--- Map a DeviceInput button name to its equivalent character.
-- @param btn     The button string (e.g., "DeviceButton_a")
-- @param shifted Boolean for shift key state
-- @return        A single character string, or nil
function DeviceBtnToChar(btn, shifted)
	if not btn then return nil end
	local b = btn:lower()
	local letter = b:match("^devicebutton_([a-z])$")
	if letter then return shifted and letter:upper() or letter end
	local digit = b:match("^devicebutton_([0-9])$")
	if digit then
		if shifted then
			local shiftMap = { ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%",
				["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")" }
			return shiftMap[digit] or digit
		end
		return digit
	end
	
	local symMap = {
		["devicebutton_period"] = shifted and ">" or ".",
		["devicebutton_comma"] = shifted and "<" or ",",
		["devicebutton_slash"] = shifted and "?" or "/",
		["devicebutton_backslash"] = shifted and "|" or "\\",
		["devicebutton_minus"] = shifted and "_" or "-",
		["devicebutton_equals"] = shifted and "+" or "=",
		["devicebutton_semicolon"] = shifted and ":" or ";",
		["devicebutton_apostrophe"] = shifted and "\"" or "'",
		["devicebutton_left bracket"] = shifted and "{" or "[",
		["devicebutton_right bracket"] = shifted and "}" or "]",
		["devicebutton_grave"] = shifted and "~" or "`",
		["devicebutton_space"] = " ",
	}
	return symMap[b]
end

Trace("Holographic Void: 07 Util.lua loaded.")
