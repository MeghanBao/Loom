# Contributing to Loom

Thank you for your interest in contributing to Loom! 🧵

## Getting Started

```bash
git clone https://github.com/MeghanBao/loom
cd loom
mix deps.get
mix test
```

## Development Workflow

1. **Fork** the repo and create a branch from `main`
2. **Write tests** for any new functionality
3. **Run tests** with `mix test`
4. **Format code** with `mix format`
5. **Submit a PR** with a clear description

## Code Style

- Follow standard Elixir conventions
- Run `mix format` before committing
- Write `@moduledoc` and `@doc` for public modules and functions
- Add typespecs (`@spec`) for public functions

## Reporting Issues

- Use GitHub Issues
- Include Elixir/OTP version (`elixir --version`)
- Provide a minimal reproduction if possible

## Architecture

See the [README](README.md) for an architecture overview. Key modules:

| Module | Responsibility |
|--------|---------------|
| `Loom.Agent` | Agent behaviour and execution |
| `Loom.Workflow.Graph` | DAG construction and topological sort |
| `Loom.Workflow.Executor` | Parallel step execution |
| `Loom.Scheduler` | Queue-based workflow dispatch |
| `Loom.LLM` | LLM provider abstraction |

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
