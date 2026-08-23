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
            child.lua([[require('mdnotes').setup({assets_path = "assets"})]])
            -- child.o.grepprg = "internal"
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

T['get_assets_folder_name()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    Mdn.set_cwd()
    return Mdn.assets.get_assets_folder_name()
    ]])
    eq(ret, "assets")
end

T['check_assets_path()'] = function()
    local ret = child.lua([[ return Mdn.assets.check_assets_path() ]])
    eq(ret, false)
    child.cmd([[edit tests/test-data/files/file7.md]])
    ret = child.lua([[ return Mdn.assets.check_assets_path() ]])
    eq(ret, true)
end

T['insert()'] = function()
    -- To have a valid assets directory
    child.cmd([[edit tests/test-data/files/file7.md]])

    local lines = { "" }
    local buf = create_md_buffer(child, lines)

    child.lua([[return Mdn.assets.insert({ asset = "test", check_exists = false, picker = false })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1],  "[test](assets/test)")

    lines = { "test2" }
    buf = create_md_buffer(child, lines)
    child.lua([[return Mdn.assets.insert({ asset = "test", check_exists = false, picker = false })]])
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines[1],  "[test2](assets/test)")
end

T['insert_file()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])

    local ret = child.lua([[ return Mdn.assets.insert_file(vim.fs.joinpath(Mdn.cwd, "asset1.txt")) ]])
    eq(ret,  "asset file already exists")

    child.lua([[require('mdnotes').setup({assets_path = "assets", asset_overwrite_behaviour = "overwrite"})]])
    ret = child.lua([[ return Mdn.assets.insert_file("asset1.txt") ]])
    eq(ret,  "file copy/move failed")

    local lines = { "" }
    local buf = create_md_buffer(child, lines)
    ret = child.lua([[ return Mdn.assets.insert_file(vim.fs.joinpath(Mdn.cwd, "file1.md")) ]])
    eq(ret,  "assets/file1.md")
    lines = child.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(lines,  {"[file1.md](assets/file1.md)"})

    vim.cmd([[!rm tests/test-data//files/assets/file1.md ]])
    child.lua([[require('mdnotes').setup({assets_path = "assets"})]])
end

-- TODO: Need test for insert_from_clipboard()

T['get_used_assets()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    Mdn.set_cwd()
    return Mdn.assets.get_used_assets({ silent = true})
    ]])
    eq(ret, {"asset1.txt", "asset2 spaces.txt"})
end

T['get_unused_assets()'] = function()
    child.cmd([[edit tests/test-data/files/file7.md]])
    local ret = child.lua([[
    Mdn.set_cwd()
    return Mdn.assets.get_unused_assets({silent = true})
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
    Mdn.set_cwd()
    return Mdn.assets.unused_delete({ skip_input = true })
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
    Mdn.set_cwd()
    return Mdn.assets.unused_move({ skip_input = true })
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
    Mdn.set_cwd()
    return Mdn.assets.download_website_html({ destination = "https://neovim.io/" })
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

    child.api.nvim_buf_set_lines(0, -1, -1, false, {"[asset4.txt](assets/asset4.txt)"})
    child.cmd([[write]])

    local ret = child.lua([[
    Mdn.set_cwd()
    return {
        Mdn.assets.delete({
        destination = "assets/asset4.txt",
        skip_input = true })
    }]])
    eq(ret[1] , true)
    eq(vim.fs.basename(ret[2]) , "asset4.txt")
    eq(
        vim.fs.basename(vim.fs.find("asset4.txt", { path = './tests/test-data/files/garbage' })[1]),
        "asset4.txt"
    )
    vim.fs.rm('./tests/test-data/files/garbage', {recursive = true})
    child.cmd([[write]])

    local lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    eq(lines,  {
        "# File 7",
        "",
        "[asset1](assets/asset1.txt)",
        "[asset2 spaces](<assets/asset2 spaces.txt>)",
        "asset4.txt",
    })
    child.api.nvim_buf_set_lines(0, -2, -1, false, {})
    child.cmd([[write]])
end

return T
