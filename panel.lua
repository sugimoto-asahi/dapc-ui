local header = require("dapc-ui.header")
local VariablesBuf = require("dapc-ui.VariablesBuf")

_G.fold_fn = function()
	local fold_level = vim.g.fold_map[vim.v.lnum]
	return fold_level
end

--- @class Panel Debug panel (vim window)
local Panel = {
	subpanel_bufs = {},
}

local win

--- Toggle the debug panel open or close
function Panel.toggle()
	if win ~= nil and vim.api.nvim_win_is_valid(win) then
		Panel.close()
	else
		Panel.open()
	end
end

--- Perform initial setup
function Panel.setup()
	-- Create buffers for each subpanel
	-- These are persistent and will be in use throughout this session
	local variables_buf = VariablesBuf:setup()
	local scopes_buf = vim.api.nvim_create_buf(false, false)

	--- @type number[]
	table.insert(Panel.subpanel_bufs, variables_buf)
	table.insert(Panel.subpanel_bufs, scopes_buf)

	-- Assign buffer-only keymaps to each subpanel
	Panel.setup_keymaps(Panel.subpanel_bufs)
end

--- @private
function Panel.open()
	-- by default we display the first subpanel
	win = vim.api.nvim_open_win(Panel.subpanel_bufs[1], true, { split = "below", height = 15 })
	vim.wo[win].foldmethod = "expr"
	vim.wo[win].foldexpr = "v:lua.fold_fn()"
	header.show(win, 1)
end

--- @private
function Panel.close()
	vim.api.nvim_win_hide(win)
end

--- Switch the currently displayed subpanel
--- @param index number Index of subpanel to switch to
function Panel.switch_subpanel(index)
	vim.api.nvim_set_current_buf(Panel.subpanel_bufs[index])
	header.select(index)
end

--- @private
--- Set up keymappings for switching between subpanels
--- @param bufs number[] Buffers to set keymaps in
function Panel.setup_keymaps(bufs)
	for _, buf in ipairs(bufs) do
		vim.keymap.set("n", "V", function()
			Panel.switch_subpanel(1)
		end, { buf = buf })
		vim.keymap.set("n", "S", function()
			Panel.switch_subpanel(2)
		end, { buf = buf })
	end
end

return Panel
