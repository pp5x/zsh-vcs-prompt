# ZSH VCS Prompt

A fast, intelligent zsh prompt that provides VCS-aware path display with smart truncation and multi-level repository support.

## Features

- **Multi-VCS Support**: Detects Git (`.git`), Jujutsu (`.jj`), and Repo (`.repo`) repositories
- **Smart Path Truncation**: Non-final path components are truncated to single letters (e.g., `/usr/local/bin` → `/u/l/bin`)
- **Nested VCS Detection**: Handles multiple nested VCS repositories with proper coloring
- **HOME Directory Support**: Displays `~` for home directory paths
- **Performance Optimized**: Lightweight implementation for fast prompt rendering
- **Color-Coded**: Different colors for different VCS types:
  - **Git**: Blue
  - **Jujutsu**: Magenta  
  - **Repo**: Green

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/zsh-vcs-prompt.git
   cd zsh-vcs-prompt
   ```

2. Source the script in your `.zshrc`:
   ```bash
   source /path/to/zsh-vcs-prompt/rel_vcs_prompt.zsh
   ```

3. Reload your shell:
   ```bash
   source ~/.zshrc
   ```

## Examples

### Basic VCS Detection
```bash
# In a git repository
~/myproject $ 
# Displays: myproject (colored blue)

# In a subdirectory
~/myproject/src/components $ 
# Displays: myproject/s/components (myproject colored blue)
```

### Nested VCS Repositories
```bash
# Multiple VCS levels
~/company/teams/frontend/dashboard/src $ 
# Where: company/.git, dashboard/.jj
# Displays: company/t/f/dashboard/src (company=blue, dashboard=magenta)
```

### Path Truncation
```bash
# Long paths get truncated
~/documents/projects/website/src/components/common $ 
# Displays: ~/d/p/w/s/c/common

# System paths
/usr/local/bin $ 
# Displays: /u/l/bin
```

### Inside VCS Directories
```bash
# Working inside .git directory
~/myproject/.git/hooks $ 
# Displays: myproject/.g/hooks (myproject colored blue)
```

## How It Works

### VCS Detection
The prompt walks up the directory tree from the current location, detecting VCS directories:
- `.git` (Git repositories)
- `.jj` (Jujutsu repositories) 
- `.repo` (Repo tool repositories)

### Path Processing
1. **VCS Mode**: When in a VCS repository, the outermost VCS root becomes the base
2. **Path Truncation**: All non-final directory components are truncated to their first letter
3. **Dotfile Handling**: Dotfiles like `.config` become `.c`
4. **Coloring**: VCS root directories are colored according to their type

### Nested VCS Support
When multiple VCS repositories are nested, each VCS root directory gets colored appropriately while maintaining the path structure.

## Testing

The project includes comprehensive test coverage using [zunit](https://github.com/zunit-zsh/zunit):

```bash
# Install zunit (if not already installed)
# Run tests
zunit run tests/vcs_prompt.zunit
```

### Test Categories
- **Unit Tests**: Individual feature testing (VCS detection, path truncation, HOME handling)
- **Integration Tests**: Feature combinations (VCS + truncation, nested VCS)
- **Complex Scenarios**: Edge cases (duplicate names, inside VCS directories, special cases)

## Configuration

The prompt uses these color codes by default:
- Git: `%F{blue}`
- Jujutsu: `%F{magenta}`
- Repo: `%F{green}`

To customize colors, modify the `get_vcs_color()` function in `rel_vcs_prompt.zsh`.

## Performance

This implementation is optimized for speed:
- Minimal external command usage
- Efficient path traversal
- Cached VCS detection
- Lightweight string operations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Changelog

### Latest
- Comprehensive test suite with 22 test cases
- Support for inside VCS directory navigation
- Improved nested VCS detection algorithm
- Enhanced path truncation logic

### Previous Versions
- Added Jujutsu (`.jj`) support
- Implemented Repo tool (`.repo`) support  
- Added HOME directory handling
- Initial Git support and path truncation