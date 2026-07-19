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

T['parse()'] = function()
    -- Setup test buffer
    local lines = {
        "[neovim][]",
        "[test][neovim]",
        "[test][neovim]",
        "",
        "[mdnotes][]",
        "[test][mdnotes]",
        "[test][mdnotes]",
        "",
        "[test][]",
        "[test][]",
        "[test][]",
        "",
        "[mdnotes]: https://github.com/ymic9963/mdnotes.nvim",
        "[neovim]: https://www.neovim.io",
        "[test]: https://example.org",
    }
    create_md_buffer(child, lines)

    child.fn.cursor(1,2)
    local ret = child.lua([[ return require('mdnotes.reference_link').parse() ]])
    eq(ret, {
        text = "neovim",
        label = "neovim",
        buf = 2,
        lnum = 1,
        col_start = 1,
        col_end = 11,
        cur_col = 2,
    })

    child.fn.cursor(2,2)
    ret = child.lua([[ return require('mdnotes.reference_link').parse() ]])
    eq(ret, {
        text = "test",
        label = "neovim",
        buf = 2,
        lnum = 2,
        col_start = 1,
        col_end = 15,
        cur_col = 2,
    })
end

T['get_buf_reference_link_definitions()'] = function()
    local lines = {
        "[neovim][]",
        "[test][neovim]",
        "[test][neovim]",
        "",
        "[mdnotes][]",
        "[test][mdnotes]",
        "[test][mdnotes]",
        "",
        "[test][]",
        "[test][]",
        "[test][]",
        "",
        "[mdnotes]: https://github.com/ymic9963/mdnotes.nvim",
        "[neovim]: https://www.neovim.io",
        "[test]: https://example.org",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[ return require('mdnotes.reference_link').get_buf_reference_link_definitions() ]])
    eq(ret, {
        {
            destination = "https://github.com/ymic9963/mdnotes.nvim",
            label = "mdnotes",
            lnum = 13
        },
        {
            destination = "https://www.neovim.io",
            label = "neovim",
            lnum = 14
        },
        {
            destination = "https://example.org",
            label = "test",
            lnum = 15
        }
    })

end

T['populate_buf_reference_links()'] = function()
    local lines = {
        "[neovim][]",
        "[test][neovim]",
        "[test][neovim]",
        "",
        "[mdnotes][]",
        "[test][mdnotes]",
        "[test][mdnotes]",
        "",
        "[test][]",
        "[test][]",
        "[test][]",
        "",
        "[mdnotes]: https://github.com/ymic9963/mdnotes.nvim",
        "[neovim]: https://www.neovim.io",
        "[test]: https://example.org",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    require('mdnotes.reference_link').populate_buf_reference_link_definitions()
    return require('mdnotes.reference_link').buf_reference_link_definitions
    ]])
    eq(ret, {
        {
            buf = 2,
            definitions = {
                {
                    destination = "https://github.com/ymic9963/mdnotes.nvim",
                    label = "mdnotes",
                    lnum = 13
                },
                {
                    destination = "https://www.neovim.io",
                    label = "neovim",
                    lnum = 14
                },
                {
                    destination = "https://example.org",
                    label = "test",
                    lnum = 15
                },
            }
        }
    })
end

T['insert()'] = function()
    local lines = {
        "test",
    }
    create_md_buffer(child, lines)


    child.lua([[ require('mdnotes.reference_link').insert({ label = "label", destination = "destination" }) ]])
    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[test][label]",
        "[label]: destination"
    })
end

T['get_rl_definition()'] = function()
    local lines = {
        "[neovim][]",
        "[test][neovim]",
        "[test][neovim]",
        "",
        "[mdnotes][]",
        "[test][mdnotes]",
        "[test][mdnotes]",
        "",
        "[test][]",
        "[test][]",
        "[test][]",
        "",
        "[mdnotes]: https://github.com/ymic9963/mdnotes.nvim",
        "[neovim]: https://www.neovim.io",
        "[test]: https://example.org",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    require('mdnotes.reference_link').populate_buf_reference_link_definitions()
    return require('mdnotes.reference_link').get_rl_definition("test")
    ]])
    eq(ret, {
        destination = "https://example.org",
        label = "test",
        lnum = 15
    })
end

T['go_to_definition()'] = function()
    local lines = {
        "[neovim][]",
        "[test][neovim]",
        "[test][neovim]",
        "",
        "[mdnotes][]",
        "[test][mdnotes]",
        "[test][mdnotes]",
        "",
        "[test][]",
        "[test][]",
        "[test][]",
        "",
        "[mdnotes]: https://github.com/ymic9963/mdnotes.nvim",
        "[neovim]: https://www.neovim.io",
        "[test]: https://example.org",
    }
    create_md_buffer(child, lines)

    child.lua([[
    require('mdnotes.reference_link').populate_buf_reference_link_definitions()
    require('mdnotes.reference_link').go_to_definition({label = "test"})
    ]])
    eq(child.fn.line("."), 15)
end

T['delete()'] = function()
    local lines = {
        "[neovim][]",
        "[test][neovim]",
    }
    create_md_buffer(child, lines)

    child.lua([[
    require('mdnotes.reference_link').delete({location = {lnum = 1}})
    require('mdnotes.reference_link').delete({location = {lnum = 2}})
    ]])
    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "neovim",
        "test"
    })
end

T['get_rl_definition_from_obj()'] = function()
    local ret = child.lua([[ return require('mdnotes.reference_link').get_rl_definition_from_obj({label = "label", destination = "destination"}) ]])
    eq(ret, "[label]: destination")
end

T['update_definition()'] = function()
    local lines = {
        "[neovim][]",
        "[test][neovim]",
        "[test][neovim]",
        "",
        "[mdnotes][]",
        "[test][mdnotes]",
        "[test][mdnotes]",
        "",
        "[test][]",
        "[test][]",
        "[test][]",
        "",
        "[mdnotes]: https://github.com/ymic9963/mdnotes.nvim",
        "[neovim]: https://www.neovim.io",
        "[test]: https://example.org",
    }
    create_md_buffer(child, lines)

    child.lua([[
    require('mdnotes.reference_link').populate_buf_reference_link_definitions()
    require('mdnotes.reference_link').update_definition({label = "test", new_label = "new label", skip_input = true})
    require('mdnotes.reference_link').update_definition({label = "new label", new_destination = "new destination", skip_input = true})
    ]])

    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[neovim][]",
        "[test][neovim]",
        "[test][neovim]",
        "",
        "[mdnotes][]",
        "[test][mdnotes]",
        "[test][mdnotes]",
        "",
        "[test][new label]",
        "[test][new label]",
        "[test][new label]",
        "",
        "[mdnotes]: https://github.com/ymic9963/mdnotes.nvim",
        "[neovim]: https://www.neovim.io",
        "[new label]: new destination",
    })
end

T['cleanup()'] = function()
    local lines = {
        "[test][]",
        "[test][]",
        "[test][]",
        "[test][what]",
        "",
        "[mdnotes]: https://github.com/ymic9963/mdnotes.nvim",
        "[test]: https://example.org",
        "[neovim]: https://www.neovim.io",
    }
    create_md_buffer(child, lines)

    child.lua([[
    require('mdnotes.reference_link').populate_buf_reference_link_definitions()
    require('mdnotes.reference_link').cleanup()
    ]])

    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[test][]",
        "[test][]",
        "[test][]",
        "test",
        "",
        "[test]: https://example.org",
    })
end

T['get_rl_from_obj()'] = function()
    local ret = child.lua([[ return require('mdnotes.reference_link').get_rl_from_obj({text = "text", label = "label"}) ]])
    eq(ret, "[text][label]")
end

T['rename()'] = function()
    local lines = {
        "[test][]",
    }
    create_md_buffer(child, lines)

    child.lua([[ require('mdnotes.reference_link').rename({new_name = "test2"}) ]])

    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[test2][test]",
    })
end

T['relink()'] = function()
    local lines = {
        "[test][]",
    }
    create_md_buffer(child, lines)

    child.lua([[ require('mdnotes.reference_link').relabel({new_label = "label"}) ]])

    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[test][label]",
    })
end

-- test_inline_link.open() handles a lot of the testing
T['open()'] = function()
    local lines = {
        "[file1][]",
        "",
        "[file1]: tests/test-data/files/file1.md",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    require('mdnotes.reference_link').populate_buf_reference_link_definitions()
    return require('mdnotes.reference_link').open()
    ]])
    eq(child.fs.normalize(child.api.nvim_buf_get_name(ret)), vim.fs.normalize(vim.fs.find("file1.md")[1]))
    lines = child.api.nvim_buf_get_lines(ret, 0, -1, false)
    eq(lines, {
        "# File 1",
        "this is file1",
        "",
        "## Section 2",
        "text"
    })
    eq(child.fn.getcurpos()[2], 1)
end

T['convert_from_inline()'] = function()
    local lines = {
        "[file1](tests/test-data/files/file1.md)",
    }
    create_md_buffer(child, lines)

    child.lua([[ require('mdnotes.reference_link').convert_from_inline() ]])

    lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines, {
        "[file1][]",
        "[file1]: tests/test-data/files/file1.md",
    })
end

T['parse_lines()'] = function()
    local lines = {
        "# Heading",
        "",
        "[file1][]",
        "",
        "[file1]: tests/test-data/files/file1.md",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[return require('mdnotes.reference_link').parse_lines({ location = {startl = 1, endl = vim.fn.line("$") }, silent = true }) ]])
    eq(ret, {
        {
            buf = 2,
            col_end = 10,
            col_start = 1,
            cur_col = 5,
            lnum = 3,
            text = "file1",
            label = "file1"
        }
    })
    ret = child.lua([[return require('mdnotes.reference_link').parse_lines({ str = true, location = {startl = 1, endl = vim.fn.line("$") }, silent = true }) ]])
    eq(ret, {"[file1][]"})
end

T['find_label_occurences()'] = function()
    local lines = {
        "[neovim][]",
        "[test][neovim]",
        "[test][neovim]",
        "",
        "[mdnotes][]",
        "[test][mdnotes]",
        "[test][mdnotes]",
        "",
        "[test][]",
        "[test][]",
        "[test][]",
        "",
        "[mdnotes]: https://github.com/ymic9963/mdnotes.nvim",
        "[neovim]: https://www.neovim.io",
        "[test]: https://example.org",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    require('mdnotes.reference_link').populate_buf_reference_link_definitions()
    return require('mdnotes.reference_link').find_label_occurences({label = "test"})
    ]])
    eq(ret, {
        {
            bufnr = 2,
            lnum = 9,
            text = "test"
        }, {
            bufnr = 2,
            lnum = 10,
            text = "test"
        }, {
            bufnr = 2,
            lnum = 11,
            text = "test"
        }
    })
end

return T
