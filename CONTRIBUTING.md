# Contributing to TinyDebian Live

Thank you for considering contributing to TinyDebian Live! Here's how you can help.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/Mini-Linux-OS.git`
3. Create a branch: `git checkout -b feature/your-feature-name`

## Making Changes

### For Documentation

- Update README.md for major user-facing changes
- Update docs/ directory for detailed guides
- Keep examples clear and tested

### For the Build Script

- Test changes thoroughly (requires root and 15+ GB disk space)
- Add comments explaining non-obvious sections
- Keep changes focused on specific functionality
- Test on both Debian 12 and Ubuntu 22.04+

### For New Features

Before making significant changes:
1. Open an issue to discuss the feature
2. Get feedback from the maintainers
3. Then proceed with implementation

Feature suggestions:
- Additional language support (keyboard layouts)
- More pre-installed applications
- Alternative desktop environments
- Cloud/VM integration improvements
- Build optimization

## Commit Messages

Write clear commit messages:
```
Add Arabic keyboard layout persistence option

This allows users to save their keyboard layout choice
across reboots using the persistence feature.
```

## Pull Request Process

1. Ensure your code follows the existing style
2. Test your changes thoroughly
3. Update documentation as needed
4. Create a PR with a clear description
5. Link any related issues
6. Wait for review and feedback

## Testing

### Before Submitting

- Build the ISO: `sudo ./scripts/build-tinydebian.sh`
- Boot from USB in VirtualBox or on real hardware
- Test the specific feature you modified
- Verify persistence works
- Test VMware clipboard if applicable

### What to Test

- Desktop environment boots correctly
- Network manager can connect to WiFi
- Audio works (test with a music file)
- Firefox launches and loads websites
- Persistence partition saves files
- Resolution auto-adjusts on boot
- Package manager (apt) works
- Terminal and text editor function properly

## Issues and Bugs

Found a bug? Please open an issue with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Your system details (host OS, VM software if applicable)
- Logs or error messages

## Code Style

For bash scripts:
- Use `set -e` for error handling
- Add comments for complex sections
- Quote variables: `"$VAR"` not `$VAR`
- Use 4-space indentation
- Check for shellcheck warnings: `shellcheck scripts/build-tinydebian.sh`

## Documentation

Documentation changes are valuable! You can:
- Fix typos
- Improve examples
- Add troubleshooting steps
- Translate guides (create docs/LANG/ folders)
- Add beginner-friendly explanations

## Community

Be respectful and constructive. We welcome:
- Questions and discussion
- Feature suggestions
- Bug reports
- Documentation improvements
- Code optimizations

We're building this for the Linux community together.

## License

By contributing, you agree that your contributions will be licensed under the MIT License (same as the project).

## Questions?

Feel free to:
- Open an issue for questions
- Check existing issues and documentation
- Join discussions on pull requests

Thank you for contributing to TinyDebian Live!
