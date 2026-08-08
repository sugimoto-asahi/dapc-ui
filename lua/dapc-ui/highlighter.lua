local M = {}

--- Utility functions and types for manipuluating lines in buffers
--- while having highlighting support.
--- The unit of manipulation is a "Line". A Line maps to a single line in buffers.
--- A Line consists of the text that will display in the buffer line, as well as
--- highlighting information for different parts of the line.
--- For example, in the buffer line
--- "int foo: 1"
--- we wish to highlight "int" (the variable type), "foo" (the variable name) and
--- "1" (the variable value) differently. A Line packages all this information.
--- This module also provides functions for manipulating Lines in a buffer.
--- This abstracts away the manual overhead of having to do nvim_buf_set_lines,
--- followed by nvim_buf_set_extmark for each section of the line we want to color differently.

--- @class dapc-ui.Line.Highlight Highlighting information for
--- a section of the display line
--- @field hl_group string Highlight group
--- @field start_col number Start column of highlight
--- @field end_col number End column of highlight (exclusive)

--- @class dapc-ui.Line
--- @field text string Display string for this node
--- @field highlights dapc-ui.Line.Highlight[]
--- @field sign string? Sign text

--- Replace a line in a buffer with a Line
--- @param buf number Target buffer
--- @param row number Row number of line to replace
--- @param line dapc-ui.Line New line
--- @param indent string? Additional indent to apply
function M.replace(buf, row, line, indent)
	indent = indent or ""
	vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { indent .. line.text })
	local ns = vim.api.nvim_create_namespace("")
	for _, highlight in ipairs(line.highlights) do
		vim.api.nvim_buf_set_extmark(buf, ns, row - 1, #indent + highlight.start_col - 1, {
			hl_group = highlight.hl_group,
			end_col = #indent + highlight.end_col - 1,
			-- automatically delete the extmark when the line is deleted
			invalidate = true,
			undo_restore = false,
		})
		if line.sign then
			vim.api.nvim_buf_set_extmark(buf, ns, row - 1, 0, {
				sign_text = line.sign,
			})
		end
	end
end

--- Insert a Line into a buffer
--- @param buf number Target buffer
--- @param row number Row number of line to insert at (inserts above).
--- Inserting into row N + 1 for a buffer with N rows will result in a new row
--- being added and the line being placed at row N + 1.
--- @param line dapc-ui.Line New line
--- @param indent string? Additional indent to apply
function M.insert(buf, row, line, indent)
	indent = indent or ""
	vim.api.nvim_buf_set_lines(buf, row - 1, row - 1, false, { indent .. line.text })
	local ns = vim.api.nvim_create_namespace("")
	for _, highlight in ipairs(line.highlights) do
		vim.api.nvim_buf_set_extmark(buf, ns, row - 1, #indent + highlight.start_col - 1, {
			hl_group = highlight.hl_group,
			end_col = #indent + highlight.end_col - 1,
			-- automatically delete the extmark when the line is deleted
			invalidate = true,
			undo_restore = false,
		})
		if line.sign then
			vim.api.nvim_buf_set_extmark(buf, ns, row - 1, 0, {
				sign_text = line.sign,
			})
		end
	end
end

return M
