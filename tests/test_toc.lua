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
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    return require('mdnotes.toc').buf_fragments
    ]])
    eq(ret, {
        {
            buf_num = buf,
            parsed = {
                fragments = {
                    {
                        hash = "#",
                        text = "Heading 1",
                        lnum = 1,
                    },
                    {
                        hash = "##",
                        text = "Heading 2",
                        lnum = 4,
                    }
                },
                gfm = {"heading-1", "heading-2"}
            }
        }
    })

    -- Call it again to ensure it doesn't get added
    ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    return require('mdnotes.toc').buf_fragments
    ]])
    eq(ret, {
        {
            buf_num = buf,
            parsed = {
                fragments = {
                    {
                        hash = "#",
                        text = "Heading 1",
                        lnum = 1,
                    },
                    {
                        hash = "##",
                        text = "Heading 2",
                        lnum = 4,
                    }
                },
                gfm = {"heading-1", "heading-2"}
            }
        }
    })

    -- Set new lines for the same buffer and check if data changes
    child.api.nvim_buf_set_lines(buf, 0, -1, false, {"### Heading 3"})
    ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    return require('mdnotes.toc').buf_fragments
    ]])
    eq(ret, {
        {
            buf_num = buf,
            parsed = {
                fragments = {
                    {
                        hash = "###",
                        text = "Heading 3",
                        lnum = 1,
                    },
                },
                gfm = {"heading-3",}
            }
        }
    })

    --Create another buffer to test if it is added
    local new_buf = create_md_buffer(child, lines)

    ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    return require('mdnotes.toc').buf_fragments
    ]])
    eq(ret, {
        {
            buf_num = buf,
            parsed = {
                fragments = {
                    {
                        hash = "###",
                        text = "Heading 3",
                        lnum = 1,
                    },
                },
                gfm = {"heading-3",}
            }
        },
        {
            buf_num = new_buf,
            parsed = {
                fragments = {
                    {
                        hash = "#",
                        text = "Heading 1",
                        lnum = 1,
                    },
                    {
                        hash = "##",
                        text = "Heading 2",
                        lnum = 4,
                    }
                },
                gfm = {"heading-1", "heading-2"}
            }
        }
    })
end

T['get_fragments_from_buf()'] = function()
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
    return require('mdnotes.toc').get_fragments_from_buf(cur_buf)
    ]])
    eq(ret, {
        {
            hash = "#",
            text = "Heading 1",
            lnum = 1,
        },
        {
            hash = "##",
            text = "Heading 2",
            lnum = 4,
        }
    })
end

T['get_fragment_from_buf_fragments()'] = function()
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
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    return require('mdnotes.toc').get_fragment_from_buf_fragments(cur_buf, "heading-1")
    ]])
    eq(ret, "Heading 1")
end

-- Test is based on these rules
-- https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#section-links
T['convert_text_to_gfm'] = function()
    local ret = child.lua([[
    return require('mdnotes.toc').convert_text_to_gfm("text -/';+123    @💩")
    ]])

    eq(ret, "text-123----")
end

T['convert_fragments_to_gfm_style()'] = function()
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
    local fragments = require('mdnotes.toc').get_fragments_from_buf(cur_buf)
    return require('mdnotes.toc').convert_fragments_to_gfm_style(fragments)
    ]])
    eq(ret, {"heading-1", "heading-2"})
end

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
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    return require('mdnotes.toc').generate({ write = false, depth = 1 })
    ]])
    eq(ret, {"- [Heading 1](#heading-1)"})

    ret = child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    return require('mdnotes.toc').generate({ write = false })
    ]])
    eq(ret, {"- [Heading 1](#heading-1)", "    - [Heading 2](#heading-2)"})


    child.lua([[
    local cur_buf = vim.api.nvim_get_current_buf()
    require('mdnotes.toc').populate_buf_fragments(cur_buf)
    require('mdnotes.toc').generate()
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

return T
