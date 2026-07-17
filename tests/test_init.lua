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
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['mdn_grep()'] = function()
    child.cmd([[
    edit tests/test-data/files/greptest.md
    cd tests/test-data/files
    ]])

    child.lua([[ require('mdnotes').mdn_grep("greptest", ".") ]])

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
end

T['check_markdown_syntax()'] = function()
    local lines = {
        "*emphasis* emphasis",
        "emphasis *emphasis*",
        "emphasis emphasis",
    }
    create_md_buffer(child, lines)

    child.fn.cursor(1,1)
    local ret = child.lua([[
    local pattern = require('mdnotes.patterns').emphasis
    return {require('mdnotes').check_markdown_syntax(pattern)}
    ]])
    eq(ret, {true, {1, 11}})

    child.fn.cursor(2,1)
    ret = child.lua([[
    local pattern = require('mdnotes.patterns').emphasis
    return {require('mdnotes').check_markdown_syntax(pattern)}
    ]])
    eq(ret, {false, {}})

    ret = child.lua([[
    local pattern = require('mdnotes.patterns').emphasis
    return {require('mdnotes').check_markdown_syntax(pattern, { entire_line = true })}
    ]])
    eq(ret, {true, {{10, 20}}})

    child.fn.cursor(3,1)
    ret = child.lua([[
    local pattern = require('mdnotes.patterns').emphasis
    return {require('mdnotes').check_markdown_syntax(pattern)}
    ]])
    eq(ret, {false, {}})

    ret = child.lua([[
    local pattern = require('mdnotes.patterns').emphasis
    return {require('mdnotes').check_markdown_syntax(pattern, { entire_line = true })}
    ]])
    eq(ret, {false, {}})

    ret = child.lua([[
    local pattern = require('mdnotes.patterns').emphasis
    return {require('mdnotes').check_markdown_syntax(pattern, {location = {lnum = 2, col_start = 10, col_end = 19}})}
    ]])
    eq(ret, {true, {10, 20}})
end

T['get_text()'] = function()
    local lines = {
        "test1 test2",
        "test3 test4",
        "test5 test6",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    return require('mdnotes').get_text({ location = {
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
        text = "test3",
    })

    ret = child.lua([[
    return require('mdnotes').get_text({ location = {
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
        text = "test5",
    })
end

T['get_text_in_pattern()'] = function()
    local lines = {
        "*test1* test2",
        "test3 *test4*",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    local pattern = require('mdnotes.patterns').emphasis
    return require('mdnotes').get_text_in_pattern(pattern, { location = {
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
        text = "",
    })

    ret = child.lua([[
    local pattern = require('mdnotes.patterns').emphasis
    return require('mdnotes').get_text_in_pattern(pattern, { location = {
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
        text = "test1",
    })
end

T['get_files_in_cwd()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes').get_files_in_cwd({ extension = ".md" })
    ]])
    eq(ret, {"file1.md", "file2.md", "file3.md", "file4.md", "file5.md", "file6.md", "file7.md", "greptest.md"})

    ret = child.lua([[
    return require('mdnotes').get_files_in_cwd({ hidden = false, fs_type = "directory"})
    ]])
    eq(ret, {"assets"})

    ret = child.lua([[
    return require('mdnotes').get_files_in_cwd({ extension = ".md", hidden = false, fs_type = "file", pattern = "^.*7.*"})
    ]])
    eq(ret, {"file7.md"})
end

-- Test is based on these rules
-- https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#section-links
T['convert_text_to_gfm()'] = function()
    local ret = child.lua([[
    return require('mdnotes').convert_text_to_gfm("text -/';+123    @💩")
    ]])

    eq(ret, "text-123----")
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
    require('mdnotes').populate_buf_fragments(cur_buf)
    return require('mdnotes').buf_fragments
    ]])
    eq(ret, {
        {
            buf = buf,
            fragments = {
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
            },
        }
    })

    -- Call it again to ensure it doesn't get added
    ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes').populate_buf_fragments(cur_buf)
    return require('mdnotes').buf_fragments
    ]])
    eq(ret, {
        {
            buf = buf,
            fragments = {
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
            },
        }
    })

    -- Set new lines for the same buffer and check if data changes
    child.api.nvim_buf_set_lines(buf, 0, -1, false, {"### Heading 3"})
    ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes').populate_buf_fragments(cur_buf)
    return require('mdnotes').buf_fragments
    ]])
    eq(ret, {
        {
            buf = buf,
            fragments = {
                {
                    hash = "###",
                    text = "Heading 3",
                    gfm = "heading-3",
                    lnum = 1,
                },
            },
        }
    })

    --Create another buffer to test if it is added
    local new_buf = create_md_buffer(child, lines)

    ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes').populate_buf_fragments(cur_buf)
    return require('mdnotes').buf_fragments
    ]])
    eq(ret, {
        {
            buf = buf,
            fragments = {
                {
                    hash = "###",
                    text = "Heading 3",
                    gfm = "heading-3",
                    lnum = 1,
                },
            },
        },
        {
            buf = new_buf,
            fragments = {
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
            },
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
    return require('mdnotes').get_buf_fragments(cur_buf)
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
    require('mdnotes').populate_buf_fragments(cur_buf)
    return require('mdnotes').find_fragment_in_buf_fragments(cur_buf, "heading-1")
    ]])
    eq(ret, "Heading 1")
end

T['scan_lines()'] = function()
    local lines = {
        "[test](link)",
        "",
        "[test](link)",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    local pattern = require('mdnotes.patterns').inline_link
    return require('mdnotes').scan_lines(pattern, { location = { startl = 1, endl = 3}})
    ]])

    eq(ret, {
        {
            lnum = 1,
            cols = { { 1,13 } }
        },
        {
            lnum = 3,
            cols = { { 1,13 } }
        }
    })
end

T['statistics()'] = function()
    local lines = {
        "# Heading",
        "",
        "[test](link)",
        "[[test]]",
        "[test][link]",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[ return require('mdnotes').statistics({ silent = true }) ]])

    if vim.fn.has("win32") == 1 then
        eq(ret, {
            bytes = 51, -- 37 on Windows, 33 on Linux
            chars = 51, -- 37 on Windows, 33 on Linux
            words = 5,
            lines = 5,
            ils = 1,
            wls = 1,
            rls = 1,
            headings = 1
        })
    else
        eq(ret, {
            bytes = 46,
            chars = 46,
            words = 5,
            lines = 5,
            ils = 1,
            wls = 1,
            rls = 1,
            headings = 1
        })
    end
end

T['is_url()'] = function()
    local ret = child.lua([[return require('mdnotes').is_url("link")]])
    eq(ret, false)
    ret = child.lua([[return require('mdnotes').is_url("https://test")]])
    eq(ret, true)
end

T['get_path_from_destination()'] = function()
    local ret = child.lua([[return require('mdnotes').get_path_from_destination("path/with/fragment#fragment", false)]])
    eq(ret, "path/with/fragment")

    child.cmd([[edit tests/test-data/files/file1.md]])
    local cwd = child.lua([[return require('mdnotes').cwd]])

    ret = child.lua([[return require('mdnotes').get_path_from_destination("tests/test-data/files/file1.md#section-2", true)]])
    eq(ret, cwd .. "/file1.md")
    ret = child.lua([[return require('mdnotes').get_path_from_destination("#section-2", true)]])
    eq(ret, "file1.md")
end

T['get_fragment_from_destination()'] = function()
    local ret = child.lua([[return require('mdnotes').get_fragment_from_destination("path/with/fragment#fragment", false)]])
    eq(ret, "fragment")

    ret = child.lua([[return require('mdnotes').get_fragment_from_destination("tests/test-data/files/file1.md#section-2", true)]])
    eq(ret, "Section 2")

    ret = child.lua([[return require('mdnotes').get_fragment_from_destination("tests/test-data/files/file1.md#Section 2", true)]])
    eq(ret, "Section 2")

    child.cmd([[edit tests/test-data/files/file1.md]])
    ret = child.lua([[return require('mdnotes').get_fragment_from_destination("#section-2", true)]])
    eq(ret, "section-2")
end

return T
