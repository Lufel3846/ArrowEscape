---
version: "0.1.2"
level: pair
processes:
  design: pair
  implementation: pair
  documentation: pair
  testing: pair
  review: human
  deployment: human
---

This format is based on [AI-DECLARATION.md](https://ai-declaration.md/en/0.1.2).

## Notes

### Original project

The original Arrow Escape project ([sidhant947/ArrowEscape](https://github.com/sidhant947/ArrowEscape)) was developed using a local LLM via [Ollama](https://ollama.com/) paired with [OpenCode](https://opencode.ai/). No online LLM was used in the original development.

### This fork

This fork ([Lufel3846/ArrowEscape](https://github.com/Lufel3846/ArrowEscape)) was developed with AI assistance as follows:

- **LLM**: [GLM-5.3-Flash](https://openrouter.ai/z-ai/glm-5.3-flash) by Z.ai
- **Provider**: [OpenRouter](https://openrouter.ai/)
- **Agent harness**: [OpenCode](https://opencode.ai/)

The AI was used in a pair-programming role for design discussion, implementation, documentation and testing — including the stability refactors, expanded test suite, Daily Challenge, achievements/statistics, undo, watch-solution replay and the level editor. All changes were reviewed, validated and iterated on by a human maintainer (analysis, tests and manual verification), who is responsible for what is merged.

### Expectations for contributors

If you use AI to help write a contribution, **please just declare it first** (an `AI-DECLARATION.md` note or a line in the PR description is enough). PRs which can be done easily with simple logic will be rejected, as LLMs tend to add overthinking that was never necessary for the specific problem the PR is trying to solve.
