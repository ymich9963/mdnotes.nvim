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
