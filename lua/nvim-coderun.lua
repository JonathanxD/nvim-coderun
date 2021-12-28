local M = {}
local cfg = {}

M.setup = function(config)
  cfg = config
end

local function get_parent_directory(dir)
  local parent = dir:match("(.*)/")
  if parent == nil then
    return nil
  end
  return parent
end

local function find_dir_of_file(pattern, dir)
  local file = dir .. "/" .. pattern

  if vim.fn.filereadable(file) == 1 then
    return { dir = dir, files = { file } }
  end

  local files = vim.fn.glob(file)
  if #files > 0 then
    return { dir = dir, files = files }
  end


  local parent = get_parent_directory(dir)
  if parent == nil then
    return nil
  end
  return find_dir_of_file(pattern, parent)
end

function M.find_parent(pattern)
  local current = vim.fn.getcwd()
  return find_dir_of_file(pattern, current)
end

--- Escapes a file path before inserting into the command with string replace.
-- This is needed because 'term://' uses blank space as a delimiter for argument separation, thus
-- file paths with spaces becomes multiple arguments instead of a single one.
-- Also, single and double quotes are not passed to the command if they are not escaped,
-- so this function escapes them.
-- For example, given the following scenarios:
-- '/home/foo/myproject/my file.go' is escaped to: '\"/home/foo/myproject/my\ file.go\"'
-- '/home/foo/myproject/my'file.go' is escaped to: '\"/home/foo/myproject/my\'file.go'\"'
-- '/home/foo/myproject/my"file.go' is escaped to: '\"/home/foo/myproject/my\\\"file.go'\"'
-- '/home/foo/myproject/my'"file.go' is escaped to: '\"/home/foo/myproject/my\'\\\"file.go'\"'
function M.escape_run_file(path)
  if string.find(path, " ") or string.find(path, '"') or string.find(path, "'") then
    local escaped_path = path:gsub("'", "\\'"):gsub('"', '\\\\\\"'):gsub(" ", "\\ ")
    return '\\"' .. escaped_path .. '\\"'
  end
  return path
end

--- Escapes the current workdir before insertingo into 'term://' command.
function M.escape_cwd(path)
  -- path ends with /
  local cpath = path
  if string.sub(path, -1) ~= "/" then
    cpath = cpath .. "/"
  end
  return cpath:gsub("'", "\\'"):gsub('"', '\\"'):gsub("/", "\\/")
end

function M.run(rtask, ...)
  local task = rtask or "run"
  local current = vim.fn.expand('%:p')
  local filetype = vim.bo.filetype
  local arguments = {...} or {}

  for name, attrs in pairs(cfg.ftypes) do
    if name == filetype then
      for _, file in pairs(attrs.files) do

        local found = M.find_parent(file)
        local root = found.dir
        local files = found.files

        if root ~= nil then
          local cmd = attrs[task]
          if cmd == nil then
            print("Task '" .. task .. "' not found for filetype '" .. filetype .. "' and file '" .. current .. "'")
            return
          end
          if cmd.cmd_function ~= nil then
            cmd = cmd.cmd_function({
              currentFile = current,
              root = root,
              files = files,
              args = arguments,
              file_escape = M.escape_run_file
            })
          else
            cmd = cmd.cmd
          end

          cmd = cmd:gsub("%$file", M.escape_run_file(current))

          local cwd = M.escape_cwd(root)

          vim.cmd('belowright 8split term://' .. cwd .. '/' .. cmd)
          return
        end
      end
    end
  end
  print('No run configuration found for filetype \'' .. filetype .. '\' and file \'' .. current .. '\'')
end

return M
