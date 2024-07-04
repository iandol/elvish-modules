# elvish-modules

[`Elvish`](https://elv.sh) is a wonderful alternative shell, much simpler, more lightweight and a less-cruft™ experience compared to POSIX shells like `bash` or `zsh`. It supports the ability to organise your code using modules and with namespaces. Elvish has a package manager, [`epm`](https://elv.sh/ref/epm.html) which allows you to use a github repo to call up your modules as needed.

Installing: add this to your `rc.elv` file:
```elvish
epm:install &silent-if-installed github.com/iandol/elvish-modules 
use github.com/iandol/elvish-modules/cmds # my utility module
use github.com/iandol/elvish-modules/ai # my ai module
use github.com/iandol/elvish-modules/python # for python venv support
use github.com/iandol/elvish-modules/mamba # for conda/mamba support
```

...then to use:

```elvish
cmds:if-external brew { echo "Brew is installed" } { echo "Brew not installed" }
cmds:do-if-path .config { echo "Config dir exists" }
ai:ask "What is the Capital of Ghana?"
mamaba:activate myenv
```

* **`cmds.elv`** — utility functions to perform helpful shell actions like add/remove (`append-to-path`, `prepend-to-path`, `remove-from-path`) or filter (`filter`, `filter-out`, `filter-re`, `filter-re-out`) lists like the path list; checking if executables are present (`if-external`) and others.

* **`ai.elv`** — Use an OpenAI-compatible API to ask an LLM a question: `ai:ask`. You can define the system prompt: `$ai:system_prompt`, the API base address: `$ai:api_base`, the API key: `ai:api_key` (can be stored at `~/.config/elvish/.key`). Different model names can be stored in the map `$ai:models`. For example: `ai:ask "What is the Capital of ghana?" &model=hermes` — you can use local LLM apps LM-Studio and GPT4All, but it should work with any compatible local/cloud API provider. You can even use different chat history stores: `ai:ask "What is the Capital of ghana?" &store=geography` then later read the chat history using `ai:get-messages &store=geography`.

* **`mamba.elv`** — support for activating and deactivationg virtual environments for conda / mamba / micromamba package managers (note: only tested with micromamba).

* **`python.elv`** — a slight modification of [iwoloschin's](https://github.com/iwoloschin/elvish-packages) python module to support official `venv` virtual environments. 

