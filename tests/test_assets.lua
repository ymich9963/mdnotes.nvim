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
            child.lua([[require('mdnotes').setup({assets_path = "assets"})]])
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['check_assets_path()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes.assets').check_assets_path()
    ]])
    eq(ret, true)
end

T['get_asset_inline_link()'] = function()
    local ret = child.lua([[return require('mdnotes.assets').get_asset_inline_link(false, "path/test", false)]])
    eq(ret, "[test](assets/test)")

    ret = child.lua([[return require('mdnotes.assets').get_asset_inline_link(true, "path/test", false)]])
    eq(ret, "![test](assets/test)")
end

T['get_used_assets()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes.assets').get_used_assets(true)
    ]])
    eq(ret, {"asset1.txt", "asset2 spaces.txt"})
end

return T
