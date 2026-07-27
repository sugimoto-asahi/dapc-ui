require("dapc-ui.highlights")
local panel = require("dapc-ui.panel")
local Editor = require("dapc-ui.Editor")

local M = {}

function M.setup()
	panel.setup()
	Editor:setup()
end

vim.keymap.set("n", "<leader>dt", panel.toggle, {})

return M
