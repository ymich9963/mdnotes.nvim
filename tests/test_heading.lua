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
            child.lua([[require('mdnotes').setup()]])
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['get_current_heading()'] = function()
    -- Setup test buffer
    local lines = {
        "# Heading 1",
        "Text here",
        "",
        "## Heading 2",
        "Text here",
    }
    local buf = create_md_buffer(child, lines)

    local ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    return {require('mdnotes.heading').get_current_heading()}
    ]])
    eq(ret, {1, {hash = "#", text = "Heading 1", lnum = 1}, 2})

    child.fn.cursor(4,1)
    ret = child.lua([[
    return {require('mdnotes.heading').get_current_heading()}
    ]])
    eq(ret, {2, {hash = "##", text = "Heading 2", lnum = 4}, 2})
end

T['goto_next()'] = function()
    -- Setup test buffer
    local lines = {
        "# Heading 1",
        "Text here",
        "",
        "## Heading 2",
        "Text here",
    }
    create_md_buffer(child, lines)

    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    return {require('mdnotes.heading').goto_next()}
    ]])
    eq(child.fn.getcurpos()[2], 4)

    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    return {require('mdnotes.heading').goto_next()}
    ]])
    eq(child.fn.getcurpos()[2], 1)
end

T['goto_previous()'] = function()
    -- Setup test buffer
    local lines = {
        "# Heading 1",
        "Text here",
        "",
        "## Heading 2",
        "Text here",
    }
    create_md_buffer(child, lines)

    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    require('mdnotes.heading').goto_previous()
    ]])
    eq(child.fn.getcurpos()[2], 4)

    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    require('mdnotes.heading').goto_previous()
    ]])
    eq(child.fn.getcurpos()[2], 1)
end

return T
