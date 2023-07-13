# MAMBA/CONDA Environment Utilites for Elvish
#
## Copyright © 2023
#   Ian Max Andolina - https://github.com/iandol
#   Version: 1.02
#   This file is licensed under the terms of the MIT license.
#
# Activation & deactivation methods for working with Mamba virtual
# environments in Elvish (tested with micromamba, but as that is supposed to
# be drop-in replacement for conda, it should work with conda and mamba).
#
# Note: this script not only sets the path but tries to do a simple parse of
# the zsh script that is returned from  `conda shel activate -s zsh [name]`
# — for standard environment variables this is fine. However, conda can also
# run external scripts, and to solve that all we can do is to capture the
# env before and after each script runs to work out what may be changing.
#
# > mamba:root — variable to store the mamba/conda root folder mamba:list —
# > lists all environments in the envs folder of the root folder
# > mamba:activate — activates an environment (tab autocomplete should work
# > here) mamba:deactivate — deactivates an environment  
#
# Example:
# ```
# ~> use mamba
# ~> set mamba:root = ~/micromamba
# ~> mamba:list
# Mamba ENVS in /Users/jdoe/micromamba/envs: 
# ▶ octave
# ▶ pupil
# ▶ test
# ~> mamba:activate pupil
# ~> mamba:deactivate
# ```
#
use str
use re
use path
use ./cmds # my utility module

var root = $E:HOME/micromamba # can be reassigned after module load

# =========================== spawn zsh and find differences in env after
# =========================== running script, then set-env those
# =========================== zsh-processed variables
fn set-zsh-envs { |script|
	var x = [(eval 'zsh -c "fe=$(env|sort);. '$script';ne=$(env|sort);echo $fe;echo ''=+=+='';echo $ne"')]
	var n = (cmds:list-find $x '=+=+=')
	var a = $x[0..$n]
	var b = $x[(+ $n 1)..-1]
	var zenvs = [(cmds:list-changed $a $b)]
	for e $zenvs {
		var p = [(str:split '=' $e)]
		if (cmds:not-empty $p) { set-env $p[0] $p[1]; echo "Set: "$p[0]"="$p[1] }
	}
}

# =========================== get conda/mamba envs
fn get-venvs { 
	try { each {|p| path:base $p } [$root/envs/*] } catch { put [] } 
}

# =========================== process zsh script (what mamba returns) for export or source
fn process-script {|@in|
	each {|line|
		set @line = (str:split " " $line)
		if (eq $line[0] "export") { # export line
			var @parts = (str:split "=" $line[1])
			if (cmds:not-match $parts[0] "^PATH") {
				var p1 = (str:trim $parts[0] "'\"" )
				var p2 = (str:trim $parts[1] "'\"")
				try { set-env $p1 $p2 } catch { echo "Cannot set-env" }
			}
		} elif (or (eq $line[0] ".") (eq $line[0] "source") ) { # source line to a file
			var p = (str:trim $line[1] '"')
			if (cmds:is-file $p) {
				try {
					echo "Running zsh script: "$p
					set-zsh-envs $p
				} catch e {
					echo "Cannot source "$p
					pprint $e[reason]
				}
			} else {
				echo "File not found: "$p
			}
		}
	} $@in
}

# =========================== list environments
fn list {
	echo "Mamba ENVS in "$root"/envs: "
	get-venvs
}

# =========================== deactivate function
fn deactivate {
	var in = []
	try { var in = [(micromamba shell deactivate -s zsh)] } catch { }
	if (cmds:not-empty $in) { process-script $in }
	each {|in| unset-env $in } [_THIS_ENV VIRTUAL_ENV MAMBA_ENV CONDA_DEFAULT_ENV CONDA_PREFIX CONDA_PROMPT_MODIFIER CONDA_SHLVL]
	var frag = (re:find '/[^/]+$' $root)
	if (cmds:not-empty $frag[text]) {
		echo (styled "• Removing paths with « "$frag[text]" »" italic magenta)
		cmds:remove-from-path $frag[text]
	} else {
		echo (styled "• Restoring old path" italic magenta)
		set-env PATH $E:_OLD_PATH
	}
	unset-env _OLD_PATH
	if (cmds:not-empty $E:_OLD_PYTHONHOME) {
		set-env PYTHONHOME $E:_OLD_PYTHONHOME
		unset-env _OLD_PYTHONHOME
	}
	echo (styled "Mamba Deactivated!" bold italic magenta)
}

# =========================== activate function
fn activate {|name|
	if (cmds:is-member [(get-venvs)] $name) {
		deactivate # lets deactivate first
		set-env '_OLD_PATH' $E:PATH
		var in = []
		try { set in = [(micromamba shell activate -s zsh $name)] } catch { }
		if (cmds:not-empty $in) { process-script $in }
		set-env CONDA_PREFIX $root/envs/$name
		set-env CONDA_DEFAULT_ENV $name
		cmds:prepend-to-path $root/condabin
		cmds:prepend-to-path $E:CONDA_PREFIX/bin
		if (cmds:not-empty $E:PYTHONHOME) {
			set-env _OLD_PYTHONHOME $E:PYTHONHOME
			unset-env PYTHONHOME
		}
		echo (styled "Mamba Environment « "$name" » Activated!" bold italic magenta)
	} else { echo "Environment "$name" not found." }
}
set edit:completion:arg-completer[mamba:activate] = {|@args| get-venvs }

