local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local helpers = require('tests/helpers')
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

T['emphasis'] = function()
    -- Setup test buffer
    local lines = {"emphasis"}
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[require('mdnotes.formatting').emphasis_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "*emphasis*")
    eq(child.fn.getcurpos()[3], 2)

    child.lua([[require('mdnotes.formatting').emphasis_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "emphasis")
    eq(child.fn.getcurpos()[3], 1)
end

T['strong'] = function()
    -- Setup test buffer
    local lines = {"strong"}
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[require('mdnotes.formatting').strong_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "**strong**")
    eq(child.fn.getcurpos()[3], 3)

    child.lua([[require('mdnotes.formatting').strong_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "strong")
    eq(child.fn.getcurpos()[3], 1)
end

T['strikethrough'] = function()
    -- Setup test buffer
    local lines = {"strikethrough"}
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[require('mdnotes.formatting').strikethrough_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "~~strikethrough~~")
    eq(child.fn.getcurpos()[3], 3)

    child.lua([[require('mdnotes.formatting').strikethrough_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "strikethrough")
    eq(child.fn.getcurpos()[3], 1)
end

T['inline_code'] = function()
    -- Setup test buffer
    local lines = {"inline_code"}
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[require('mdnotes.formatting').inline_code_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "`inline_code`")
    eq(child.fn.getcurpos()[3], 2)

    child.lua([[require('mdnotes.formatting').inline_code_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "inline_code")
    eq(child.fn.getcurpos()[3], 1)
end

T['autolink'] = function()
    -- Setup test buffer
    local lines = {"autolink"}
    local buf = create_md_buffer(child, lines)

    -- Check toggling and cursor pos
    child.lua([[require('mdnotes.formatting').autolink_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "<autolink>")
    eq(child.fn.getcurpos()[3], 2)

    child.lua([[require('mdnotes.formatting').autolink_toggle()]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1], "autolink")
    eq(child.fn.getcurpos()[3], 1)
end

T['unordered_list'] = function()
    for _, ul_indicator in ipairs(helpers.unordered_list_indicators) do
        local lines = {ul_indicator .. " item"}
        local buf = create_md_buffer(child, lines)

        child.lua([[require('mdnotes').new_line_remap('o')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {ul_indicator .. " item", ul_indicator .. "  "})

        child.lua([[require('mdnotes').new_line_remap('<CR>')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {ul_indicator .. " item", ul_indicator .. "  ", ""})

        child.api.nvim_input("<ESC>kk")
        child.lua([[require('mdnotes').new_line_remap('O')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {ul_indicator .. "  ", ul_indicator .. " item", ul_indicator .. "  ", ""})

        child.api.nvim_input("<ESC>")
    end
end

T['ordered_list'] = function()
    for _, ol_indicator in ipairs(helpers.ordered_list_indicators) do
        local lines = {"1" .. ol_indicator .. " item"}
        local buf = create_md_buffer(child, lines)

        child.lua([[require('mdnotes').new_line_remap('o')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " item",
            "2" .. ol_indicator .. "  "
        })

        child.lua([[require('mdnotes').new_line_remap('<CR>')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " item",
            "2" .. ol_indicator .. "  ",
            ""
        })

        child.api.nvim_input("<ESC>kk")
        child.lua([[require('mdnotes').new_line_remap('O')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "0" .. ol_indicator .. "  ",
            "1" .. ol_indicator .. " item",
            "2" .. ol_indicator .. "  ",
            ""
        })

        child.api.nvim_input("<ESC>")

        child.lua([[require('mdnotes.formatting').ordered_list_renumber()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. "  ",
            "2" .. ol_indicator .. " item",
            "3" .. ol_indicator .. "  ",
            ""
        })
    end
end

T['task_list'] = function()
    for _, ul_indicator in ipairs(helpers.unordered_list_indicators) do
        local lines = {ul_indicator .. " item"}
        local buf = create_md_buffer(child, lines)

        child.lua([[require('mdnotes.formatting').task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            ul_indicator .. " [ ] item",
        })

        child.lua([[require('mdnotes.formatting').task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            ul_indicator .. " [x] item",
        })

        child.lua([[require('mdnotes.formatting').task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            ul_indicator .. " item",
        })

        child.lua([[require('mdnotes.formatting').task_list_toggle()]])
        child.lua([[require('mdnotes').new_line_remap('o')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            ul_indicator .. " [ ] item",
            ul_indicator .. " [ ]  ",
        })

        child.api.nvim_input("<ESC>")
    end

    for _, ol_indicator in ipairs(helpers.ordered_list_indicators) do
        local lines = {"1" .. ol_indicator .. " item"}
        local buf = create_md_buffer(child, lines)

        child.lua([[require('mdnotes.formatting').task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " [ ] item",
        })

        child.lua([[require('mdnotes.formatting').task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " [x] item",
        })

        child.lua([[require('mdnotes.formatting').task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " item",
        })

        child.lua([[require('mdnotes.formatting').task_list_toggle()]])
        child.lua([[require('mdnotes').new_line_remap('o')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " [ ] item",
            "2" .. ol_indicator .. " [ ]  ",
        })

        child.api.nvim_input("<ESC>")
    end
end

return T
