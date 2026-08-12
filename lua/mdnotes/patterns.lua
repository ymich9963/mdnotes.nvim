---@module 'mdnotes.patterns'

local M = {}

---@alias MdnPattern string Lua pattern that returns the start and end columns, as well as the text
---@alias MdnLinePattern string Lua pattern that checks an entire line
---@alias MdnSubPattern string Lua pattern that checks small sub-sections of the string

---@class MdnPatterns
---@field wikilink MdnPattern WikiLink pattern
---@field inline_link MdnPattern Inline link pattern
---@field strong MdnPattern Strong format delimiter pattern
---@field emphasis MdnPattern Emphasis format delimiter pattern
---@field strikethrough MdnPattern Strikethrough format delimiter pattern
---@field inline_code MdnPattern Inline code format delimiter pattern
---@field autolink MdnPattern Autolink format delimiter pattern
---@field reference_link MdnPattern Reference link format delimiter pattern
---@field footnote_reference MdnPattern Footnote reference format delimiter pattern
---@field heading MdnLinePattern Heading pattern
---@field unordered_list MdnLinePattern Unordered list pattern
---@field ordered_list MdnLinePattern Ordered list pattern
---@field reference_link_definition MdnLinePattern Reference link definition pattern
---@field code_fence MdnLinePattern Code fence pattern
---@field footnote MdnLinePattern Footnote pattern
---@field text_dest MdnSubPattern Text and destination from inline link pattern
---@field dest_title MdnSubPattern Title from inline link destination
---@field dest_no_fragment MdnSubPattern destination only pattern
---@field fragment MdnSubPattern Fragment only pattern
---@field wikilink_alias MdnSubPattern WikiLink alias
---@field task MdnSubPattern Task item pattern
M = {
    wikilink = "()(%[%[.-%]%])()",
    inline_link = "()([!]?%[[^%]]+%]%([^%)]+%))()",
    strong = "()[%*_][%*_]([^%*_].-)[%*_][%*_]()",
    emphasis = "()[%*_]([^%*_].-)[%*_]()",
    strikethrough = "()~~(.-)~~()",
    inline_code = "()`([^`]+)`()",
    autolink = "()<(.-)>()",
    reference_link = "()(%[[^%]]+%]%[[^%]]-%])()",
    footnote_reference = "()(%[^[^%]]+%])()",

    heading = "^([%#]+)[%s]+(.+)",
    unordered_list = "^([%s]-)([-+*])[%s](.*)",
    ordered_list = "^([%s]-)([%d]+)([%.%)])[%s](.*)",
    reference_link_definition = "^%[([^%]]+)%]:%s?(.+)",
    code_fence = "^```.-",
    footnote = "^%[^([^%]]+)%]:%s?(.+)",

    text_dest = "%[([^%]]+)%]%((.+)%)",
    dest_title = ".+%s\"([^\"]*)\"",
    dest_no_fragment = "^([^#]+).*",
    fragment = "#([^|]*)",
    wikilink_contents = "%[%[(.-)%]%]",
    wikilink_alias = ".+|([^|]+)",
    task = "[%s]-(%[[ xX]%])[%s]+.-",
    text_label = "%[([^%]]+)%]%[(.-)%]",
    footnote_identifier = "%[^([^%]]+)%]",
}

return M
