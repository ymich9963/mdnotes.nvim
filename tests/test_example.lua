local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

-- Create (but not start) child Neovim object
local child = MiniTest.new_child_neovim()

-- Define main test set of this file
local T = new_set({
    -- Register hooks
    hooks = {
        -- This will be executed before every (even nested) case
        pre_case = function()
            -- Restart child process with custom 'init.lua' script
            child.restart({ '-u', 'scripts/minimal_init.lua' })
            -- Load tested plugin
            child.lua([[M = require('mdnotes')]])
            child.lua([[require('mdnotes').setup()]])
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['emphasis'] = function()
    local buf = child.api.nvim_create_buf(false, true)
    local lines = {
        "emphasis",
    }

    child.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    child.api.nvim_set_current_buf(buf)
    child.api.nvim_win_set_cursor(0, {1, 0})
    child.lua([[require('mdnotes.formatting').emphasis_toggle()]])

    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)

    eq(lines[3], "*emphasis*")
end

return T
