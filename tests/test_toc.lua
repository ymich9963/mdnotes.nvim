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

T['generate()'] = function()
    local lines = {
        "# Heading 1",
        "Text here",
        "",
        "## Heading 2",
        "Text here",
    }
    local buf = create_md_buffer(child, lines)

    local ret = child.lua([[
    Mdn.populate_buf_fragments()
    return Mdn.toc.generate({ write = false, depth = 1 })
    ]])
    eq(ret, {
        contents = { "- [Heading 1](#heading-1)" },
        buf = 2,
        depth = 1,
        startl = 1,
        endl = 1
    })

    ret = child.lua([[
    Mdn.populate_buf_fragments()
    return Mdn.toc.generate({ write = false })
    ]])
    eq(ret, {
        contents = { "- [Heading 1](#heading-1)", "    - [Heading 2](#heading-2)" },
        buf = 2,
        depth = 4,
        startl = 1,
        endl = 2
    })

    child.lua([[
    Mdn.populate_buf_fragments()
    Mdn.toc.generate()
    ]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "- [Heading 1](#heading-1)",
        "    - [Heading 2](#heading-2)",
        "# Heading 1",
        "Text here",
        "",
        "## Heading 2",
        "Text here"
    })
end


T['check_toc_valid()'] = function()
    local lines = {
        "- [Heading 1](#heading-1)",
        "    - [Heading 2](#heading-2)",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[ return Mdn.toc.check_toc_valid() ]])
    eq(ret, {
        buf = 2,
        endl = 2,
        startl = 1,
        valid = true
    })
end

T['parse()'] = function()
    local lines = {
        "- [Heading 1](#heading-1)",
        "    - [Heading 2](#heading-2)",
    }
    create_md_buffer(child, lines)

    local ret = child.lua([[ return Mdn.toc.parse() ]])
    eq(ret, {
        contents = { "- [Heading 1](#heading-1)", "    - [Heading 2](#heading-2)" },
        depth = 2,
        startl = 1,
        endl = 2,
        buf = 2
    })
end


T['update()'] = function()
    local lines = {
        "- [Heading 1](#heading-1)",
        "    - [Heading 2](#heading-2)",
        "# Heading 1",
        "Text here",
        "",
        "## Heading 2",
        "Text here",
        "",
        "## Heading 3",
        "Text here",
    }
    local buf = create_md_buffer(child, lines)

    local ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    Mdn.populate_buf_fragments(cur_buf)
    return Mdn.toc.update()
    ]])
    eq(ret, {
        contents = { "- [Heading 1](#heading-1)", "    - [Heading 2](#heading-2)", "    - [Heading 3](#heading-3)" },
        depth = 2,
        startl = 1,
        endl = 3,
        buf = 2
    })
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines, {
        "- [Heading 1](#heading-1)",
        "    - [Heading 2](#heading-2)",
        "    - [Heading 3](#heading-3)",
        "# Heading 1",
        "Text here",
        "",
        "## Heading 2",
        "Text here",
        "",
        "## Heading 3",
        "Text here",
    }
)
end

return T
