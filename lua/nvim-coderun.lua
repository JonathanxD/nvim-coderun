local M = {}

---@class UserConfig
---@field follow boolean|nil
---@field sticky_cursor boolean|nil
---@field split_size number|nil
---@field split_cmd string|nil
---@field windowed boolean|nil
---@field ftypes table<string, FTypeConfig>
local cfg = {
    split_size = 20,
    split_cmd = 'split',
    follow = true,
    sticky_cursor = false,
    windowed = false,
}

M.setup = function(config)
    if config.follow ~= nil then cfg.follow = config.follow end
    if config.sticky_cursor ~= nil then
        cfg.stick_cursor = config.stick_cursor
    end
    if config.split_size then cfg.split_size = config.split_size end
    if config.split_cmd then cfg.split_cmd = config.split_cmd end
    if config.windowed then cfg.windowed = config.windowed end
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

function M.find_from_cwd(pattern)
    local current = vim.fn.expand('%:p:h')
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


---@class BufOpts
---@field split_size number|nil
---@field split_cmd string|nil
---@field follow boolean|nil
---@field sticky_cursor boolean|nil
local BufOpts = {}

---@class Config
---@field root string root directory of the project
---@field cmd string command to run
---@field buf BufOpts buffer options
local Config = {}

---@param config Config
function M.create_cmd(config)
    local root = config.root
    local cmd = config.cmd
    local cwd = M.escape_cwd(root)
    local append_mode = config.buf.split_cmd ~= nil
    cmd = 'term://' .. cwd .. '/' .. cmd

    if config.buf.split_cmd then
        cmd = config.buf.split_cmd .. ' ' .. cmd
    end

    if config.buf.split_size and config.buf.split_cmd then
        cmd = config.buf.split_size .. cmd
    end

    if append_mode then
        if config.buf.follow then
            cmd = cmd .. '|$'
        end
        if config.buf.sticky_cursor then
            cmd = cmd .. '|wincmd p'
        end
    end

    return cmd
end

---@param config Config
function M.spawn_cmd(config)
    local cmd = M.create_cmd(config)
    cmd = 'belowright ' .. cmd
    vim.cmd(cmd)
end

local coderun_buf = vim.api.nvim_create_buf(false, true)

---@param config Config
function M.spawn_cmd_floating(config)
    local ui = vim.api.nvim_list_uis()[1]
    local width = math.floor(ui.width * 0.70)
    local height = math.floor(ui.height * 0.70)
    local win_id = vim.api.nvim_open_win(coderun_buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((ui.height - height) / 2),
        col = math.floor((ui.width - width) / 2),
        style = 'minimal',
        border = 'single',
    })
    vim.api.nvim_win_set_option(win_id, 'winhl', 'Normal:Normal')

    ---@type Config
    config = {
        root = config.root,
        cmd = config.cmd,
        buf = {
            split_size = nil,
            split_cmd = 'edit',
            follow = config.buf.follow,
            sticky_cursor = config.buf.sticky_cursor
        }
    }
    local cmd = M.create_cmd(config)
    vim.print(cmd)
    vim.cmd(cmd)
    --vim.api.nvim_command(cmd)
end

function M.run(rtask, ...)
    local task = rtask or "run"
    local current = vim.fn.expand('%:p')
    local filetype = vim.bo.filetype
    local arguments = {...} or {}

    for name, tld_attrs in pairs(cfg.ftypes) do
        if name == filetype then
            local tld_files = tld_attrs.files
            if tld_files ~= nil then
                tld_files = { tld_attrs }
            else
                tld_files = tld_attrs
            end
            local tld_files_count = #tld_files
            for i_attrs, attrs in ipairs(tld_files) do
                local is_last = i_attrs == tld_files_count
                local is_cwd = false
                for key, file in pairs(attrs.files) do
                    if key == "cwd" and file then
                        is_cwd = true
                        break
                    end
                end
                for key, file in pairs(attrs.files) do
                    if key == "cwd" then
                        goto continue
                    end

                    local pattern = file
                    local resolv = function()
                        return M.find_parent(pattern)
                    end
                    if is_cwd then
                        resolv = function()
                            return M.find_from_cwd(pattern)
                        end
                    end
                    local found = resolv()
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
                            if not is_last then
                                goto continue
                            end
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
                            if not is_last then
                                goto continue
                            end
                            print(
                                "Command definition not found for task '" .. task ..
                                    "' and filetype '" .. filetype ..
                                    "'. Make sure you have a 'cmd' or 'cmd_function' (and 'cmd_function' returns command string) key in your config.")
                            return
                        end

                        cmd = cmd:gsub("%$file", M.escape_run_file(current))

                        local cwd = M.escape_cwd(root)

                        ---@type BufOpts
                        local launch_config = {
                            split_size = first_key_in('split_size', task_attrs,
                                                      attrs, cfg),
                            split_cmd = first_key_in('split_cmd', task_attrs, attrs,
                                                     cfg),
                            follow = first_key_in('follow', task_attrs, attrs, cfg),
                            sticky_cursor = first_key_in('sticky_cursor',
                                                         task_attrs, attrs, cfg)
                        }

                        ---@type Config
                        local config = {
                            root = root,
                            cmd = cmd,
                            buf = launch_config
                        }
                        if cfg.windowed then
                            M.spawn_cmd_floating(config)
                        else
                            M.spawn_cmd(config)
                        end
                        if task_attrs.after ~= nil then
                            task_attrs.after(fn_attrs)
                        end
                        return
                    end
                    ::continue::
                end
            end
       end
    end
    print('No run configuration found for filetype \'' .. filetype ..
              '\' and file \'' .. current .. '\'')
end

return M
