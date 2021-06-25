-- Some functions adapted from: https://github.com/orbitalquark/textadept-lsp
-- and others added as needed.
--
-- @copyright Jefferson Gonzalez
-- @license MIT

local config = require "core.config"
local json = require "plugins.lsp.json"

local util = {}

--- Split a string by the given delimeter
--- @param s string The string to split
--- @param delimeter string Delimeter without lua patterns
--- @param delimeter_pattern string Optional delimeter with lua patterns
--- @return table List of results
function util.split(s, delimeter, delimeter_pattern)
  if not delimeter_pattern then
    delimeter_pattern = delimeter
  end

  local result = {};
  for match in (s..delimeter):gmatch("(.-)"..delimeter_pattern) do
    table.insert(result, match);
  end
  return result;
end

function util.file_extension(filename)
  local parts = util.split(filename, "%.")
  if #parts > 1 then
    return parts[#parts]:gsub("%%", "")
  end

  return filename
end

function util.file_exists(file_path)
  local file = io.open(file_path, "r")
  if file ~= nil then
    file:close()
    return true
  end
 return false
end

--- Converts the given LSP DocumentUri into a valid filename path.
--- @param uri string LSP DocumentUri to convert into a filename.
--- @return string Path of file
function util.tofilename(uri)
  local filename = ""
  if PLATFORM == "Windows" then
    filename = uri:gsub('^file:///', '')
  else
    filename = uri:gsub('^file://', '')
  end

  filename = filename:gsub(
    '%%(%x%x)',
    function(hex) return string.char(tonumber(hex, 16)) end
  )

  if PLATFORM == "Windows" then filename = filename:gsub('/', '\\') end

  return filename
end

function util.touri(filename)
  if PLATFORM ~= "Windows" then
    filename = 'file://' .. filename
  else
    filename = 'file:///' .. filename:gsub('\\', '/')
  end

  return filename
end

--- Converts a document range returned by lsp to a valid document selection.
--- @param range table LSP Range.
--- @return integer,integer,integer,integer
function util.toselection(range)
  local line1 = range.start.line + 1
  local col1 = range.start.character + 1
  local line2 = range['end'].line + 1
  local col2 = range['end'].character + 1

  return line1, col1, line2, col2
end

function util.jsonprettify(code)
  if config.lsp.prettify_json then
    code = json.prettify(code)
  end

  if config.lsp.log_file and #config.lsp.log_file > 0 then
    local log = io.open(config.lsp.log_file, "a+")
    log:write("Output: \n" .. tostring(code) .. "\n\n")
    log:close()
  end

  return code
end

--- Gets the last component of a path. For example:
--- /my/path/to/somwhere would return somewhere.
--- @param path string
--- @return string
function util.getpathname(path)
  local components = {}
  if PLATFORM == "Windows" then
    components = util.split(path, "\\")
  else
    components = util.split(path, "/")
  end

  if #components > 0 then
    return components[#components]
  end

  return path
end

function util.intable(value, table_array)
  for _, element in pairs(table_array) do
    if element == value then
      return true
    end
  end

  return false
end

function util.command_exists(command)
  local path_list = {}

  if util.file_exists(command) then
    return true
  end

  if PLATFORM ~= "Windows" then
    path_list = util.split(os.getenv("PATH"), ":")
  else
    path_list = util.split(os.getenv("PATH"), ";")
  end

  for _, path in pairs(path_list) do
    if util.file_exists(path .. PATHSEP .. command) then
      return true
    end
  end

  return false
end

function util.table_remove_key(table_object, key_name)
  local new_table = {}
  for key, data in pairs(table_object) do
    if key ~= key_name then
      new_table[key] = data
    end
  end

  return new_table
end

--- Get a table specific field or nil if not found.
--- @param t table The table we are going to search for the field.
--- @param fieldset string A field spec in the format
--- "parent[.child][.subchild]" eg: "myProp.subProp.subSubProp"
--- @return any|nil The value of the given field or nil if not found.
function util.table_get_field(t, fieldset)
  local fields = util.split(fieldset, ".", "%.")
  local field = fields[1]
  local value = nil

  if field and #fields > 1 and t[field] then
    local sub_fields = table.concat(fields, ".", 2)
    value = util.table_get_field(t[field], sub_fields)
  elseif field and #fields > 0 and t[field] then
    value = t[field]
  end

  return value
end

--- Merge the content of table2 into table1.
--- Solution found here: https://stackoverflow.com/a/1283608
--- @param t1 table
--- @param t2 table
function util.table_merge(t1, t2)
  for k,v in pairs(t2) do
    if type(v) == "table" then
      if type(t1[k] or false) == "table" then
        util.table_merge(t1[k] or {}, t2[k] or {})
      else
        t1[k] = v
      end
    else
      t1[k] = v
    end
  end
end

function util.table_empty(t)
  local found = false
  for _, value in pairs(t) do
    found = true
    break
  end
  return not found
end

function util.strip_markdown(text)
  local clean_text = ""
  for match in (text.."\n"):gmatch("(.-)".."\n") do
    match = match .. "\n"
    clean_text = clean_text .. match
      -- Block quotes
      :gsub("^>+(%s*)", "%1")
      -- headings
      :gsub("^(%s*)######%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)#####%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)####%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)####%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)###%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)##%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)#%s(.-)\n", "%1%2\n")
      -- bold and italic
      :gsub("%*%*%*(.-)%*%*%*", "%1")
      :gsub("___(.-)___", "%1")
      :gsub("%*%*_(.-)_%*%*", "%1")
      :gsub("__%*(.-)%*__", "%1")
      :gsub("___(.-)___", "%1")
      -- bold
      :gsub("%*%*(.-)%*%*", "%1")
      :gsub("__(.-)__", "%1")
      -- italic
      :gsub("%*(.-)%*", "%1")
      :gsub("_(.-)_", "%1")
      -- code
      :gsub("^%s*```(%w+)%s*\n", "")
      :gsub("^%s*```%s*\n", "")
      :gsub("``(.-)``", "%1")
      :gsub("`(.-)`", "%1")
      -- lines
      :gsub("^%-%-%-%-*%s*\n", "")
      :gsub("^%*%*%*%**%s*\n", "")
      -- Images
      :gsub("!%[(.-)%]%((.-)%)", "")
      -- links
      :gsub("<(.-)>", "%1")
      :gsub("%[(.-)%]%((.-)%)", "%1: %2")
  end
  return clean_text
end


return util
