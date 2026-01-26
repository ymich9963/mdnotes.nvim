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

T['get_il_data()'] = function()
    -- Setup test buffer
    local lines = {
        "[file1](tests/test-data/files/file1.md) [file2](tests/test-data/files/file2.md)",
        "[file1](tests/test-data/files/file1.md#section-2) [file2](tests/test-data/files/file2.md#file-2)",
        "![image1](tests/test-data/images/neovim-mark-flat.svg) ![image2](tests/test-data/images/neovim-mark.svg)",
        "[url1](https://neovim.io/) [url2](https://neovim.io/doc/user/#Q_ct)",
        "[section](#test-section)",
        "",
        "# Test Section"
    }
    create_md_buffer(child, lines)

    -- Return format here is 
    -- img_char, text, uri, path, fragment, col_start, col_end

    -- File inline links
    child.fn.cursor(1,2)
    local ret = child.lua([[ return {require('mdnotes.inline_link').get_il_data()} ]])
    eq(ret, {
        false,
        "file1",
        "tests/test-data/files/file1.md",
        1,
        40,
    })

    child.fn.cursor(1,42)
    ret = child.lua([[ return {require('mdnotes.inline_link').get_il_data()} ]])
    eq(ret, {
        false,
        "file2",
        "tests/test-data/files/file2.md",
        41,
        80,
    })

    -- File inline links with sections
    child.fn.cursor(2,2)
    ret = child.lua([[ return {require('mdnotes.inline_link').get_il_data()} ]])
    eq(ret, {
        false,
        "file1",
        "tests/test-data/files/file1.md#section-2",
        1,
        50,
    })

    child.fn.cursor(2,60)
    ret = child.lua([[ return {require('mdnotes.inline_link').get_il_data()} ]])
    eq(ret, {
        false,
        "file2",
        "tests/test-data/files/file2.md#file-2",
        51,
        97,
    })

    -- Inline images
    child.fn.cursor(3,2)
    ret = child.lua([[ return {require('mdnotes.inline_link').get_il_data()} ]])
    eq(ret, {
        true,
        "image1",
        "tests/test-data/images/neovim-mark-flat.svg",
        1,
        55,
    })

    child.fn.cursor(3,60)
    ret = child.lua([[ return {require('mdnotes.inline_link').get_il_data()} ]])
    eq(ret, {
        true,
        "image2",
        "tests/test-data/images/neovim-mark.svg",
        56,
        105,
    })

    -- Inline images
    child.fn.cursor(4,2)
    ret = child.lua([[ return {require('mdnotes.inline_link').get_il_data()} ]])
    eq(ret, {
        false,
        "url1",
        "https://neovim.io/",
        1,
        27,
    })

    child.fn.cursor(4,60)
    ret = child.lua([[ return {require('mdnotes.inline_link').get_il_data()} ]])
    eq(ret, {
        false,
        "url2",
        "https://neovim.io/doc/user/#Q_ct",
        28,
        68,
    })

    -- Same file section
    child.fn.cursor(5,2)
    ret = child.lua([[ return {require('mdnotes.inline_link').get_il_data()} ]])
    eq(ret, {
        false,
        "section",
        "#test-section",
        1,
        25,
    })
end

T['get_path_from_uri()'] = function()
    local ret = child.lua([[return require('mdnotes.inline_link').get_path_from_uri("path/with/fragment#fragment", false)]])
    eq(ret, "path/with/fragment")
end

T['get_fragment_from_uri()'] = function()
    local ret = child.lua([[return require('mdnotes.inline_link').get_fragment_from_uri("path/with/fragment#fragment", false)]])
    eq(ret, "fragment")
end

T['open()'] = function()
    local lines = {
        "[file1](tests/test-data/files/file1.md) [file2](tests/test-data/files/file2.md)",
        "[file1](tests/test-data/files/file1.md#section-2) [file2](tests/test-data/files/file2.md#file-2)",
        "![image1](tests/test-data/images/neovim-mark-flat.svg) ![image2](tests/test-data/images/neovim-mark.svg)",
        "[url1](https://neovim.io/) [url2](https://neovim.io/doc/user/#Q_ct)",
        "[section](#test-section)",
        "",
        "# Test Section"
    }
    local buf = create_md_buffer(child, lines)

    child.fn.cursor(2,1)
    local ret = child.lua([[return require('mdnotes.inline_link').open()]])
    lines = child.api.nvim_buf_get_lines(ret, 0, -1, false)
    eq(lines, {
        "# File 1",
        "this is file1",
        "",
        "## Section 2",
        "text"
    })
    eq(child.fn.getcurpos()[2], 4)

    child.cmd("buffer " .. buf)
    child.fn.cursor(5,1)
    child.lua([[require('mdnotes.inline_link').open()]])
    eq(child.fn.getcurpos()[2], 7)
end

T['is_img()'] = function()
    local lines = {
        "[text](link)",
        "![img](link)",
    }

    create_md_buffer(child, lines)
    local ret = child.lua([[return require('mdnotes.inline_link').is_img()]])
    eq(ret, false)
    ret = child.lua([[return require('mdnotes.inline_link').is_img(nil, true)]])
    eq(ret, "")

    child.fn.cursor(2,1)
    ret = child.lua([[return require('mdnotes.inline_link').is_img()]])
    eq(ret, true)
    ret = child.lua([[return require('mdnotes.inline_link').is_img(nil, true)]])
    eq(ret, "!")
end

T['is_url()'] = function()
    local lines = {
        "[text](link)",
        "[text](https://test)",
    }

    create_md_buffer(child, lines)
    local ret = child.lua([[return require('mdnotes.inline_link').is_url()]])
    eq(ret, false)
    child.fn.cursor(2,1)
    ret = child.lua([[return require('mdnotes.inline_link').is_url()]])
    eq(ret, true)
end

T['insert()'] = function()
    local lines = {
        "test"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[require('mdnotes.inline_link').insert("link")]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test](link)")
end

T['delete()'] = function()
    local lines = {
        "[test](link)"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[require('mdnotes.inline_link').delete()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "test")
end

T['toggle()'] = function()
    local lines = {
        "test"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[
    vim.fn.setreg("+", "link", "")
    require('mdnotes.inline_link').toggle()
    ]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test](link)")
    child.lua([[ require('mdnotes.inline_link').toggle() ]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "test")
end

T['relink()/rename()'] = function()
    local lines = {
        "[test](link)"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[require('mdnotes.inline_link').relink("link2")]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test](link2)")
    child.lua([[require('mdnotes.inline_link').rename("test2")]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test2](link2)")
end

T['normalize()'] = function()
    local lines = {
        "[test](link\\ has spaces\\ test)"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[require('mdnotes.inline_link').normalize()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test](<link/ has spaces/ test>)")
end

T['convert_fragment_to_gfm()'] = function()
    local lines = {
        "[test](#Fragment to GFM)",
        "[test](File#Fragment to GFM)"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[require('mdnotes.inline_link').convert_fragment_to_gfm()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test](#fragment-to-gfm)")

    child.fn.cursor(2,1)
    child.lua([[require('mdnotes.inline_link').convert_fragment_to_gfm()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[2], "[test](File#fragment-to-gfm)")
end

return T
