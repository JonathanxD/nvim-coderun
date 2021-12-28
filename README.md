# nvim-coderun

A nvim plugin for customizing run commands for different
programming languages.

## How it works

`nvim-coderun` searches for a specific file in directory ancestors to
determine the project root, then it runs the configured command with
the found folder as the workdir.

## Installing

### Packer

```lua
return require('packer').startup(function(use)
  use 'JonathanxD/nvim-coderun'
end)
```

## Configuration

```lua
return require('packer').startup(function(use)
  use 'JonathanxD/nvim-coderun'

  require('nvim-coderun').setup{
    ftypes = {
      rust = {
        files = { 'Cargo.toml' },
        run = { cmd = 'cargo run' }
      }
    }
  }
end)
```


```lua
return require('packer').startup(function(use)
  use 'JonathanxD/nvim-coderun'

  require('nvim-coderun').setup{
    ftypes = {
      rust = {
        files = { 'Cargo.toml' },
        run = { 
          cmd_function = function(attrs)
            if next(attrs.args) == nil then
              return 'cargo run'
            end
            return 'cargo run ' .. table.concat(attrs.args, ' ')
          end          
        }
      }
    }
  }
end)
```


See the help manual with `:help nvim-coderun` for more information.
