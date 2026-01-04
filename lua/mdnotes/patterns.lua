local M = {}

local fi_emphasis = function() return require('mdnotes.formatting').format_indicators.emphasis() end
local fi_strong = function() return require('mdnotes.formatting').format_indicators.strong():sub(1,1) end

M = {
    wikilink = "()%[%[(.-)%]%]()",
    uri_no_fragment = "^([^#]+).*",
    fragment = "#(.*)",
    inline_link = "()(%[.+%]%([^%)]+%))()",
    text_uri = "%[([^%]]+)%]%((.+)%)",
    strong = "()%" .. fi_strong() .. "%" .. fi_strong() .. "([^%" .. fi_strong() .. "].-)%" .. fi_strong() .. "%" .. fi_strong() .. "()",
    emphasis = "()%" .. fi_emphasis() .. "([^%" .. fi_emphasis() .. "].-)%" .. fi_emphasis() .."()",
    strikethrough = "()~~(.-)~~()",
    inline_code = "()`([^`]+)`()",
    unordered_list = "^([%s]-)([-+*])[%s](.+)",
    ordered_list = "^([%s]-)([%d]+)([%.%)])[%s]-(.+)",
    task = "[%s]-(%[[ xX]%])[%s].-",
    heading = "^([%#]+)[%s]+(.+)",
}

return M
