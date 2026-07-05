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

T['get_heading()'] = function()
    -- Setup test buffer
    local lines = {
        "# Heading 1",
        "Text here",
        "",
        "## Heading 2",
        "Text here",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    require('mdnotes').populate_buf_fragments()
    return require('mdnotes.heading').get_heading()
    ]])
    eq(ret, {hash = "#", text = "Heading 1", gfm = "heading-1", lnum = 1})

    child.fn.cursor(4,1)
    ret = child.lua([[ return require('mdnotes.heading').get_heading() ]])
    eq(ret, {hash = "##", text = "Heading 2", gfm = "heading-2", lnum = 4})
end

T['move_to()'] = function()
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
    require('mdnotes').populate_buf_fragments()
    require('mdnotes.heading').move_to(1)
    ]])
    eq(child.fn.getcurpos()[2], 4)

    child.lua([[ return require('mdnotes.heading').move_to(1) ]])
    eq(child.fn.getcurpos()[2], 1)

    child.lua([[ return require('mdnotes.heading').move_to(-1) ]])
    eq(child.fn.getcurpos()[2], 4)

    child.lua([[ return require('mdnotes.heading').move_to(-1) ]])
    eq(child.fn.getcurpos()[2], 1)
end

return T
