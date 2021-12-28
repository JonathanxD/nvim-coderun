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

  require('nvim-coderun').setup{}
end)
```

See the help manual with `:help nvim-coderun` for more information.
