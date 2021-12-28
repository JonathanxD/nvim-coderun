return require('packer').startup(function(use)
  use 'JonathanxD/nvim-coderun'
  if packer_plugins['nvim-coderun'] and packer_plugins['nvim-coderun'].loaded then
    local cargo = function(cargo_cmd, args)
      if next(args) == nil then
        return 'cargo ' .. cargo_cmd
      end
      local cmd = 'cargo '..cargo_cmd..' ' .. table.concat(args, ' ')
      return cmd
    end

    require('nvim-coderun').setup {
      ftypes = {
        rust = {
          files = {'Cargo.toml'},
          run = {
            cmd_function = function(attrs)
              return cargo('run', attrs.args)
            end
          },
          build = {
            cmd_function = function(attrs)
              return cargo('build', attrs.args)
            end
          },
        },
        vlang = {
          files = {'v.mod'},
          run = {cmd = 'v run $file' },
          build = { cmd = 'v .' }
        },
        nim = {
          files = {'*.nimble'},
          run = {cmd = 'nimble run' },
          build = { cmd = 'nimble build' }
        },
        kotlin = {
          files = {'*.gradle', '*.gradle.kts'},
          run = {cmd = 'gradle run' },
          build = { cmd = 'gradle build' }
        },
        go = {
          files = { 'go.mod' },
          run = {
            cmd_function = function(attrs)
              print(vim.inspect(attrs.args))
              return 'go run ' .. attrs.file_escape(attrs.currentFile)
            end
          },
          build = { cmd = 'go build' }
        }
     }
  }
  end
end)
