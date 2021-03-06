local M = {}
local cfg = {
    split_size = 20,
    split_cmd = 'split',
    follow = true,
    sticky_cursor = false
}

M.setup = function(config)
    if config.follow ~= nil then cfg.follow = config.follow end
    if config.sticky_cursor ~= nil then
        cfg.stick_cursor = config.stick_cursor
    end
    if config.split_size then cfg.split_size = config.split_size end
    if config.split_cmd then cfg.split_cmd = config.split_cmd end
    cfg.ftypes = config.ftypes
end

local function get_parent_directory(dir)
    local parent = dir:match("(.*)/")
    if parent == nil then return nil end
    return parent
end

local function find_dir_of_file(pattern, dir)
    local file = dir .. "/" .. pattern

    if vim.fn.filereadable(file) == 1 then return {dir = dir, files = {file}} end

    local files = vim.fn.glob(file)
    if #files > 0 then return {dir = dir, files = files} end

    local parent = get_parent_directory(dir)
    if parent == nil then return nil end
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
    if string.find(path, " ") or string.find(path, '"') or
        string.find(path, "'") or string.find(path, "|") then
        local escaped_path = path:gsub("'", "\\'"):gsub('"', '\\\\\\"'):gsub(
                                 " ", "\\ "):gsub("|", "\\|")
        return '\\"' .. escaped_path .. '\\"'
    end
    return path
end

--- Escapes the current workdir before inserting into 'term://' command.
function M.escape_cwd(path)
    -- path ends with /
    local cpath = path
    if string.sub(path, -1) ~= "/" then cpath = cpath .. "/" end
    return cpath:gsub("'", "\\'"):gsub('"', '\\"'):gsub("/", "\\/")
end

local function first_key_in(key, ...)
    for _, k in ipairs({...}) do if k[key] ~= nil then return k[key] end end
    return nil
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
                if found == nil then
                    found = {dir = nil, files = {}}
                end

                local root = found.dir
                local files = found.files
                local fn_attrs = {
                    currentFile = current,
                    root = root,
                    files = files,
                    args = arguments,
                    file_escape = M.escape_run_file
                };
                if root ~= nil then
                    local task_attrs = attrs[task]
                    local cmd = nil;
                    if task_attrs == nil then
                        print(
                            "Task '" .. task .. "' not found for filetype '" ..
                                filetype .. "' and file '" .. current .. "'")
                        return
                    end
                    if task_attrs.cmd_function ~= nil then
                        cmd = task_attrs.cmd_function(fn_attrs)
                    else
                        cmd = task_attrs.cmd
                    end
                    if cmd == nil then
                        print(
                            "Command definition not found for task '" .. task ..
                                "' and filetype '" .. filetype ..
                                "'. Make sure you have a 'cmd' or 'cmd_function' (and 'cmd_function' returns command string) key in your config.")
                        return
                    end

                    cmd = cmd:gsub("%$file", M.escape_run_file(current))

                    local cwd = M.escape_cwd(root)

                    local launch_config = {
                        split_size = first_key_in('split_size', task_attrs,
                                                  attrs, cfg),
                        split_cmd = first_key_in('split_cmd', task_attrs, attrs,
                                                 cfg),
                        follow = first_key_in('follow', task_attrs, attrs, cfg),
                        sticky_cursor = first_key_in('sticky_cursor',
                                                     task_attrs, attrs, cfg)
                    }
                    if launch_config.follow then
                        cmd = cmd .. '|$'
                    end
                    if launch_config.sticky_cursor then
                        cmd = cmd .. '|wincmd p'
                    end

                    vim.cmd('belowright ' .. launch_config.split_size ..
                                launch_config.split_cmd .. ' term://' .. cwd ..
                                '/' .. cmd)
                    if task_attrs.after ~= nil then
                        task_attrs.after(fn_attrs)
                    end
                    return
                end
            end
        end
    end
    print('No run configuration found for filetype \'' .. filetype ..
              '\' and file \'' .. current .. '\'')
end

return M
