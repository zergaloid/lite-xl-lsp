---@type core.doc
local Doc = require "core.doc"

---A partially readonly core.doc.
---@class lsp.helpdoc : core.doc
local HelpDoc = Doc:extend()

---Set the help text.
---@param text string
function HelpDoc:set_text(text)
  self.lines = {}
  local i = 1
  for line in text:gmatch("([^\n]*)\n?") do
    if line:byte(-1) == 13 then
      line = line:sub(1, -2)
      self.crlf = true
    end
    table.insert(self.lines, line .. "\n")
    self.highlighter.lines[i] = false
    i = i + 1
  end
  self:reset_syntax()
end

--Let user modify text, maybe to make it more legible?
-- function HelpDoc:raw_insert(...) end
-- function HelpDoc:raw_remove(...) end

function HelpDoc:load(...) end
function HelpDoc:reload() end
function HelpDoc:save(...) end


return HelpDoc
