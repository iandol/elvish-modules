# elvish-modules

[`Elvish`](https://elv.sh) is a great alternative shell, with a much simpler and a less-cruft™ experience compared to `bash` or `zsh`. It uses modules with namespaces you load to add functions.

* `cmds.elv` — utility functions to perform helpful shell actions like add/remove (`append-to-path`, `prepend-to-path`, `remove-from-path`) or filter (`filter`, `filter-out`, `filter-re`, `filter-re-out`) lists like the path list; checking if executables are present (`if-external`) and others.
* `mamba.elv` — support for conda / mamba / micromamba package manager (note: only tested with micromamba).
* `python.elv` — a slight modification of [iwoloschin's](https://github.com/iwoloschin/elvish-packages) python module to support official `venv` virtual environments. 

