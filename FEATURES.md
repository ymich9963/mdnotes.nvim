# 🔥 Features
All the features of `mdnotes` and their associated commands are listed and categorised below.

## 🔗 Inline Links
- Open inline links to files and URLs with `:Mdn inline_link open`.
- Toggle inline links with `:Mdn inline_link toggle` which pastes your copied text over the selected text or word under cursor. This command also removes the inline link and saves it to be used later with the same command.
- Rename the link text with `:Mdn inline_link rename`. 
- Re-link the inline link with `:Mdn inline_link relink`. 
- Normalize an inline link with `:Mdn inline_link normalize` to have consistent paths. 
- Validate an inline link without opening it by executing `:Mdn inline_link validate`. This ensures that your inline link has a valid destination.
- Convert an inline link with a fragment to a [GFM-style fragment](https://github.github.com/gfm/#example-510) with `Mdn inline_link convert_fragment_to_gfm`. Useful when using LSP auto-completion and you want to create valid Markdown links on GitHub.
- Go to an inline link in the current buffer with `:Mdn inline_link go_to` or specify it using `:Mdn inline_link go_to [inline_link]`. Defaults to Neovim picker.

## 🖇️ WikiLinks
- Create a WikiLink by highlighting or hovering over a word and executing `:Mdn wikilink create`.
- Open WikiLinks with `:Mdn wikilink follow/_hor/_vert`. Use the `_hor/_vert` variations of the command to open WikiLinks in a horizontal or vertical split.
- Rename link references and the file itself using `:Mdn wikilink rename_references`. Also rename references of the current buffer when not hovering over a Wikilink.
- Show the references of a Wikilink by hovering over the link and executing `:Mdn wikilink show_references`. Also show references of the current buffer when not hovering over a Wikilink.
- Undo the most recent reference rename with `:Mdn wikilink undo_rename`. **Only** available when `prefer_lsp = false`.
- Delete the WikiLink under the cursor with `:Mdn wikilink delete`. 
- Normalize your WikiLink path with `:Mdn wikilink normalize`. 
- Find orphan pages (pages with no references) in current directory with `:Mdn wikilink find_orphans`. 
- Go to a WikiLink in the current buffer with `:Mdn wikilink go_to` or specify it using `:Mdn wikilink go_to [wikilink]`. Defaults to Neovim picker.

## 👩‍💼 Asset Management
- Insert an image or file from clipboard using `:Mdn assets insert` which creates the appropriate link and copies or moves the image to your assets folder. Requires `xclip` or `wl-clipboard` for Linux.
- Specify an asset in your assets directory with `:Mdn assets insert [asset]` to insert it. Supports autocompletion.
- Use `:Mdn assets unused_delete` to easily cleanup assets that you no longer use.
- Use `:Mdn assets unused_move` to move unused assets to a separate folder.
- Open your assets folder using `:Mdn assets open_containing_folder`. 
- Download website HTML to your assets folder with `:Mdn assets download_website_html`.
- Delete the asset in the inline link under the cursor with `:Mdn assets delete`.
- View an asset in your assets direcory with `:Mdn assets view` or specify it using `:Mdn assets view [asset]`. Currently uses the default Neovim picker.

## 🫦 Tables
- See [TABLES.md](TABLES.md) for how `mdnotes` integrates with Neovim to edit tables.
- Create a `ROW` by `COLS` table with `:Mdn table create ROW COLS`.
- Automatting setting of the best fit of your columns so that all your cells line up (opt-out). Can also be done manually with `:Mdn table best_fit` and can also add padding around your cells (`table_best_fit_padding` in config).
- Insert columns to the left or right of your current column with `:Mdn table column_insert_left/right`.
- Move columns to the left or right of your current column with `:Mdn table column_move_left/right`.
- Delete current column with `:Mdn table column_delete`.
- Duplicate current column with `:Mdn table column_duplicate`.
- Toggle column alignment with `:Mdn table column_alignment_toggle`.
- Sort the table by the current column ascending or descending with `:Mdn table column_sort_ascending/descending`. Can also use the API to create custom sorting.
- Insert empty rows to the above or below of your current line with `:Mdn table row_insert_above/below`.

## 🧭 General Navigation
- Set your index and journal files and go there with `:Mdn index` and `:Mdn journal`.
- Can go backwards and forwards in notes history by using `:Mdn history go_back` and  `:Mdn history go_forward`.
- Use `:Mdn heading next/previous` to easily navigate headings. 

## 💁 Formatting
- Toggle the appropriate formatting with `:Mdn formatting strong/emphasis/inline_code/strikethrough/autolink_toggle`.
- Automatically continue your ordered/unordered/task lists. Works with `<CR>`, `o`, and `O` and can be disabled.
- Automatically renumber your ordered lists (`auto_list_renumber = true` by default, can also be done manually).
- Toggle through checked, unchecked, and no checkbox in a list item with `:Mdn formatting task_list_toggle`. Also works with linewise visual mode to toggle multiple tasks at a time.
- Unformat your line(s) with `:Mdn formatting unformat_lines`. 

## Table of Contents
- Generate and insert at the cursor a Table Of Contents (ToC) for the current Markdown buffer with `:Mdn toc generate`. Can also customise the depth of the ToC by changing the `toc_depth = 4` or by specifying the depth in the command e.g. `:Mdn toc generate 2`.
- Update a ToC in-place with `:Mdn toc update`. Optionally specify the new depth with `:Mdn toc update X`.
- Browse the ToC as a location list using `:Mdn toc browse`.

## 🧍‍♂️ Uncategorised
- Implements an outliner mode by doing `:Mdn outliner_toggle`. Make sure to exit afterwards by re-toggling. Can also use outliner-like indentation with `:Mdn outliner indent/unindent`.
- Journal entries are automatically inserted to the journal file, but can also be done manually with `:Mdn journal insert_entry`. 
- Open your folder containing the current file with `:Mdn miscellaneous open_containing_folder`. 
- Tips for repeating last command, find/replace words, finding tags, and finding files, can be found in [TIPS.md](TIPS.md).
- Opt-in use of existing Markdown LSP functions by setting `prefer_lsp = true`.
- Supports Windows eccentricities.
- Create user commands within the `:Mdn user` namespace for better organisation.
- See `:h mdnotes-wikilink-graphs` for a starter Python script for creating a node graph to visualise your WikiLinks.
- View statistics of current buffer with `:Mdn miscellaneous statistics` which shows number of bytes, characters, words, lines, inline links, WikiLinks, and headings.
- Exposes most internal functions to provide an API as to allow an extensible note-taking experience. See `:h mdnotes-api` for function documentation and `:h mdnotes-api-examples` for example usage.

