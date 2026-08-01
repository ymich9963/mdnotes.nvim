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

T['parse'] = function()
    local lines = {
        "[^1]",
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    }
    create_md_buffer(child, lines)

    child.fn.cursor(1,2)
    local ret = child.lua([[ return require('mdnotes.reference_link').parse() ]])
    eq(ret, {
        identifier = "1",
        buf = 2,
        lnum = 1,
        col_start = 1,
        col_end = 5,
        cur_col = 3,
    })

    child.fn.cursor(2,14)
    ret = child.lua([[ return require('mdnotes.reference_link').parse() ]])
    eq(ret, {
        identifier = "2",
        buf = 2,
        lnum = 2,
        col_start = 13,
        col_end = 17,
        cur_col = 15,
    })
end

T['get_buf_footnotes()'] = function()
    local lines = {
        "[^1]",
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[ return require('mdnotes.footnote').get_buf_footnotes() ]])
    eq(ret, {
        {
            identifier = "1",
            lnum = 4
        },
        {
            identifier = "2",
            lnum = 5
        },
    })
end

T['populate_buf_footnotes()'] = function()
        "[^1]",
        local lines = {
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    require('mdnotes.reference_link').populate_buf_footnotes()
    return require('mdnotes.reference_link').buf_footnotes
    ]])
    eq(ret, {
        {
            buf = 2,
            footnotes = {
                {
                    identifier = "1",
                    text = "This is footnote 1",
                    lnum = 4
                },
                {
                    identifier = "2",
                    text = "This is footnote 2",
                    lnum = 5
                },
            }
        }
    })
end

T['insert()'] = function()
    local lines = {
        "",
        "",
        "",
    }
    create_md_buffer(child, lines)

    child.fn.cursor({1,1})
    child.lua([[ require('mdnotes.footnote').insert({ identifier = "1", text = "This is footnote 1" }) ]])
    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[^1]",
        "",
        "",
        "[^1]: This is footnote 1",
    })

    child.fn.cursor({2,1})
    child.lua([[ require('mdnotes.footnote').insert() ]])
    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[^1]",
        "[^2]",
        "",
        "[^1]: This is footnote 1",
        "[^2]: ",
    })
end

T['get_footnote()'] = function()
    local lines = {
        "[^1]",
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    require('mdnotes.reference_link').populate_buf_footnotes()
    return require('mdnotes.reference_link').get_footnote("1")
    ]])
    eq(ret, {
        identifier = "1",
        text = "This is footnote 1",
        lnum = 4
    })
end

return T
