--- Panel header bar, implemented with native winbar
local M = {
	HEADERS = {
		"Variables",
		"Scopes",
	},
}

--- Make the styled string for assigning to vim.wo.winbar
--- @param selected number Index of selected header item
local function make_winbar(selected)
	local padding = 1 -- number of padding whitespace around each item

	local winbar = ""
	for i, name in ipairs(M.HEADERS) do
		if i == selected then
			winbar = winbar
				.. "%#DapUIHeaderItemSel#"
				.. string.rep(" ", padding)
				.. name
				.. string.rep(" ", padding)
				.. "%*"
		else
			winbar = winbar
				.. "%#DapUIHeaderItem#"
				.. string.rep(" ", padding)
				.. name
				.. string.rep(" ", padding)
				.. "%*"
		end
	end
	return winbar
end

--- Display the header bar.
--- @param win number Window number of the window the header should display relative to
--- @param index number Index of header item to display as selected
function M.show(win, index)
	local winbar = make_winbar(index)
	vim.wo[win].winbar = winbar
end

function M.hide(win)
	vim.wo[win].winbar = "" -- setting "winbar" to an empty string removes it
end

--- Select the header item at the given index
--- @param index number
function M.select(index)
	local winbar = make_winbar(index)
	vim.wo.winbar = winbar
end

return M
