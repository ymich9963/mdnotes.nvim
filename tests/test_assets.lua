local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

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

T['get_assets_folder_name()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes.assets').get_assets_folder_name()
    ]])
    eq(ret, "assets")
end

T['check_assets_path()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes.assets').check_assets_path()
    ]])
    eq(ret, true)
end

T['get_asset_inline_link()'] = function()
    local ret = child.lua([[return require('mdnotes.assets').get_asset_inline_link({
        is_image = false,
        file_path = "path/test",
        process_file = false
    })]])
    eq(ret, "[test](assets/test)")

    ret = child.lua([[return require('mdnotes.assets').get_asset_inline_link({
        is_image = true,
        file_path = "path/test",
        process_file = false
    })]])
    eq(ret, "![test](assets/test)")
end

T['get_used_assets()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes.assets').get_used_assets({ silent = true})
    ]])
    eq(ret, {"asset1.txt", "asset2 spaces.txt"})
end

T['get_unused_assets()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes.assets').get_unused_assets({silent = true})
    ]])
    eq(ret, {"asset3.txt"})
end

T['unused_delete()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    eq(
        vim.fs.basename(vim.fs.find("asset3.txt", { path = './tests/test-data/files/assets' })[1]),
        "asset3.txt"
    )
    child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes.assets').unused_delete({ skip_input = true })
    ]])
    eq(
       vim.fs.basename(vim.fs.find("asset3.txt", { path = './tests/test-data/files/assets' })[1]),
        nil
    )
    child.cmd([[
    edit tests/test-data/files/assets/asset3.txt
    write
    ]])
end

T['unused_move()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    eq(
        vim.fs.basename(vim.fs.find("asset3.txt", { path = './tests/test-data/files/assets' })[1]),
        "asset3.txt"
    )
    child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes.assets').unused_move({ skip_input = true })
    ]])
    eq(
       vim.fs.basename(vim.fs.find("asset3.txt", { path = './tests/test-data/files/unused_assets' })[1]),
        "asset3.txt"
    )
    vim.fs.rm('./tests/test-data/files/unused_assets', {recursive = true})
    child.cmd([[
    edit tests/test-data/files/assets/asset3.txt
    write
    ]])
end

T['download_website_html()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes.assets').download_website_html({ uri = "https://neovim.io/" })
    ]])
    eq(
       vim.fs.basename(vim.fs.find("https_neovim_io_.html", { path = './tests/test-data/files/assets' })[1]),
        "https_neovim_io_.html"
    )
    vim.fs.rm('./tests/test-data/files/assets/https_neovim_io_.html')
end

T['delete()'] = function()
    child.cmd([[
    edit tests/test-data/files/assets/asset4.txt
    write
    edit tests/test-data/files/file7.md
    ]])
    local ret = child.lua([[
    require('mdnotes').set_cwd()
    return require('mdnotes.assets').delete({
        uri = "assets/asset4.txt",
        skip_input = true
    })]])
    eq(ret , true)
    eq(
       vim.fs.basename(vim.fs.find("asset4.txt", { path = './tests/test-data/files/garbage' })[1]),
        "asset4.txt"
    )
    vim.fs.rm('./tests/test-data/files/garbage', {recursive = true})
end

return T
