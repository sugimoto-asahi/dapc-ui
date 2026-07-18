local panel = require("dapc-ui.panel")

local M = {}

function M.setup()
	require("dapc-ui.highlights")
	panel.setup()
end

vim.keymap.set("n", "<leader>dt", panel.toggle, {})

return M
