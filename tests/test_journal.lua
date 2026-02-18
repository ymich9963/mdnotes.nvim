local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local create_md_buffer = require('tests/helpers').create_md_buffer

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
            child.lua([[require('mdnotes').setup({journal_file = "journal.md"})]])
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['get_journal_file()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    return require('mdnotes.journal').get_journal_file()
    ]])
    eq(ret, "journal.md")
end

T['insert_entry()'] = function()
    local lines = {
        ""
    }
    local buf = create_md_buffer(child, lines)
    local strftime = vim.fn.strftime("%a %d %b %Y"):match("([^\n\r\t]+)")
    local journal_entry = {
        "## " .. strftime,
        "",
        "",
        "",
        "---",
        ""
    }

    child.lua([[ return require('mdnotes.journal').insert_entry({ silent = true, check_file = false }) ]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, journal_entry)

    child.lua([[ return require('mdnotes.journal').insert_entry({ silent = true, check_file = false }) ]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, journal_entry)
end

return T
