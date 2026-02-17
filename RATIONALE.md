# Mdnotes Rationale
In this document I explain certain design decisions for `mdnotes` and how they differ from an Obsidian-like approach.

## Using Current File's Directory
In most note-taking apps, the notes directory is designated within its options or configuration. I chose to use the current file's directory in `mdnotes` for the following reasons,

- No configuration needed so you can create wikis anywhere on any machine
- Easily create small local wikis
- WikiLinks or inline links are directly linked to the file's location, which works like a filesystem
- Functionality like global rename, backlinks, etc. are scoped to the current file's directory

Essentially the plugin treats a directory as a namespace, instead of using a vault model.

## Using LSPs
The main reason I started this project was dissatisfaction with Markdown LSPs at the time, and I really wanted to use Neovim as my notes editor. Therefore, `mdnotes` is designed to work with Markdown LSPs by trying to fill the gaps and to also complement their current functionality. Unfortunately, I don't think the Markdown LSPs are there yet, so the default behaviour of the plugin is to have `prefer_lsp = false`. Please see the table below for how `mdnotes` tries to work with LSPs and Neovim itself.

|Feature                         |mdnotes                              |LSP                                                        |Neovim                                                                 |
|--------------------------------|-------------------------------------|-----------------------------------------------------------|-----------------------------------------------------------------------|
|Showing references              |Y (`:Mdn wikilink show_references`)           |Y (`:h vim.lsp.buf.references()` or `grr`)                 |N                                                                      |
|Rename links to current buffer  |Y (`:Mdn wikilink rename_references`)         |Y (`:h vim.lsp.buf.rename()` or `grn`, markdown-oxide only)|N                                                                      |
|Rename links to hovered WikiLink|Y (`:Mdn wikilink rename_references`)         |? (`:h vim.lsp.buf.rename()`, should work but it does not) |N                                                                      |
|Buffer History                  |Y (Sequential `:Mdn history go_back/forward`)|N                                                          |Y (Not Sequential `:h bp`/`:h bn`                                      |
|Path Completion                 |N                                    |Y (`:h lsp-completion`)                                    |Y (`:h i_CTRL-X_CTRL-F`)                                               |
|Opening WikiLinks               |Y (`:Mdn wikilink follow`)             |Y (`:h vim.lsp.buf.definition()` or `CTRL-]`)              |Y (`:h gf`, needs .md extension in link, requires settings for Windows)|
 
 **Note:** Not all of the features of `mdnotes` are listed in this table, just the ones that are relevant to this section. Some LSPs provide more than just LSP features and their documentation should also be referenced along with this table.

