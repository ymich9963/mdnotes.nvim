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

-- Test for doc help tags
T['docs'] = function()
    child.cmd([[helptags doc/]])
end
T['mdn_grep()'] = function()
    child.cmd([[
    edit tests/test-data/files/greptest.md
    cd tests/test-data/files
    ]])

    child.lua([[ Mdn.mdn_grep("greptest", Mdn.cwd) ]])

    if child.o.grepprg == "internal" then
        eq(child.fn.getqflist(), { {
            bufnr = 1,
            col = 1,
            end_col = 9,
            end_lnum = 4,
            lnum = 4,
            module = "",
            nr = 0,
            pattern = "",
            text = "greptest",
            type = "",
            valid = 1,
            vcol = 0
        } })
    else
        eq(child.fn.getqflist(), { {
            bufnr = 1,
            col = 1,
            end_col = 0,
            end_lnum = 0,
            lnum = 4,
            module = "",
            nr = -1,
            pattern = "",
            text = "greptest",
            type = "",
            valid = 1,
            vcol = 0
        } })
    end

    child.lua([[ Mdn.mdn_grep("file1", Mdn.cwd) ]])

    if child.o.grepprg == "internal" then
        eq(child.fn.getqflist(), { {
            bufnr = 10,
            col = 9,
            end_col = 14,
            end_lnum = 2,
            lnum = 2,
            module = "",
            nr = 0,
            pattern = "",
            text = "this is file1",
            type = "",
            valid = 1,
            vcol = 0
        } })
    else
        eq(child.fn.getqflist(), { {
            bufnr = 2,
            col = 9,
            end_col = 0,
            end_lnum = 0,
            lnum = 2,
            module = "",
            nr = -1,
            pattern = "",
            text = "this is file1",
            type = "",
            valid = 1,
            vcol = 0
        } })
    end
end

T['check_inline_markdown_syntax()'] = new_set({
    parametrize = {
        { '_re(pattern' },
        { '_ts("emphasis"' }
    }
})

T['check_inline_markdown_syntax()']['impl'] = function(suffix)
    local lines = {
        "*emphasis* emphasis",
        "emphasis *emphasis*",
        "emphasis emphasis",
    }
    create_md_buffer(child, lines)

    child.fn.cursor(1,1)
    local ret = child.lua([[
    local pattern = Mdn.patterns.emphasis
    return {Mdn.check_inline_markdown_syntax]] .. suffix .. [[)}
    ]])
    eq(ret, {true, {col_start = 1, col_end = 11, lnum = 1}})

    child.fn.cursor(2,1)
    ret = child.lua([[
    local pattern = Mdn.patterns.emphasis
    return {Mdn.check_inline_markdown_syntax]] .. suffix .. [[)}
    ]])
    eq(ret, {false, {}})

    ret = child.lua([[
    local pattern = Mdn.patterns.emphasis
    return {Mdn.check_inline_markdown_syntax]] .. suffix .. [[, { entire_line = true })}
    ]])
    eq(ret, {true, {{col_start = 10, col_end = 20, lnum = 2}}})

    child.fn.cursor(3,1)
    ret = child.lua([[
    local pattern = Mdn.patterns.emphasis
    return {Mdn.check_inline_markdown_syntax]] .. suffix .. [[)}
    ]])
    eq(ret, {false, {}})

    ret = child.lua([[
    local pattern = Mdn.patterns.emphasis
    return {Mdn.check_inline_markdown_syntax]] .. suffix .. [[, { entire_line = true })}
    ]])
    eq(ret, {false, {}})

    ret = child.lua([[
    local pattern = Mdn.patterns.emphasis
    return {Mdn.check_inline_markdown_syntax]] .. suffix .. [[, {location = {lnum = 2, col_start = 10, col_end = 19}})}
    ]])
    eq(ret, {true, {col_start = 10, col_end = 20, lnum = 2}})
end

T['get_text()'] = function()
    local lines = {
        "test1 test2",
        "test3 test4",
        "test5 test6",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    return Mdn.get_text({ location = {
        buf = vim.api.nvim_get_current_buf(),
        lnum = 2,
        col_start = 1,
        col_end = 5,
    } })
    ]])
    eq(ret, {
        buf = 2,
        lnum = 2,
        col_start = 1,
        col_end = 5,
        cur_col = 1,
        raw = "test3",
    })

    ret = child.lua([[
    return Mdn.get_text({ location = {
        buf = vim.api.nvim_get_current_buf(),
        lnum = 3,
        col_start = 1,
        col_end = 1,
    } })
    ]])
    eq(ret, {
        buf = 2,
        lnum = 3,
        col_start = 1,
        col_end = 5,
        cur_col = 1,
        raw = "test5",
    })

    -- Test for linewise-visual prior to get_text() in normal mode
    local esc = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
    child.api.nvim_feedkeys("V" .. esc, "n", false)
    ret = child.lua([[
    return Mdn.get_text({ location = {
        buf = vim.api.nvim_get_current_buf(),
        lnum = 1,
        cur_col = 7,
    } })
    ]])
    eq(ret, {
        buf = 2,
        lnum = 1,
        col_end = 11,
        col_start = 7,
        cur_col = 7,
        raw = "test2",
    })
end

T['get_text_in_pattern()'] = function()
    local lines = {
        "*test1* test2",
        "test3 *test4*",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    local pattern = Mdn.patterns.emphasis
    return Mdn.get_text_in_pattern(pattern, { location = {
        buf = vim.api.nvim_get_current_buf(),
        lnum = 2,
        col_start = 1,
        col_end = 5,
    } })
    ]])
    eq(ret, {
        buf = 2,
        lnum = 2,
        col_start = 1,
        col_end = 5,
        cur_col = 3,
        raw = "",
    })

    ret = child.lua([[
    local pattern = Mdn.patterns.emphasis
    return Mdn.get_text_in_pattern(pattern, { location = {
        buf = vim.api.nvim_get_current_buf(),
        lnum = 1,
        col_start = 1,
        col_end = 1,
    } })
    ]])
    eq(ret, {
        buf = 2,
        lnum = 1,
        col_start = 1,
        col_end = 8,
        cur_col = 1,
        raw = "*test1*",
    })
end

T['get_files_in_cwd()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    Mdn.set_cwd()
    Mdn.get_garbage_dir()
    return Mdn.get_files_in_cwd({ extension = ".md" })
    ]])
    eq(ret, {
        "file1.md",
        "file2.md",
        "file3.md",
        "file4.md",
        "file5.md",
        "file6.md",
        "file7.md",
        "file8.md",
        "greptest.md"
    })

    ret = child.lua([[
    return Mdn.get_files_in_cwd({ hidden = false, fs_type = "directory"})
    ]])
    eq(ret, {
        "assets",
        "garbage",
        "nested-dir"
    })

    ret = child.lua([[
    return Mdn.get_files_in_cwd({ extension = ".md", hidden = false, fs_type = "file", pattern = "^.*7.*"})
    ]])
    eq(ret, {
        "file7.md"
    })

    ret = child.lua([[
    return Mdn.get_files_in_cwd({ hidden = true })
    ]])
    eq(ret, {
        ".hidden.md",
        "assets",
        "file1.md",
        "file2.md",
        "file3.md",
        "file4.md",
        "file5.md",
        "file6.md",
        "file7.md",
        "file8.md",
        "garbage",
        "greptest.md",
        "nested-dir"
    })
end

-- Test is based on these rules
-- https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#section-links
T['convert_text_to_gfm()'] = function()
    local ret = child.lua([[
    return Mdn.convert_text_to_gfm("text -/';+123    @💩")
    ]])

    eq(ret, "text--123----")
end

T['populate_buf_fragments()'] = function()
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
    Mdn.populate_buf_fragments(cur_buf)
    return Mdn.buf_fragments
    ]])
    eq(ret, {
        vim.NIL,
        {
            {
                gfm = "heading-1",
                hash = "#",
                lnum = 1,
                text = "Heading 1"
            }, {
                gfm = "heading-2",
                hash = "##",
                lnum = 4,
                text = "Heading 2"
            }
        }
    })

    -- Call it again to ensure it doesn't get added
    ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    Mdn.populate_buf_fragments(cur_buf)
    return Mdn.buf_fragments
    ]])
    eq(ret, {
        vim.NIL, -- buf 1
        {
            {
                gfm = "heading-1",
                hash = "#",
                lnum = 1,
                text = "Heading 1"
            }, {
                gfm = "heading-2",
                hash = "##",
                lnum = 4,
                text = "Heading 2"
            }
        }
    })

    -- Set new lines for the same buffer and check if data changes
    child.api.nvim_buf_set_lines(buf, 0, -1, false, {"### Heading 3"})
    ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    Mdn.populate_buf_fragments(cur_buf)
    return Mdn.buf_fragments
    ]])
    eq(ret, {
        vim.NIL, -- buf 1
        {
            {
                hash = "###",
                text = "Heading 3",
                gfm = "heading-3",
                lnum = 1,
            },
        }
    })

    --Create another buffer to test if it is added
    create_md_buffer(child, lines)

    ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    Mdn.populate_buf_fragments(cur_buf)
    return Mdn.buf_fragments
    ]])
    eq(ret, {
        vim.NIL, -- buf 1
        {
            {
                hash = "###",
                text = "Heading 3",
                gfm = "heading-3",
                lnum = 1,
            },
        },
        {
            {
                hash = "#",
                text = "Heading 1",
                gfm = "heading-1",
                lnum = 1,
            },
            {
                hash = "##",
                text = "Heading 2",
                gfm = "heading-2",
                lnum = 4,
            }
        }
    })
end


T['get_buf_fragments()'] = function()
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
    local cur_buf = vim.api.nvim_get_current_buf()
    return Mdn.get_buf_fragments({ buf = cur_buf })
    ]])
    eq(ret, {
        {
            hash = "#",
            text = "Heading 1",
            gfm = "heading-1",
            lnum = 1,
        },
        {
            hash = "##",
            text = "Heading 2",
            gfm = "heading-2",
            lnum = 4,
        }
    })
end

T['find_fragment_in_buf_fragments()'] = function()
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
    local cur_buf = vim.api.nvim_get_current_buf()
    Mdn.populate_buf_fragments(cur_buf)
    return Mdn.find_fragment_in_buf_fragments(cur_buf, "heading-1")
    ]])
    eq(ret, "Heading 1")
end

T['statistics()'] = function()
    local lines = {
        "# Heading",
        "",
        "[test](link)",
        "[[test]]",
        "[test][link]",
        "[^1]",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[ return Mdn.statistics({ silent = true }) ]])

    if vim.fn.has("win32") == 1 then
        eq(ret, {
            bytes = 57,
            chars = 57,
            words = 6,
            lines = 6,
            ils = 1,
            wls = 1,
            rls = 1,
            frefs = 1,
            headings = 1
        })
    else
        eq(ret, {
            bytes = 51,
            chars = 51,
            words = 6,
            lines = 6,
            ils = 1,
            wls = 1,
            rls = 1,
            frefs = 1,
            headings = 1
        })
    end
end

T['is_url()'] = function()
    local ret = child.lua([[return Mdn.is_url("link")]])
    eq(ret, false)
    ret = child.lua([[return Mdn.is_url("https://test")]])
    eq(ret, true)
end

T['get_path_from_destination()'] = function()
    local ret = child.lua([[return Mdn.get_path_from_destination("path/with/fragment#fragment", false)]])
    eq(ret, "path/with/fragment")

    child.cmd([[edit tests/test-data/files/file1.md]])
    local cwd = child.lua([[return Mdn.cwd]])

    ret = child.lua([[return Mdn.get_path_from_destination("tests/test-data/files/file1.md#section-2", true)]])
    eq(ret, cwd .. "/file1.md")
    ret = child.lua([[return Mdn.get_path_from_destination("#section-2", true)]])
    eq(ret, "file1.md")
end

T['get_fragment_from_destination()'] = function()
    local ret = child.lua([[return Mdn.get_fragment_from_destination("path/with/fragment#fragment", false)]])
    eq(ret, "fragment")

    ret = child.lua([[return Mdn.get_fragment_from_destination("tests/test-data/files/file1.md#section-2", true)]])
    eq(ret, "Section 2")

    ret = child.lua([[return Mdn.get_fragment_from_destination("tests/test-data/files/file1.md#Section 2", true)]])
    eq(ret, "Section 2")

    child.cmd([[edit tests/test-data/files/file1.md]])
    ret = child.lua([[return Mdn.get_fragment_from_destination("#section-2", true)]])
    eq(ret, "section-2")
end

return T
