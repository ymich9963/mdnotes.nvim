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

T['parse()'] = function()
    -- Setup test buffer
    local lines = {
        "[file1](tests/test-data/files/file1.md) [file2](tests/test-data/files/file2.md)",
        "[file1](tests/test-data/files/file1.md#section-2) [file2](tests/test-data/files/file2.md#file-2)",
        "![image1](tests/test-data/images/neovim-mark-flat.svg) ![image2](tests/test-data/images/neovim-mark.svg)",
        "[url1](https://neovim.io/) [url2](https://neovim.io/doc/user/#Q_ct)",
        "[section](#test-section)",
        "[section](#test-section \"title\")",
        "",
        "# Test Section"
    }
    create_md_buffer(child, lines)

    -- File inline links
    child.fn.cursor(1,2)
    local ret = child.lua([[ return Mdn.inline_link.parse() ]])
    eq(ret, {
        img_char = "",
        text = "file1",
        destination = "tests/test-data/files/file1.md",
        buf = 2,
        lnum = 1,
        col_start = 1,
        col_end = 40,
        cur_col = 2,
        title = "",
        raw = "[file1](tests/test-data/files/file1.md)",
    })

    child.fn.cursor(1,42)
    ret = child.lua([[ return Mdn.inline_link.parse() ]])
    eq(ret, {
        img_char = "",
        text = "file2",
        destination = "tests/test-data/files/file2.md",
        buf = 2,
        lnum = 1,
        col_start = 41,
        col_end = 80,
        cur_col = 42,
        title = "",
        raw = "[file2](tests/test-data/files/file2.md)",
    })

    -- File inline links with sections
    child.fn.cursor(2,2)
    ret = child.lua([[ return Mdn.inline_link.parse() ]])
    eq(ret, {
        img_char = "",
        text = "file1",
        destination = "tests/test-data/files/file1.md#section-2",
        buf = 2,
        lnum = 2,
        col_start = 1,
        col_end = 50,
        cur_col = 2,
        title = "",
        raw = "[file1](tests/test-data/files/file1.md#section-2)"
    })

    child.fn.cursor(2,60)
    ret = child.lua([[ return Mdn.inline_link.parse() ]])
    eq(ret, {
        img_char = "",
        text = "file2",
        destination = "tests/test-data/files/file2.md#file-2",
        buf = 2,
        lnum = 2,
        col_start = 51,
        col_end = 97,
        cur_col = 60,
        title = "",
        raw = "[file2](tests/test-data/files/file2.md#file-2)"
    })

    -- Inline images
    child.fn.cursor(3,2)
    ret = child.lua([[ return Mdn.inline_link.parse() ]])
    eq(ret, {
        img_char = "!",
        text = "image1",
        destination = "tests/test-data/images/neovim-mark-flat.svg",
        buf = 2,
        lnum = 3,
        col_start = 1,
        col_end = 55,
        cur_col = 2,
        title = "",
        raw = "![image1](tests/test-data/images/neovim-mark-flat.svg)"
    })

    child.fn.cursor(3,60)
    ret = child.lua([[ return Mdn.inline_link.parse() ]])
    eq(ret, {
        img_char = "!",
        text = "image2",
        destination = "tests/test-data/images/neovim-mark.svg",
        buf = 2,
        lnum = 3,
        col_start = 56,
        col_end = 105,
        cur_col = 60,
        title = "",
        raw = "![image2](tests/test-data/images/neovim-mark.svg)",
    })

    child.fn.cursor(4,2)
    ret = child.lua([[ return Mdn.inline_link.parse() ]])
    eq(ret, {
        img_char = "",
        text = "url1",
        destination = "https://neovim.io/",
        buf = 2,
        lnum = 4,
        col_start = 1,
        col_end = 27,
        cur_col = 2,
        title = "",
        raw = "[url1](https://neovim.io/)",
    })

    child.fn.cursor(4,60)
    ret = child.lua([[ return Mdn.inline_link.parse() ]])
    eq(ret, {
        img_char = "",
        text = "url2",
        destination = "https://neovim.io/doc/user/#Q_ct",
        buf = 2,
        lnum = 4,
        col_start = 28,
        col_end = 68,
        cur_col = 60,
        title = "",
        raw = "[url2](https://neovim.io/doc/user/#Q_ct)",
    })

    -- Same file section
    child.fn.cursor(5,2)
    ret = child.lua([[ return Mdn.inline_link.parse() ]])
    eq(ret, {
        img_char = "",
        text = "section",
        destination = "#test-section",
        buf = 2,
        lnum = 5,
        col_start = 1,
        col_end = 25,
        cur_col = 2,
        title = "",
        raw = "[section](#test-section)",
    })

    child.fn.cursor(6,2)
    ret = child.lua([[ return Mdn.inline_link.parse() ]])
    eq(ret, {
        img_char = "",
        text = "section",
        destination = "#test-section",
        buf = 2,
        lnum = 6,
        col_start = 1,
        col_end = 33,
        cur_col = 2,
        title = "title",
        raw = "[section](#test-section \"title\")",
    })
end

T['get_il_from_obj()'] = function()
    local ret = child.lua([[return Mdn.inline_link.get_il_from_obj({img_char = "", text = 1, destination = 2})]])
    eq(ret, "[1](2)")
    ret = child.lua([[return Mdn.inline_link.get_il_from_obj({img_char = "", text = 1, destination = 2, title = 3})]])
    eq(ret, "[1](2 \"3\")")
    ret = child.lua([[return Mdn.inline_link.get_il_from_obj({img_char = "", text = 1, destination = "spaces test", title = 3})]])
    eq(ret, "[1](<spaces test> \"3\")")
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
    local ret = nil

    child.fn.cursor(1,1)
    ret = child.lua([[return Mdn.inline_link.open()]])
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

    child.cmd("buffer " .. buf)
    child.lua([[return Mdn.set_cwd()]]) -- Autocmd does not get triggered so call manually
    child.fn.cursor(2,1)
    ret = child.lua([[return Mdn.inline_link.open()]])
    eq(child.fs.normalize(child.api.nvim_buf_get_name(ret)), vim.fs.normalize(vim.fs.find("file1.md")[1]))
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
    child.lua([[ Mdn.inline_link.open()]])
    eq(child.fn.getcurpos()[2], 7)
end

T['is_image()'] = function()
    local ret = child.lua([[return Mdn.inline_link.is_image("[text](link)")]])
    eq(ret, false)
    ret = child.lua([[return Mdn.inline_link.is_image("![img](link)")]])
    eq(ret, true)
end

T['insert()'] = function()
    local lines = {
        "test"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[Mdn.inline_link.insert({ destination = "link" })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test](link)")
end

T['delete()'] = function()
    local lines = {
        "[test](link)"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[Mdn.inline_link.delete()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "test")
end

T['toggle()'] = function()
    local lines = {
        "test"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[
    Mdn.inline_link.toggle({ destination = "link" })
    ]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test](link)")
    child.lua([[ Mdn.inline_link.toggle() ]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "test")
end

T['relink()/rename()'] = function()
    local lines = {
        "[test](link)",
        "[test](<link with spaces>)"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[Mdn.inline_link.relink({ new_link = "link2" })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test](link2)")
    child.lua([[Mdn.inline_link.rename({ new_name = "test2" })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test2](link2)")

    child.fn.cursor(2,1)
    child.lua([[Mdn.inline_link.relink({ new_link = "link with spaces2" })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[2], "[test](<link with spaces2>)")
    child.lua([[Mdn.inline_link.rename({ new_name = "test2" })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[2], "[test2](<link with spaces2>)")
    child.lua([[Mdn.inline_link.relink({ new_link = "link2" })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[2], "[test2](link2)")
end

T['normalize()'] = function()
    local lines = {
        "[test](link/ has spaces/ test)"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[Mdn.inline_link.normalize()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test](<link/ has spaces/ test>)")
end

T['convert_fragment_to_gfm()'] = function()
    local lines = {
        "[test](#Fragment to GFM)",
        "[test](File#Fragment to GFM)"
    }

    local buf = create_md_buffer(child, lines)
    child.lua([[Mdn.inline_link.convert_fragment_to_gfm()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[test](#fragment-to-gfm)")

    child.fn.cursor(2,1)
    child.lua([[Mdn.inline_link.convert_fragment_to_gfm()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[2], "[test](File#fragment-to-gfm)")
end

T['parse_lines()'] = function()
    local lines = {
        "# Heading",
        "",
        "[test](link)",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[return Mdn.inline_link.parse_lines({ location = {startl = 1, endl = vim.fn.line("$") }, silent = true }) ]])
    eq(ret, {
        {
            buf = 2,
            col_end = 13,
            col_start = 1,
            cur_col = 7,
            img_char = "",
            lnum = 3,
            text = "test",
            title = "",
            destination = "link",
            raw = "[test](link)"
        }
    })
    ret = child.lua([[return Mdn.inline_link.parse_lines({ str = true, location = {startl = 1, endl = vim.fn.line("$") }, silent = true }) ]])
    eq(ret, {"[test](link)"})
end

return T
