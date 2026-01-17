---@module 'mdnotes.patterns'
local M = {}

local fi_emphasis = function() return require('mdnotes').config.emphasis_format end
local fi_strong = function() return require('mdnotes').config.strong_format:sub(1,1) end

---@alias MdnotesPattern string Pattern that returns the start and end columns, as well as the text

---@class MdnotesPatterns
---@field wikilink MdnotesPattern WikiLink pattern
---@field uri_no_fragment MdnotesPattern URI only pattern
---@field fragment MdnotesPattern Fragment only pattern
---@field inline_link MdnotesPattern Inline link pattern
---@field text_uri MdnotesPattern Text and URI from inline link pattern
---@field strong MdnotesPattern Strong format indicator pattern
---@field emphasis MdnotesPattern Emphasis format indicator pattern
---@field strikethrough MdnotesPattern Strikethrough format indicator pattern
---@field inline_code MdnotesPattern Inline code format indicator pattern
---@field autolink MdnotesPattern Autolink format indicator pattern
---@field unordered_list MdnotesPattern Unordered list pattern
---@field ordered_list MdnotesPattern Ordered list pattern
---@field task MdnotesPattern Task item pattern
---@field heading MdnotesPattern Heading pattern
M = {
    wikilink = "()%[%[(.-)%]%]()",
    uri_no_fragment = "^([^#]+).*",
    fragment = "#(.*)",
    inline_link = "()([!]?%[.+%]%([^%)]+%))()",
    text_uri = "%[([^%]]+)%]%((.+)%)",
    strong = "()%" .. fi_strong() .. "%" .. fi_strong() .. "([^%" .. fi_strong() .. "].-)%" .. fi_strong() .. "%" .. fi_strong() .. "()",
    emphasis = "()%" .. fi_emphasis() .. "([^%" .. fi_emphasis() .. "].-)%" .. fi_emphasis() .."()",
    strikethrough = "()~~(.-)~~()",
    inline_code = "()`([^`]+)`()",
    autolink = "()<(.-)>()",
    unordered_list = "^([%s]-)([-+*])[%s](.+)",
    ordered_list = "^([%s]-)([%d]+)([%.%)])[%s](.+)",
    task = "[%s]-(%[[ xX]%])[%s].-",
    heading = "^([%#]+)[%s]+(.+)",
}

return M
