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
    local ret = child.lua([[ return Mdn.footnote.parse() ]])
    eq(ret, {
        buf = 2,
        col_end = 5,
        col_start = 1,
        cur_col = 2,
        identifier = "1",
        lnum = 1,
        raw = "[^1]"
    })

    child.fn.cursor(2,14)
    ret = child.lua([[ return Mdn.footnote.parse() ]])
    eq(ret, {
        buf = 2,
        col_end = 17,
        col_start = 13,
        cur_col = 14,
        identifier = "2",
        lnum = 2,
        raw = "[^2]"
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

    local ret = child.lua([[ return Mdn.footnote.get_buf_footnotes() ]])
    eq(ret, {
        {
            identifier = "1",
            lnum = 4,
            text = "This is footnote 1"
        },
        {
            identifier = "2",
            lnum = 5,
            text = "This is footnote 2"
        },
    })
end

T['populate_buf_footnotes()'] = function()
    local lines = {
        "[^1]",
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    Mdn.footnote.populate_buf_footnotes()
    return Mdn.footnote.buf_footnotes
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
    child.lua([[ Mdn.footnote.insert({ identifier = "1", text = "This is footnote 1" }) ]])
    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[^1]",
        "",
        "",
        "[^1]: This is footnote 1",
    })
    local curpos = {child.fn.getpos(".")[2], child.fn.getpos(".")[3]}
    eq(curpos, {4,6})

    child.fn.cursor({2,1})
    child.lua([[ Mdn.footnote.insert() ]])
    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[^1]",
        "[^2]",
        "",
        "[^1]: This is footnote 1",
        "[^2]: ",
    })
    curpos = {child.fn.getpos(".")[2], child.fn.getpos(".")[3]}
    eq(curpos, {5,6})
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
    Mdn.footnote.populate_buf_footnotes()
    return Mdn.footnote.get_footnote("1")
    ]])
    eq(ret, {
        identifier = "1",
        text = "This is footnote 1",
        lnum = 4
    })
end

T['go_to()'] = function()
    local lines = {
        "[^1]",
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    }
    create_md_buffer(child, lines)

    child.lua([[
    Mdn.footnote.populate_buf_footnotes()
    Mdn.footnote.go_to({identifier = "1"})
    ]])
    eq(child.fn.line("."), 4)
end

T['get_footnote_from_obj()'] = function()
    local ret = child.lua([[ return Mdn.footnote.get_footnote_from_obj({identifier = "1", text = "text"}) ]])
    eq(ret, "[^1]: text")
end

T['update()'] = function()
    local lines = {
        "[^1]",
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    }
    create_md_buffer(child, lines)

    child.lua([[
    Mdn.footnote.populate_buf_footnotes()
    Mdn.footnote.update({identifier = "1", new_identifier = "5", skip_input = true})
    Mdn.footnote.update({identifier = "2", new_text = "new text", skip_input = true})
    ]])

    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[^5]",
        "Text before [^2] and after",
        "",
        "[^5]: This is footnote 1",
        "[^2]: new text",
    })
end

T['cleanup()'] = function()
    local lines = {
        "[^3]",
        "[^1]",
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    }
    create_md_buffer(child, lines)

    child.lua([[
    Mdn.footnote.populate_buf_footnotes()
    Mdn.footnote.cleanup()
    ]])

    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "",
        "[^1]",
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    })
end

T['get_fref_from_obj()'] = function()
    local ret = child.lua([[ return Mdn.footnote.get_fref_from_obj({identifier = "1"}) ]])
    eq(ret, "[^1]")
end

T['parse_lines()'] = function()
    local lines = {
        "[^1]",
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[return Mdn.footnote.parse_lines({ location = {startl = 1, endl = vim.fn.line("$") }, silent = true }) ]])
    eq(ret, {
        {
            buf = 2,
            col_end = 5,
            col_start = 1,
            cur_col = 3,
            lnum = 1,
            identifier = "1",
            raw = "[^1]",
        },
        {
            buf = 2,
            col_end = 17,
            col_start = 13,
            cur_col = 15,
            lnum = 2,
            identifier = "2",
            raw = "[^2]",
        }
    })
    ret = child.lua([[return Mdn.footnote.parse_lines({ str = true, location = {startl = 1, endl = vim.fn.line("$") }, silent = true }) ]])
    eq(ret, {"[^1]", "[^2]", "", ""})
end

T['find_references()'] = function()
    local lines = {
        "[^1]",
        "[^1]",
        "Text before [^2] and after",
        "",
        "[^1]: This is footnote 1",
        "[^2]: This is footnote 2",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    Mdn.footnote.populate_buf_footnotes()
    return Mdn.footnote.find_references({identifier = "1"})
    ]])
    eq(ret, {
        {
            bufnr = 2,
            col = 1,
            end_col = 5,
            lnum = 1
        }, {
            bufnr = 2,
            col = 1,
            end_col = 5,
            lnum = 2
        }
    })
end

T['renumber()'] = function()
    local lines = {
        "[^5] test",
        "",
        "This is a footnote [^1] for testing. Another one here [^3]. [^test]",
        "",
        "[^1]",
        "",
        "[^test]: footnote test",
        "[^3]: footnote 3",
        "[^1]: footnote 1",
        "[^4]: footnote 4",
    }
    create_md_buffer(child, lines)

    child.lua([[
    Mdn.footnote.populate_buf_footnotes()
    Mdn.footnote.renumber()
    ]])

    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        " test",
        "",
        "This is a footnote [^1] for testing. Another one here [^2]. [^test]",
        "",
        "[^1]",
        "",
        "[^test]: footnote test",
        "[^1]: footnote 1",
        "[^2]: footnote 3",
    })
end

return T
