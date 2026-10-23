---@module 'mdnotes.demo'

local M = {}

local dir = vim.fs.normalize(vim.fs.abspath("."))
local demo_running = false
local demo_buf = 0

local function stop_demo()
    demo_running = false
    vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
        "# Mdnotes Demo",
        "Progress: 0/8 (Press <ESC> to stop demo)",
    })
    vim.cmd.write({mods = {silent = true}})
    vim.cmd("bw! " .. demo_buf)
    vim.cmd("cd " .. dir) -- preserve path
    vim.notify("Mdn: Demo stopped")
end

-- Demo runner
local function run_demo(steps)
    local co

    local function pause(ms)
        vim.defer_fn(function()
            if coroutine.status(co) == "suspended" then
                coroutine.resume(co)
            end
        end, ms)

        coroutine.yield()
    end

    co = coroutine.create(function()
        for _, step in ipairs(steps) do
            step.action()
            pause(step.delay or 1000)

            if demo_running == false then
                coroutine.yield()
            end
        end
    end)

    coroutine.resume(co)
end

---Run demo (AI assisted)
function M.run()
    local demo_path = vim.fs.joinpath(require('mdnotes').plugin_install_dir, "tests/markdown-test-files/demo-files/demo.md")
    demo_buf = vim.fn.bufadd(demo_path)
    vim.bo[demo_buf].filetype = "markdown"
    vim.cmd.buffer(demo_buf)

    vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
        "# Mdnotes Demo",
        "Progress: 0/8 (Press <ESC> to stop demo)",
    })

    demo_running = true
    vim.keymap.set("n", "<Esc>", stop_demo, { buffer = demo_buf, })

    local esc = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
    local ctrl_u = vim.api.nvim_replace_termcodes("<C-U>", true, false, true)

    local best_fit_check = Mdn.config.autocmds.table_best_fit

    run_demo({
        {
            action = function()
                -- initial delay
            end,
            delay = 1000,
        },
        -- Formatting Demo Start
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 1/8 (Press <ESC> to stop demo)",
                    "",
                    "## Formatting",
                    "Set formatting:",
                    "- Emphasis",
                    "- Strong",
                    "- Strikethrough",
                    "- Autolinks https://neovim.io/",
                    "- Inline code",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(6, 3)
                vim.api.nvim_feedkeys(":Mdn formatting emphasis_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(7, 3)
                vim.api.nvim_feedkeys(":Mdn formatting strong_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(8, 3)
                vim.api.nvim_feedkeys(":Mdn formatting strikethrough_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(9, 13)
                vim.api.nvim_feedkeys("v$", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn formatting autolink_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(10, 3)
                vim.api.nvim_feedkeys("v$", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn formatting inline_code_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 1/8 (Press <ESC> to stop demo)",
                    "",
                    "## Formatting",
                    "Toggle fenced code blocks:",
                    "int main(int argc, char **argv) {",
                    '    printf("Hello Neovimmer")',
                    "}",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(6, 1)
                vim.api.nvim_feedkeys("Vjjj", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn formatting fenced_code_block_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn formatting fenced_code_block_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 1/8 (Press <ESC> to stop demo)",
                    "",
                    "## Formatting",
                    "Automatically continue unordered lists:",
                    "- Item 1",
                    "- Item 2",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(7, 1)
                require('mdnotes.list').new_line_remap('o')
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("Item 3", "n", false)
                vim.api.nvim_feedkeys(esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 1/8 (Press <ESC> to stop demo)",
                    "",
                    "## Formatting",
                    "Automatically continue ordered lists, and renumber:",
                    "1. Item 1",
                    "3. Item 2",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(7, 1)
                require('mdnotes.list').new_line_remap('o', 1)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("Item 3", "n", false)
                vim.api.nvim_feedkeys(esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn list ordered_list_renumber\n", "n", false)
            end,
            delay = 1000,
        },
        -- Formatting Demo End
        -- Inline Link Demo Start
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 2/8 (Press <ESC> to stop demo)",
                    "",
                    "## Inline links",
                    "- Open [link.md](link.md#fragment)",
                    "- Toggle [link](https://neovim.io/)",
                    "- Rename [link](https://neovim.io/)",
                    "- Relink [link](https://neovim.io/)",
                    "- Normalize [path](a/../path/to/../normalize#Fragment to normalize)",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(5, 8)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn inline_link open\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                require('mdnotes.history').go_back()
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(6, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn inline_link toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(6, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn inline_link toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(7, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn inline_link rename\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("renamed\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(8, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn inline_link relink\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("https://www.example.com/\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(9, 13)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn inline_link normalize\n", "n", false)
            end,
            delay = 1000,
        },
        -- Inline Link Demo End
        -- WikiLink Demo Start
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 3/8 (Press <ESC> to stop demo)",
                    "",
                    "## WikiLinks",
                    "- Create WikiLink",
                    "- Follow WikiLink",
                    "- Delete WikiLink",
                    "- Find references to WikiLink",
                    "- Rename references to WikiLink",
                    "- Undo the rename",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.cmd.write({mods = {silent = true}})
                vim.fn.cursor(5, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn wikilink create\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.cmd.write({mods = {silent = true}})
                vim.fn.cursor(6, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn wikilink follow\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                local buf = vim.api.nvim_get_current_buf()
                require('mdnotes.history').go_back()
                vim.cmd("bw! " .. buf)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(7, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn wikilink delete", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("y\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.cmd([[undo]])
            end,
            delay = 1000,
        },
        {
            action = function()
                local cwd = require('mdnotes').cwd
                vim.uv.fs_copyfile(vim.fs.joinpath(cwd, "WikiLink-backup.md"), vim.fs.joinpath(cwd, "WikiLink.md"))
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(8, 22)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn wikilink find_references\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                --delay
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.cmd([[ccl]])
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(9, 24)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn wikilink rename_references", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("Renamed", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(10, 3)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn wikilink undo_rename\n", "n", false)
            end,
            delay = 1000,
        },
        -- WikiLink Demo End
        -- Tables Demo Start
        {
            action = function()
                if best_fit_check == false then
                    Mdn.config.autocmds.table_best_fit = true
                end
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 4/8 (Press <ESC> to stop demo)",
                    "",
                    "## Tables",
                    "Create and populate with automatic best fit:",
                    "",
                    "",
                    "",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
                if best_fit_check == false then
                    Mdn.config.autocmds.table_best_fit = false
                end
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.cmd.write({mods = {silent = true}})
                vim.fn.cursor(7, 2)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table create 3 3\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
                vim.api.nvim_feedkeys(":Mdn table populate\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("Heading 1\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("Heading 2\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("Heading 3\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("Table\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("contents\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("here\n", "n", false)
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, 5, false, {
                    "# Mdnotes Demo",
                    "Progress: 4/8 (Press <ESC> to stop demo)",
                    "",
                    "## Tables",
                    "Move, duplicate, delete, and insert columns:",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
                vim.fn.cursor(7, 1)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table column_move_right\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table column_duplicate\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table column_delete\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table column_move_right\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table column_insert_left\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 4/8 (Press <ESC> to stop demo)",
                    "",
                    "## Tables",
                    "Sort columns by ascending or descending:",
                    "",
                    "|Col1|Col2     |Col3      |",
                    "|----|---------|----------|",
                    "|A   |Column   |now       |",
                    "|C   |ascending|sorted    |",
                    "|B   |sorted   |descending|",
                    "|D   |now      |Column    |",
                    "",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(7, 1)
                vim.api.nvim_feedkeys(":Mdn table column_sort_ascending\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table column_sort_descending\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 4/8 (Press <ESC> to stop demo)",
                    "",
                    "## Tables",
                    "Toggle column alignment (more visible with a renderer):",
                    "",
                    "|Col1 with extra text to showcase alignment|",
                    "|------------------------------------------|",
                    "|A                                         |",
                    "|B                                         |",
                    "|C                                         |",
                    "",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table column_alignment_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table column_alignment_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table column_alignment_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn table column_alignment_toggle\n", "n", false)
            end,
            delay = 1000,
        },
        -- Tables Demo End
        -- Reference Link Demo Start
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 5/8 (Press <ESC> to stop demo)",
                    "",
                    "## Reference links",
                    "- Open [link.md][]",
                    "- Delete [link.md][]",
                    "- Insert new link",
                    "- Insert labels",
                    "- Update [link][]",
                    "- Cleanup unused",
                    "- Convert from inline links [convert](https://neovim.io/)",
                    "",
                    "[link.md]: link.md#fragment",
                    "[unused]: this is unused"
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(5, 8)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.cmd.write({mods = {silent = true}})
                vim.api.nvim_feedkeys(":Mdn reference_link open\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                require('mdnotes.history').go_back()
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(6, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn reference_link delete\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(7, 14)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.setreg("+", "https://neovim.io/")
                vim.api.nvim_feedkeys(":Mdn reference_link insert\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(8, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn reference_link insert link\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(9, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn reference_link update_definition\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("new link", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("new destination", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(10, 1)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn reference_link cleanup\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(11, 29)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn reference_link convert_from_inline\n", "n", false)
            end,
            delay = 1000,
        },
        -- Reference Link Demo End
        -- Footnotes Demo Start
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 6/8 (Press <ESC> to stop demo)",
                    "",
                    "## Footnotes",
                    "- Insert  ",
                    "- Update [^5]",
                    "- Cleanup",
                    "- Renumber",
                    "- Go to [^5]",
                    "- Find references [^5]",
                    "",
                    "[^5]: Footnote 5",
                    "[^unused]: Unused footnote",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(5, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn footnote insert\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("anew footnote" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(6, 10)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn footnote update\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("100", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(ctrl_u, "n", false)
                vim.api.nvim_feedkeys("updated text", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys("\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(7, 1)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn footnote cleanup\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(8, 1)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn footnote renumber\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(9, 9)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn footnote go_to\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(10, 19)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn footnote find_references\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.cmd([[ccl]])
            end,
            delay = 1000,
        },
        -- Footnotes Demo End
        -- ToC Demo Start
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 7/8 (Press <ESC> to stop demo)",
                    "",
                    "## Table of Contents",
                    "- Create and update",
                    "",
                    ""
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(7, 1)
                vim.cmd.write({mods = {silent = true}})
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn toc generate\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(5, 1)
                vim.api.nvim_feedkeys("o## New Heading" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(8, 1)
                vim.cmd.write({mods = {silent = true}})
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn toc update\n", "n", false)
            end,
            delay = 1000,
        },
        -- ToC Demo End
        -- Outliner Demo Start
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Progress: 8/8 (Press <ESC> to stop demo)",
                    "",
                    "## Outliner",
                    "- Item",
                    "- Item",
                    "- Item",
                    "- Item",
                })
                vim.api.nvim_feedkeys("i" .. esc, "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(7, 1)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn outliner indent\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.fn.cursor(6, 1)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn outliner indent\n", "n", false)
            end,
            delay = 1000,
        },
        {
            action = function()
                vim.api.nvim_feedkeys(":Mdn outliner unindent\n", "n", false)
            end,
            delay = 1000,
        },
        -- Outliner Demo End
        {
            action = function()
                vim.api.nvim_buf_set_lines(demo_buf, 0, -1, false, {
                    "# Mdnotes Demo",
                    "Fin!",
                })
            end,
            delay = 1000,
        },
        {
            action = function()
                stop_demo()
            end,
            delay = 1,
        },
    })
end

return M
