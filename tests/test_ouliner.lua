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

T['get_indent()'] = function()
    -- Setup test buffer
    local lines = {
        "- item",
        " - item",
        "  - item",
        "   - item",
        "text"
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    local indent_tbl = {}
    local line = vim.api.nvim_get_current_line()
    local indent = require('mdnotes.outliner').get_indent(line)
    table.insert(indent_tbl, indent)
    vim.fn.cursor(2,1)

    line = vim.api.nvim_get_current_line()
    indent = require('mdnotes.outliner').get_indent(line)
    table.insert(indent_tbl, indent)
    vim.fn.cursor(3,1)

    line = vim.api.nvim_get_current_line()
    indent = require('mdnotes.outliner').get_indent(line)
    table.insert(indent_tbl, indent)
    vim.fn.cursor(4,1)

    line = vim.api.nvim_get_current_line()
    indent = require('mdnotes.outliner').get_indent(line)
    table.insert(indent_tbl, indent)
    vim.fn.cursor(5,1)

    line = vim.api.nvim_get_current_line()
    indent = require('mdnotes.outliner').get_indent(line)
    table.insert(indent_tbl, indent)

    return indent_tbl
    ]])

    eq(ret, {0, 1, 2, 3, 0})
end

T['get_list_lines()'] = function()
    -- Setup test buffer
    local lines = {
        "- item",
        " - item",
        "  - item",
        "   - item",
        "text",
        "- item",
        " - item",
        "  - item",
        "   - item",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    return require('mdnotes.outliner').get_cur_list_items()
    ]])

    eq(ret, {
        "- item",
        " - item",
        "  - item",
        "   - item",
    })
end

T['indent()'] = function()
    -- Setup test buffer
    local lines = {
        "- item",
        "  - item",
        "  - item",
        "    - item",
    }
    local buf = create_md_buffer(child, lines)

    child.lua([[ require('mdnotes.outliner').indent() ]])

    local new_lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    child.fn.cursor(1,1)
    eq(new_lines, {
        (" "):rep(child.o.shiftwidth) .. "- item",
        (" "):rep(child.o.shiftwidth) .. "  - item",
        (" "):rep(child.o.shiftwidth) .. "  - item",
        (" "):rep(child.o.shiftwidth) .. "    - item",
    })

    buf = create_md_buffer(child, lines)
    child.fn.cursor(2,1)
    child.lua([[ require('mdnotes.outliner').indent() ]])
    new_lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(new_lines, {
        "- item",
        (" "):rep(child.o.shiftwidth) .. "  - item",
        "  - item",
        "    - item",
    })

    buf = create_md_buffer(child, lines)
    child.fn.cursor(3,1)
    child.lua([[ require('mdnotes.outliner').indent() ]])
    new_lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(new_lines, {
        "- item",
        "  - item",
        (" "):rep(child.o.shiftwidth) .. "  - item",
        (" "):rep(child.o.shiftwidth) .. "    - item",
    })
end

T['unindent()'] = function()
    -- Setup test buffer
    -- Line indentation here must be at least of child.o.shiftwidth
    local lines = {
        "- item",
        "    - item",
        "    - item",
        "        - item",
    }

    local buf = create_md_buffer(child, lines)
    child.fn.cursor(1,1)
    child.lua([[ require('mdnotes.outliner').unindent() ]])
    local new_lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(new_lines, {
        "- item",
        (" "):rep(1 * child.o.shiftwidth) .. "- item",
        (" "):rep(1 * child.o.shiftwidth) .. "- item",
        (" "):rep(2 * child.o.shiftwidth) .. "- item",
    })

    buf = create_md_buffer(child, lines)
    child.fn.cursor(2,1)
    child.lua([[ require('mdnotes.outliner').unindent() ]])
    new_lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(new_lines, {
        "- item",
        "- item",
        (" "):rep(1 * child.o.shiftwidth) .. "- item",
        (" "):rep(2 * child.o.shiftwidth) .. "- item",
    })

    buf = create_md_buffer(child, lines)
    child.fn.cursor(3,1)
    child.lua([[ require('mdnotes.outliner').unindent() ]])
    new_lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(new_lines, {
        "- item",
        (" "):rep(1 * child.o.shiftwidth) .. "- item",
        "- item",
        (" "):rep(1 * child.o.shiftwidth) .. "- item",
    })
end

return T
