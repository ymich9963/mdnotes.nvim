# 🦠 Editing Tables
`mdnotes` tries to complement Neovim functionality to make editing tables as easy as possible. See the table below for what functions Neovim does and what functions are done by `mdnotes`.

|Feature             |mdnotes                                  |Neovim                |
|--------------------|-----------------------------------------|----------------------|
|Insert empty rows   |Y (`:Mdn table row_insert_above/below`)  |N                     |
|Duplicate row       |N                                        |Y (`:h yy`)           |
|Delete row          |N                                        |Y (`:h dd`)           |
|Move row            |N                                        |Y (`:h dd` and `:h p`)|
|Insert empty columns|Y (`:Mdn table column_insert_left/right`)|N                     |
|Duplicate column    |Y (`:Mdn table column_duplicate`)        |Y (`:h visual-block`) |
|Delete column       |Y (`:Mdn table column_delete`)           |Y (`:h visual-block`) |
|Move column         |Y (`:Mdn table column_move_left/right`)  |N                     |


 **Note:** Not all of the features of `mdnotes` are listed in this table, just the ones that are relevant to this section.

