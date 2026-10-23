---@module 'mdnotes.wikilink'

local M = {}

local uv = vim.loop or vim.uv

---@type table<string>
M.old_filenames = {}

---@type table<string>
M.new_filenames = {}

---@class MdnWikiLinkData: MdnText
---@field file string WikiLink file
---@field fragment string The fragment in the WikiLink
---@field alias string WikiLink alias

local check_markdown_lsp_cur_buf = function() return require('mdnotes').check_markdown_lsp_cur_buf() end
local get_buf_from_buf_list = function(...) return require('mdnotes').get_buf_from_buf_list(...) end

---Parse WikiLink
---@param opts {wikilink: string?, location: MdnInLineLocation?}?
---@return MdnWikiLinkData?
function M.parse(opts)
    local parser = require('mdnotes').config.parser
    if parser == "patterns" then
        return M.parse_re(opts)
    elseif parser == "treesitter" then
        return M.parse_ts(opts)
    end
end

---Parse WikiLink with Lua patterns
---@param opts {wikilink: string?, location: MdnInLineLocation?}?
---@return MdnWikiLinkData?
function M.parse_re(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local wikilink = opts.wikilink

    vim.validate("wikilink", wikilink, "string", true)

    local mdn_patterns = require('mdnotes.patterns')
    local check_inline_markdown_syntax_re = require('mdnotes').check_inline_markdown_syntax_re
    local txtdata = {}

    -- Overwrite if location is given
    if opts.location ~= nil or wikilink == nil then
        if not check_inline_markdown_syntax_re(mdn_patterns.wikilink, {location = opts.location}) then return nil end
        txtdata = require('mdnotes').get_text_in_pattern(mdn_patterns.wikilink, { location = opts.location })
        wikilink = txtdata.raw or ""
    end

    local wikilink_contents = wikilink:match(mdn_patterns.wikilink_contents)
    local wikilink_no_fragment = wikilink_contents:match(mdn_patterns.dest_no_fragment) or ""
    local fragment = wikilink_contents:match(mdn_patterns.fragment) or ""
    local alias = wikilink_contents:match(mdn_patterns.wikilink_alias) or ""

    return vim.tbl_extend("force", {
        file = wikilink_no_fragment,
        fragment = fragment,
        alias = alias,
    }, txtdata)
end

---Parse WikiLink with Lua patterns
---@param opts {wikilink: string?, location: MdnInLineLocation?}?
---@return MdnWikiLinkData?
function M.parse_ts(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local wikilink = opts.wikilink
    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local lnum = locopts.lnum or vim.fn.line('.')
    local col_start = locopts.col_start or vim.fn.col('.')
    local col_end = locopts.col_end or vim.fn.col('.')
    local cur_col = locopts.cur_col or math.floor((col_start + col_end) / 2)

    vim.validate("wikilink", wikilink, "string", true)

    local node, source
    if opts.location ~= nil or wikilink == nil then
        node = vim.treesitter.get_node({
            bufnr = buf,
            ignore_injections = false,
            pos = {lnum - 1, col_start - 1}
        })
        source = buf
    else
        local parser = vim.treesitter.get_string_parser(wikilink, "markdown_inline")
        local tree = parser:parse()[1]
        node = tree:root():child(0)
        source = wikilink
    end

    local node_data
    local process_node = require('mdnotes.treesitter')["wikilink"] or function() return {} end
    local function get_node_data(_node)
        if _node ~= nil then
            node_data = process_node(_node, source, false) or process_node(_node:named_child(), source, false)
            if node_data == nil then
                get_node_data(_node:parent())
            end
        end
    end

    get_node_data(node)

    if node_data == nil then
        return nil
    end

    node_data.cur_col = cur_col

    return node_data
end
---Follow the WikiLink under the cursor
---@param opts {wikilink: string?, location: MdnInLineLocation?, hor: boolean?, vert: boolean?, picker: boolean?}?
function M.follow(opts)
    if check_markdown_lsp_cur_buf() then
        vim.lsp.buf.definition()

        return
    end

    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local locopts = opts.location or {}
    local buf = locopts.buf or vim.api.nvim_get_current_buf()
    local wikilink = opts.wikilink
    local hor = opts.hor or false
    local vert = opts.vert or false
    local picker = opts.picker or false

    local wldata
    if wikilink == nil then
        wldata = M.parse({ location = opts.location })
    else
        wldata = M.parse({ wikilink = wikilink })
    end

    if wldata == nil and picker == true then
        wldata = M.picker(function(sel_obj) M.follow({ wikilink = sel_obj.raw }) end, buf)
    end

    if wldata == nil then return end

    local cwd = require('mdnotes').cwd

    if wldata.file ~= "" then
        local path = vim.fs.joinpath(cwd, wldata.file)

        if not vim.endswith(path, ".md") then
            path = path .. ".md"
        end

        require('mdnotes').open_buf(path, {hor = hor, vert = vert})
    end

    if wldata.fragment ~= "" then
        vim.fn.cursor(vim.fn.search(wldata.fragment), 1)
        vim.api.nvim_input('zz')
    end
end

---Follow the WikiLink and split horizontally
---@param opts {wikilink: string?, location: MdnInLineLocation?, picker: boolean?}?
function M.follow_hor(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    M.follow({ wikilink = opts.wikilink, location = opts.location, hor = true, picker = opts.picker})
end

---Follow the WikiLink and split vertically
---@param opts {wikilink: string?, location: MdnInLineLocation?, picker: boolean?}?
function M.follow_vert(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    M.follow({ wikilink = opts.wikilink, location = opts.location, vert = true, picker = opts.picker})
end

---Show the references to the current WikiLink under the cursor
---@param opts {location: MdnInLineLocation?, silent: boolean?}?
---@return table? qflist Resulting quickfix list
function M.find_references(opts)
    if check_markdown_lsp_cur_buf() then
        vim.lsp.buf.references()

        return
    end

    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    local silent = opts.silent or false
    local wldata = M.parse({ location = opts.location })

    if wldata == nil then
        -- If WikiLink isn't detected use current file name
        local cur_file_basename = vim.fs.basename(vim.api.nvim_buf_get_name(0))
        wldata = {
            buf = vim.api.nvim_get_current_buf(),
            file = cur_file_basename:gsub(".md$",""),
            fragment = "",
            alias = "",
        }
        wldata.raw = "[[" .. wldata.file .. "]]"
    end

    local cur_pos = vim.fn.getpos('.')
    local cwd = require('mdnotes').cwd
    local mdn_grep = require('mdnotes').mdn_grep

    if silent == false then
        vim.notify("Mdn: Searching references for '" .. wldata.raw:sub(3, -3) .. "'...", vim.log.levels.INFO)
    end

    mdn_grep("\\[\\[".. wldata.file .. "(\\.md)?(\\#.*)?\\]\\]", cwd)

    local qflist = vim.fn.getqflist()
    if vim.tbl_isempty(qflist) then
        if silent == false then
            vim.notify("Mdn: No references found for '" .. wldata.raw:sub(3, -3) .. "'", vim.log.levels.ERROR)
        end

        return qflist
    end

    vim.cmd.buffer(wldata.buf)
    vim.fn.setpos('.', cur_pos)
    vim.cmd.copen()

    return qflist
end

---Rename references of the WikiLink under the cursor
---If there is no WikiLink under the cursor, prompt to rename references to
---the current buffer
---@param opts {new_name: string?, location: MdnInLineLocation?, silent: boolean?}?
---@return string? old_name, string|nil new_name 
function M.rename_references(opts)
    if check_markdown_lsp_cur_buf() then
        -- I think this renames the current buffer and
        -- not the symbol under cursor
        vim.lsp.buf.rename()

        return
    end

    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    local silent = opts.silent or false
    local new_name = opts.new_name

    vim.validate("new_name", new_name, "string", true)

    -- Save current position to rever back later
    local cur_buf = vim.api.nvim_get_current_buf()
    local pos = vim.fn.getpos('.')

    local temp_qflist = vim.fn.getqflist()
    local prompt = "Rename WikiLink and file: "
    local cwd = require('mdnotes').cwd
    local mdn_grep = require('mdnotes').mdn_grep
    local wldata = M.parse({ location = opts.location })

    if wldata == nil then
        prompt = "Rename current buffer: "
        wldata = {
            file = vim.fs.basename(vim.api.nvim_buf_get_name(0)):match("(.+)%.[^%.]+$"),
            fragment = "",
            alias = "",
        }
        wldata.raw = "[[" .. wldata.file .. "]]"
    end

    -- Remove the file extension for this function
    if vim.endswith(wldata.file, ".md") then
        wldata.file = wldata.file:sub(1,-4)
    end

    -- Check if it exists
    local filepath = vim.fs.normalize(vim.fs.joinpath(cwd, wldata.file .. ".md"))
    if not uv.fs_stat(filepath) then
        if silent == false then
            vim.notify("Mdn: WikiLink does not seem to link to a valid Markdown file", vim.log.levels.ERROR)
        end

        return wldata.file, "invalid file"
    end

    -- Prompt for new name and check if valid
    if new_name == nil then
        vim.ui.input({ prompt = prompt, default = wldata.file },
        function(input)
            new_name = input
        end)

        if new_name == "" or new_name == nil then
            if silent == false then
                vim.notify("Mdn: Please insert a valid name", vim.log.levels.ERROR)
            end

            return wldata.file, "invalid name"
        end
    end

    if silent == false then
        vim.cmd.redraw()
        vim.notify("Mdn: Renaming references of '" .. wldata.raw:sub(3, -3) .. "' to '" .. new_name .. "'", vim.log.levels.INFO)
    end

    -- Change all [[WikiLink]] text to be the new name
    mdn_grep("\\[\\[".. wldata.file .. "(\\.md)?(\\#.*)?\\]\\]", cwd)
    vim.cmd.cdo({args = {('s/%s/%s/'):format("\\[\\[" .. wldata.file, "\\[\\[" .. new_name)}, mods = {emsg_silent = true, noautocmd = true}})

    -- Get the buffer number of the renamed file if it is in the buffer list
    local renamed_bufnum = get_buf_from_buf_list(wldata.file .. ".md")

    -- If the buffer number of the renamed file is in the buffer list
    if renamed_bufnum ~= nil then
        if renamed_bufnum ~= cur_buf then
            vim.api.nvim_buf_delete(renamed_bufnum, {force = true})
        elseif renamed_bufnum == cur_buf then
            vim.api.nvim_buf_set_name(cur_buf, vim.fs.joinpath(cwd, new_name .. ".md"))
        end
    end

    -- Rename and check if succesful
    local ret, err = uv.fs_rename(
        filepath,
        vim.fs.joinpath(cwd, new_name .. ".md")
    )

    if not ret then
        if silent == false then
            vim.cmd.redraw()
            vim.notify("Mdn: File rename failed", vim.log.levels.ERROR)
        end

        return wldata.file, err
    end

    table.insert(M.old_filenames, wldata.file)
    table.insert(M.new_filenames, new_name)

    -- Set the qf list to what it was before the operation
    vim.fn.setqflist(temp_qflist)

    -- Go back to position where command started
    vim.cmd.buffer(cur_buf)
    vim.fn.setpos('.', pos)

    vim.cmd.write({bang = true, mods = {silent = true}})

    if silent == false then
        vim.cmd.redraw()
        vim.notify(("Mdn: Succesfully renamed '%s' links to '%s'"):format(wldata.raw:sub(3, -3), new_name), vim.log.levels.INFO)
    end

    return wldata.file, new_name
end

---Undo the most recent rename
---@param opts {silent: boolean?}?
---@return string? old_name, string|nil new_name 
function M.undo_rename(opts)
    if check_markdown_lsp_cur_buf() then
        vim.notify("Mdn: 'undo_rename' is only available when your config has 'prefer_lsp = false'", vim.log.levels.ERROR)
        return
    end

    vim.validate("opts", opts, "table", true)
    opts = opts or {}
    local silent = opts.silent or false
    vim.validate("silent", silent, "boolean")

    if vim.tbl_isempty(M.new_filenames) or vim.tbl_isempty(M.old_filenames) then
        if silent == false then
            vim.notify("Mdn: Detected no recent rename", vim.log.levels.ERROR)
        end

        return
    end

    local newest_filename = M.new_filenames[#M.new_filenames]
    local newest_old_filename = M.old_filenames[#M.old_filenames]

    local temp_qflist = vim.fn.getqflist()
    local cur_buf = vim.api.nvim_get_current_buf()
    local cur_pos = vim.fn.getpos('.')
    local cwd = require('mdnotes').cwd
    local mdn_grep = require('mdnotes').mdn_grep

    if silent == false then
        vim.notify("Mdn: Undoing rename...", vim.log.levels.INFO)
    end

    mdn_grep("\\[\\[".. newest_filename .. "(\\.md)?(\\#.*)?\\]\\]", cwd)
    vim.cmd.cdo({args = {('s/%s/%s/'):format(newest_filename, newest_old_filename)}, mods = {emsg_silent = true, noautocmd = true}})

    local ret, err = uv.fs_rename(
        vim.fs.joinpath(cwd, newest_filename .. ".md"),
        vim.fs.joinpath(cwd, newest_old_filename .. ".md")
    )
    if not ret then
        if silent == false then
            vim.notify(("Mdn: Undo file rename failed"), vim.log.levels.ERROR)
        end

        return nil, err
    end

    if silent == false then
        vim.cmd.redraw()
        vim.notify(("Mdn: Undo renaming '%s' to '%s'"):format(newest_old_filename, newest_filename), vim.log.levels.INFO)
    end

    -- Get the buffer number of the renamed file if it is in the buffer list
    local renamed_bufnum = get_buf_from_buf_list(newest_old_filename .. ".md")

    -- If the buffer number of the renamed file is in the buffer list
    if renamed_bufnum ~= nil then
        if renamed_bufnum ~= cur_buf then
            vim.api.nvim_buf_delete(renamed_bufnum, {force = true})
        elseif renamed_bufnum == cur_buf then
            vim.api.nvim_buf_set_name(cur_buf, vim.fs.joinpath(cwd, newest_old_filename .. ".md"))
        end
    end

    vim.cmd.buffer(cur_buf)
    vim.fn.setpos('.', cur_pos)

    -- Set the qf list to what it was before the operation
    vim.fn.setqflist(temp_qflist)

    table.remove(M.new_filenames)
    table.remove(M.old_filenames)

    return newest_filename, newest_old_filename
end

---Create a WikiLink from the word under the cursor
---@param opts {location: MdnInLineLocation?, move_cursor: boolean?}?
function M.create(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local cur_pos = vim.fn.getpos(".")

    local text
    local wldata = M.parse({ location = opts.location })
    if wldata == nil then
        local txtdata = require('mdnotes').get_text({ location = opts.location })
        if txtdata.raw == nil then
            return
        end
        text = txtdata.raw
    else
        text = wldata.file
    end

    local buf = vim.api.nvim_get_current_buf()
    local temp_qflist = vim.fn.getqflist()
    local mdn_grep = require('mdnotes').mdn_grep

    mdn_grep(text, require('mdnotes').cwd)
    if vim.api.nvim_get_current_buf() ~= buf then
        vim.cmd.buffer(buf)
    end

    local wl_list = vim.fn.getqflist()
    vim.fn.setqflist(temp_qflist)

    -- Create WikiLinks where the text shows up
    for _,v in ipairs(wl_list) do

        -- Some external tools don't provide end_col
        if v.end_col == 0 then
            v.end_col = v.col + #text
        end

        -- Ignore text in headings
        local pattern = require('mdnotes.patterns').heading
        if not v.text:match(pattern) then
            local locopts = {
                buf = v.bufnr,
                lnum = v.lnum,
                col_start = v.col,
                col_end = v.end_col
            }

            vim.api.nvim_buf_call(locopts.buf, function()
                local wl = M.parse({ location = locopts })
                if wl == nil or (wl.lnum ~= v.lnum and wl.raw:sub(3, -3) == v.text) then
                    local insert_format = require('mdnotes.formatting').insert_format
                    insert_format("wikilink", { location = locopts, move_cursor = false })
                end
            end)
        end
    end

    vim.fn.setpos(".", cur_pos)
end

---Delete the current WikiLink and the associated file
---@param opts {file: string?, location: MdnInLineLocation?, move_cursor: boolean?, skip_input: boolean?}?
---@return boolean deleted, string? wl_path Returns whether the file was deleted and the affected WikiLink
function M.delete(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local skip_input = opts.skip_input or false
    local file = opts.file

    local wldata
    if file == nil then
        wldata = M.parse({ location = opts.location })
        if wldata == nil then return false, nil end
        file = wldata.file
    end

    local cwd = require('mdnotes').cwd
    local wl_abspath = vim.fs.normalize(vim.fs.joinpath(cwd, file))

    -- Append .md to guarantee a file name
    local wl_name = vim.fs.basename(wl_abspath)
    if not vim.endswith(wl_name, ".md") then
        wl_name = wl_name .. ".md"
        wl_abspath = wl_abspath .. ".md"
    end

    local wl_relpath = vim.fs.relpath(cwd, wl_abspath)

    local behaviour = require('mdnotes').config.wikilink_delete_behaviour
    local garbage_path = require('mdnotes').get_garbage_dir()
    local is_deleted = false

    local verb = ""
    local prompt = "Type y/n/a(ll) or 'c' to cancel (default 'n'): "
    if behaviour == "remove" then
        prompt = "Remove file at '" .. wl_relpath .. "'. " .. prompt
        verb = "Removed"
    elseif behaviour == "garbage" then
        prompt = "Move file at '" .. wl_relpath .. "' to garbage folder. " .. prompt
        verb = "Moved"
    end

    local user_input = ""
    if skip_input == false then
        vim.ui.input( { prompt = prompt, }, function(input)
            user_input = input
        end)
        vim.cmd.echo()
    elseif skip_input == true then
        user_input = 'y'
    end

    vim.cmd.redraw()
    if uv.fs_stat(wl_abspath) then
        if user_input == 'y' then
            if behaviour == "remove" then
                vim.fs.rm(wl_abspath)
            elseif behaviour == "garbage" then
                uv.fs_rename(wl_abspath, vim.fs.joinpath(garbage_path, wl_name))
            end
            vim.notify(("Mdn: %s '%s'"):format(verb, wl_relpath), vim.log.levels.WARN)
            is_deleted = true
        elseif user_input == 'n' or '' then
            vim.notify(("Mdn: Skipped '%s'"):format(wl_relpath), vim.log.levels.WARN)
        else
            vim.notify(("Mdn: Unknown input '%s'"):format(user_input), vim.log.levels.ERROR)
        end
    else
        vim.notify(("Mdn: File '%s' does not exist. Continuing with deleting its WikiLinks"):format(wl_relpath), vim.log.levels.WARN)
        is_deleted = true
    end

    -- Reset the text if a location for it was found
    if is_deleted == true then
        local mdn_grep = require('mdnotes').mdn_grep
        local temp_qflist = vim.fn.getqflist()

        mdn_grep("\\[\\[".. file .. "(\\.md)?(\\#.*)?\\]\\]", require('mdnotes').cwd)
        local wl_list = vim.fn.getqflist()
        vim.fn.setqflist(temp_qflist)

        for _,v in ipairs(wl_list) do

            -- Some external tools don't provide end_col
            if v.end_col == 0 then
                v.end_col = v.col + #file
            end

            -- + 1 due to treesitter getting the entire node text at col 0
            local locopts = {
                buf = v.bufnr,
                lnum = v.lnum,
                col_start = v.col + 1,
                col_end = v.end_col
            }

            vim.api.nvim_buf_call(locopts.buf, function()
                local wl = M.parse_re({location = locopts})
                if wl == nil then return end
                vim.api.nvim_buf_set_text(wl.buf, wl.lnum - 1, wl.col_start - 1, wl.lnum - 1, wl.col_end - 1, {wl.file})
            end)
        end

        if wldata ~= nil then
            if vim.api.nvim_get_current_buf() ~= wldata.buf then
                vim.cmd.buffer(wldata.buf)
            end
            local new_col = wldata.cur_col - 2
            if new_col < 1 then new_col = 1 end
            vim.fn.cursor({wldata.lnum, new_col})
        end
    end

    return is_deleted, wl_abspath
end

---Normalize the WikiLink under the cursor
---@param opts {location: MdnInLineLocation?, move_cursor: boolean?}?
function M.normalize(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local move_cursor = opts.move_cursor ~= false

    local wldata = M.parse({ location = opts.location })
    if wldata == nil then return end

    wldata.file = vim.fs.normalize(wldata.file)

    vim.api.nvim_buf_set_text(wldata.buf, wldata.lnum - 1, wldata.col_start - 1, wldata.lnum - 1, wldata.col_end - 1, {M.get_wl_from_obj(wldata)})

    if move_cursor == true then
        vim.cmd.buffer(wldata.buf)
        vim.fn.cursor({wldata.lnum, wldata.cur_col})
    end
end

---Get any orphan pages in the cwd
---@param opts {silent: boolean?}?
---@return table<string> orphans Table of orphan pages
function M.get_orphans(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local silent = opts.silent or false
    vim.validate("silent", silent, "boolean")

    local orphans = {}
    local tempqf_list = vim.fn.getqflist()
    local count = 0
    local cwd = require('mdnotes').cwd
    local mdn_grep = require('mdnotes').mdn_grep
    local files_cwd = require('mdnotes').get_files_in_cwd({ extension = ".md", hidden = false, fs_type = "file" })
    local buf = vim.api.nvim_get_current_buf()

    local progress = {
      kind = "progress",
      percent = 0,
      source = "mdn",
      status = "running",
    }

    if silent == false then
        progress.id = vim.api.nvim_echo({ { "Mdn: Searching notes for orphans..." } }, false, progress)
    end

    for i, file in ipairs(files_cwd) do
        file = file:gsub(".md", "")
        mdn_grep("\\[\\[".. file .. "(\\.md)?(\\#.*)?\\]\\]", cwd)
        if vim.api.nvim_get_current_buf() ~= buf then
            vim.cmd.buffer(buf) -- to prevent jumps while searching
        end
        if vim.tbl_isempty(vim.fn.getqflist()) then
            count = count + 1
            table.insert(orphans, file .. ".md")
            if silent == false then
                vim.cmd.redraw()
                progress.percent = math.floor(100 * i / #files_cwd)
                vim.api.nvim_echo({ {"Mdn: Found " .. tostring(count) .. " orphan pages so far..."} }, false, progress)
            end
        end
    end

    vim.cmd.buffer(buf)
    vim.fn.setqflist(tempqf_list)

    return orphans
end

---Show orphans in qflist
function M.find_orphans()
    local orphans = M.get_orphans()
    if vim.tbl_isempty(orphans) then
        vim.cmd.redraw()
        vim.notify("Mdn: No orphan pages found", vim.log.levels.WARN)
        return
    end

    local cwd = require('mdnotes').cwd
    local qflist = {}
    for _, v in pairs(orphans) do
        table.insert(qflist, {filename = vim.fs.joinpath(cwd, v)})
    end

    vim.fn.setqflist(qflist)
    vim.cmd.copen()

    return qflist
end

---Get an inline link string from an MdnInlineLinkData object
---@param wldata MdnWikiLinkData? Inline link object
---@return string wikilink
function M.get_wl_from_obj(wldata)
    vim.validate("wldata", wldata, "table", true)
    if wldata == nil then return "" end

    if wldata.alias == nil or wldata.alias == "" then
        if wldata.fragment == nil or wldata.fragment == "" then
            return "[[" .. wldata.file .. "]]"
        else
            return "[[" .. wldata.file .. "#" .. wldata.fragment .. "]]"
        end
    else
        if wldata.fragment == nil or wldata.fragment == "" then
            return "[[" .. wldata.file .. "|" .. wldata.alias .. "]]"
        else
            return "[[" .. wldata.file .. "#" .. wldata.fragment .. "|" .. wldata.alias .. "]]"
        end
    end
end

---Open a picker to get the WikiLink
---@param on_end fun(sel_obj): any Callback function for when the coroutine finishes
---@param buf integer Buffer number
function M.picker(on_end, buf)
    vim.validate("on_end", on_end, "function")
    vim.validate("buf", buf, "number")
    if buf == 0 then buf = vim.api.nvim_get_current_buf() end

    local parsed_tbl = M.parse_lines({ location = {startl = 1, endl = vim.fn.line("$"), buf = buf }, silent = true})
    if parsed_tbl == nil then
        vim.notify("Mdn: No WikiLinks in current file", vim.log.levels.ERROR)
        return
    end

    local ui_opts = {
        prompt = "Select a WikiLink:",
        format_item = function(item)
            return item.raw:sub(3, -3)
        end,
    }

    return require('mdnotes').mdn_picker(parsed_tbl, on_end, ui_opts)
end

---Parse the WikiLinks in the specified lines
---@param opts MdnParseLinesOpts?
---@return table<MdnWikiLinkData>?
function M.parse_lines(opts)
    local parser = require('mdnotes').config.parser
    if parser == "patterns" then
        return M.parse_lines_re(opts)
    elseif parser == "treesitter" then
        return M.parse_lines_ts(opts)
    end
end

---Parse the WikiLinks in the specified lines using Lua patterns
---@param opts MdnParseLinesOpts?
---@return table<MdnWikiLinkData>?
function M.parse_lines_re(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local str = opts.str or false
    local pattern = require('mdnotes.patterns').wikilink
    local parse_lines_re = require('mdnotes').parse_lines_re

    local process_func = nil
    if str == true then
        process_func = M.get_wl_from_obj
    end
    local _opts = vim.tbl_extend("force", opts, {process_func = process_func})

    return parse_lines_re(pattern, M.parse_re, _opts)
end

---Parse the WikiLinks in the specified lines using treesitter
---@param opts MdnParseLinesOpts?
---@return table<MdnWikiLinkData>?
function M.parse_lines_ts(opts)
    vim.validate("opts", opts, "table", true)
    opts = opts or {}

    local str = opts.str or false
    local parse_lines_ts = require('mdnotes').parse_lines_ts

    local process_func = nil
    if str == true then
        process_func = M.get_wl_from_obj
    end
    local _opts = vim.tbl_extend("force", opts, {process_func = process_func})

    return parse_lines_ts("wikilink", _opts)
end

return M
