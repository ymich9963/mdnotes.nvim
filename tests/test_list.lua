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
            child.lua([[require('mdnotes').setup()]])
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['parse_list_item()'] = new_set({
    parametrize = {
        { '_re' },
        { '_ts' }
    }
})

T['parse_list_item()']['impl'] = function(suffix)
    local lines = {
        "- item",
        "- [ ] item",
        "- [x] item",
        "1. item",
        "2. [ ] item",
        "3. [x] item",
        "",
        "  - item",
        "    - item",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[
    local line = vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]
    return Mdn.list.parse_list_item]] .. suffix .. [[(line)
    ]])
    eq(ret, {
        indent = "",
        marker = "-",
        separator = "",
        text = "item",
        type = "unordered",
        task_state = ""
    })

    ret = child.lua([[
    local line = vim.api.nvim_buf_get_lines(0, 0, -1, false)[2]
    return Mdn.list.parse_list_item]] .. suffix .. [[(line)
    ]])
    eq(ret, {
        indent = "",
        marker = "-",
        separator = "",
        text = "item",
        type = "unordered",
        task_state = "[ ]"
    })

    ret = child.lua([[
    local line = vim.api.nvim_buf_get_lines(0, 0, -1, false)[3]
    return Mdn.list.parse_list_item]] .. suffix .. [[(line)
    ]])
    eq(ret, {
        indent = "",
        marker = "-",
        separator = "",
        text = "item",
        type = "unordered",
        task_state = "[x]"
    })

    ret = child.lua([[
    local line = vim.api.nvim_buf_get_lines(0, 0, -1, false)[4]
    return Mdn.list.parse_list_item]] .. suffix .. [[(line)
    ]])
    eq(ret, {
        indent = "",
        marker = "1",
        separator = ".",
        text = "item",
        type = "ordered",
        task_state = ""
    })

    ret = child.lua([[
    local line = vim.api.nvim_buf_get_lines(0, 0, -1, false)[5]
    return Mdn.list.parse_list_item]] .. suffix .. [[(line)
    ]])
    eq(ret, {
        indent = "",
        marker = "2",
        separator = ".",
        text = "item",
        type = "ordered",
        task_state = "[ ]"
    })

    ret = child.lua([[
    local line = vim.api.nvim_buf_get_lines(0, 0, -1, false)[6]
    return Mdn.list.parse_list_item]] .. suffix .. [[(line)
    ]])
    eq(ret, {
        indent = "",
        marker = "3",
        separator = ".",
        text = "item",
        type = "ordered",
        task_state = "[x]"
    })

    ret = child.lua([[
    local line = vim.api.nvim_buf_get_lines(0, 0, -1, false)[8]
    return Mdn.list.parse_list_item]] .. suffix .. [[(line)
    ]])
    eq(ret, {
        indent = "  ",
        marker = "-",
        separator = "",
        text = "item",
        type = "unordered",
        task_state = ""
    })

    ret = child.lua([[
    local line = vim.api.nvim_buf_get_lines(0, 0, -1, false)[9]
    return Mdn.list.parse_list_item]] .. suffix .. [[(line)
    ]])
    eq(ret, {
        indent = "    ",
        marker = "-",
        separator = "",
        text = "item",
        type = "unordered",
        task_state = ""
    })
end

T['get_list_item_string()'] = function()
    local ret = child.lua([[
    local ldata = {
        indent = "",
        marker = "1",
        separator = ".",
        text = "item",
        type = "ordered",
        task_state = "[x]"
    }
    return Mdn.list.get_list_item_string(ldata)
    ]])
    eq(ret, "1. [x] item")

    ret = child.lua([[
    local ldata = {
        indent = "",
        marker = "1",
        separator = ".",
        text = "item",
        type = "ordered",
        task_state = ""
    }
    return Mdn.list.get_list_item_string(ldata)
    ]])
    eq(ret, "1. item")
end

T['unordered_list'] = function()
    for _, ul_indicator in ipairs(helpers.unordered_list_indicators) do
        local lines = {ul_indicator .. " item"}
        local buf = create_md_buffer(child, lines)

        child.lua([[Mdn.list.new_line_remap('o')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {ul_indicator .. " item", ul_indicator .. " "})

        child.lua([[return Mdn.list.new_line_remap('<CR>')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {ul_indicator .. " item", ""})
        child.api.nvim_input("<ESC>")

        child.api.nvim_input("kk")
        child.lua([[Mdn.list.new_line_remap('O')]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {ul_indicator .. " ", ul_indicator .. " item", ""})

        child.api.nvim_input("<ESC>")
    end
end

T['ordered_list'] = function()
    for _, ol_indicator in ipairs(helpers.ordered_list_indicators) do
        local lines = {"1" .. ol_indicator .. " item"}
        local buf = create_md_buffer(child, lines)

        child.lua([[Mdn.list.new_line_remap('o', 1)]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " item",
            "2" .. ol_indicator .. " "
        })

        child.lua([[return Mdn.list.new_line_remap('<CR>', 1)]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " item",
            "",
        })
        child.api.nvim_input("<ESC>")

        child.api.nvim_input("kk")
        child.lua([[Mdn.list.new_line_remap('O', -1)]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "0" .. ol_indicator .. " ",
            "1" .. ol_indicator .. " item",
            "",
        })

        child.api.nvim_input("<ESC>")
    end
end

T['task_list'] = function()
    for _, ul_indicator in ipairs(helpers.unordered_list_indicators) do
        local lines = {ul_indicator .. " item"}
        local buf = create_md_buffer(child, lines)

        child.lua([[Mdn.list.task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            ul_indicator .. " [ ] item",
        })

        child.lua([[Mdn.list.task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            ul_indicator .. " [x] item",
        })

        child.lua([[Mdn.list.task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            ul_indicator .. " item",
        })

        child.lua([[Mdn.list.task_list_toggle()]])
        child.lua([[Mdn.list.new_line_remap('o', false)]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            ul_indicator .. " [ ] item",
            ul_indicator .. " [ ] ",
        })

        child.api.nvim_input("<ESC>")
    end

    for _, ol_indicator in ipairs(helpers.ordered_list_indicators) do
        local lines = {"1" .. ol_indicator .. " item"}
        local buf = create_md_buffer(child, lines)

        child.lua([[Mdn.list.task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " [ ] item",
        })

        child.lua([[Mdn.list.task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " [x] item",
        })

        child.lua([[Mdn.list.task_list_toggle()]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " item",
        })

        child.lua([[Mdn.list.task_list_toggle()]])
        child.lua([[Mdn.list.new_line_remap('o', 1)]])
        lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
        eq(lines, {
            "1" .. ol_indicator .. " [ ] item",
            "2" .. ol_indicator .. " [ ] ",
        })

        child.api.nvim_input("<ESC>")
    end
end

T['check_list_valid()'] = function()
    local lines = {
        "- item",
        "- item",
        "    - item",
        "    - item",
        "- item",
        "- item",
        "    - item",
        "    - item",
        "",
        "1. item",
        "2. item",
        "3. item",
        "   - item",
        "4. item",
        "5. item",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[return Mdn.list.check_list_valid()]])
    eq(ret, {
        valid = true,
        buf = 2,
        startl = 1,
        endl = 8
    })

    child.fn.cursor(2,1)
    ret = child.lua([[return Mdn.list.check_list_valid({ outliner_list = true })]])
    eq(ret, {
        valid = true,
        buf = 2,
        startl = 2,
        endl = 4
    })

    child.fn.cursor(5,1)
    ret = child.lua([[return Mdn.list.check_list_valid({ same_indent = true })]])
    eq(ret, {
        valid = true,
        buf = 2,
        startl = 5,
        endl = 6
    })

    child.fn.cursor(10,1)
    ret = child.lua([[return Mdn.list.check_list_valid({ same_marker = false })]])
    eq(ret, {
        valid = true,
        buf = 2,
        startl = 10,
        endl = 15
    })
end

T['ordered_list_renumber()'] = function()
    local lines = {
        "1. item",
        "4. item",
        "4. item",
        "   - item",
        "   - item",
        "   - item",
        "6. item",
        "8. item",
    }
    local buf = create_md_buffer(child, lines)

    child.lua([[Mdn.list.ordered_list_renumber({ silent = true })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "1. item",
        "2. item",
        "3. item",
        "   - item",
        "   - item",
        "   - item",
        "4. item",
        "5. item",
    })

    lines = {
        "# Header",
        "1. item",
        "4. item",
        "6. item",
        "8. item",
    }
    buf = create_md_buffer(child, lines)

    child.fn.cursor(2,1)
    child.lua([[Mdn.list.ordered_list_renumber({ silent = true })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "# Header",
        "1. item",
        "2. item",
        "3. item",
        "4. item",
    })

    lines = {
        "# Header",
        "1. item",
        "4. item",
        "6) item",
        "8) item",
    }
    buf = create_md_buffer(child, lines)

    child.fn.cursor(2,1)
    child.lua([[Mdn.list.ordered_list_renumber({ silent = true })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "# Header",
        "1. item",
        "2. item",
        "6) item",
        "8) item",
    })
end

return T
