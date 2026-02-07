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

T['get_wikilink_data()'] = function()
    local ret = child.lua("return {require('mdnotes.wikilink').get_wikilink_data('[[test#fragment]]')}")
    eq(ret, {
        "test#fragment",
        "test",
        "fragment",
        0, 0
    })
end

T['follow()'] = function()
    local lines = {}
    child.cmd([[edit tests/test-data/files/file3.md]])
    child.lua([[require('mdnotes').set_cwd()]])
    child.fn.cursor(2,1)
    child.lua([[require('mdnotes.wikilink').follow()]])
    local buf = child.api.nvim_get_current_buf()
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "# File 2")
end

T['show_references()'] = function()
    child.cmd([[edit tests/test-data/files/file2.md]])
    child.fn.cursor(1,1)
    local ret = child.lua([[return require('mdnotes.wikilink').show_references()]])
    eq(ret, {
        {
            bufnr = 3,
            col = 1,
            end_col = 10,
            end_lnum = 2,
            lnum = 2,
            module = "",
            nr = 0,
            pattern = "",
            text = "[[file2]]",
            type = "",
            valid = 1,
            vcol = 0
        }
    })
    child.cmd("ccl")
    eq(vim.fs.basename(child.api.nvim_buf_get_name(0)), "file2.md")

    child.cmd([[edit tests/test-data/files/file3.md]])
    child.fn.cursor(2,1)
    ret = child.lua([[return require('mdnotes.wikilink').show_references()]])
    eq(ret, {
        {
            bufnr = 3,
            col = 1,
            end_col = 10,
            end_lnum = 2,
            lnum = 2,
            module = "",
            nr = 0,
            pattern = "",
            text = "[[file2]]",
            type = "",
            valid = 1,
            vcol = 0
        }
    })
end

T['rename_references()'] = function()
    -- Rename file3 to file33
    child.cmd([[edit tests/test-data/files/file4.md]])
    child.fn.cursor(2,1)
    local ret = child.lua([[return {require('mdnotes.wikilink').rename_references("file55")}]])
    eq(ret, {"file5", "file55"})
    local lines = child.api.nvim_buf_get_lines(child.api.nvim_get_current_buf(), 0, -1, false)
    eq(lines[2], "[[file55]]")
    eq(lines[3], "[[file55]]")
    eq(lines[4], "[[file55.md]]")
    eq(lines[5], "[[file55#File 5]]")

    child.cmd([[edit tests/test-data/files/file55.md]])
    lines = child.api.nvim_buf_get_lines(child.api.nvim_get_current_buf(), 0, -1, false)
    eq(lines[1], "# File 5")

    -- Rename back to file3
    child.fn.cursor(2,1)
    child.cmd([[edit tests/test-data/files/file4.md]])
    child.lua([[require('mdnotes.wikilink').rename_references("file5")]])

    -- Self rename
    child.fn.cursor(1,1)
    ret = child.lua([[return {require('mdnotes.wikilink').rename_references("file44")}]])
    eq(ret, {"file4", "file44"})
    eq(vim.fs.basename(child.api.nvim_buf_get_name(0)), "file44.md")
    child.lua([[require('mdnotes.wikilink').rename_references("file4")]])
    eq(vim.fs.basename(child.api.nvim_buf_get_name(0)), "file4.md")
end

T['undo_rename()'] = function()
    -- Rename file3 to file33
    child.cmd([[edit tests/test-data/files/file4.md]])
    child.fn.cursor(2,1)
    local ret = child.lua([[return {require('mdnotes.wikilink').rename_references("file55")}]])
    eq(ret, {"file5", "file55"})

    ret = child.lua([[return {require('mdnotes.wikilink').undo_rename()}]])
    eq(ret, {"file55", "file5"})
end

T['create()'] = function()
    local lines = {
        "Test"
    }
    create_md_buffer(child, lines)

    child.fn.cursor(1,1)
    child.lua([[require('mdnotes.wikilink').create()]])
    lines = child.api.nvim_buf_get_lines(child.api.nvim_get_current_buf(), 0, -1, false)
    eq(lines[1], "[[Test]]")
end

T['delete()'] = function()
    local lines = {
        "[[./tests/test-data/files/file6]]"
    }
    local buf = create_md_buffer(child, lines)

    eq(
        vim.fs.basename(vim.fs.find("file6.md", { path = './tests/test-data/files' })[1]),
        "file6.md"
    )
    child.lua([[require('mdnotes.wikilink').delete(true)]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "./tests/test-data/files/file6")
    eq(vim.fs.find("file6.md", { path = './tests/test-data/files' }), {})
    child.cmd([[ edit tests/test-data/files/file6.md ]])
    child.cmd([[ write ]])
end

T['normalize()'] = function()
    local lines = {
        "[[.\\tests\\test-data\\files\\file6]]"
    }
    local buf = create_md_buffer(child, lines)
    child.lua([[require('mdnotes.wikilink').normalize()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "[[tests/test-data/files/file6]]")
end

T['find_orphans()'] = function()
    -- Move to directory to search
    child.cmd([[edit tests/test-data/files/file1.md]])
    local ret = child.lua([[return require('mdnotes.wikilink').find_orphans()]])
    eq(ret, {
        "file1.md",
        "file3.md",
        "file4.md",
        "file6.md",
        "file7.md",
    })
end

return T
