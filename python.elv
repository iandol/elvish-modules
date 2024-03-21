# Python Virtual Environment Utilites for Elvish (modified)
#
# Copyright © 2018
#   Ian Woloschin - ian@woloschin.com
#
# License: github.com/iwoloschin/elvish-packages/LICENSE
#
# Activation & deactivation methods for working with Python virtual
# environments in Elvish.  Will not allow invalid Virtual
# Environments to be activated.

use ./cmds

var venv-directory = $E:HOME/.venv

fn activate {|name|
	if (str:has-suffix $venv-directory "/") { set venv-directory = $venv-directory[0..-1] }
	var venvs = [(e:ls $venv-directory)]

	var error = ?(var confirmed-name = (
		each {|venv|
			if (eq $name $venv) { put $name }
		} $venvs)
	)

	if (eq $name $confirmed-name) {
		set-env VIRTUAL_ENV $venv-directory/$name
		set-env _OLD_VIRTUAL_PATH $E:PATH
		cmds:prepend-to-path $E:VIRTUAL_ENV/bin

		if (cmds:not-empty $E:PYTHONHOME) {
			set-env _OLD_VIRTUAL_PYTHONHOME $E:PYTHONHOME
			unset-env PYTHONHOME
		}
	} else {
		echo 'Virtual Environment «'$name'» not found.'
	}
}

set edit:completion:arg-completer[python:activate] = {|@args| e:ls $venv-directory }

fn deactivate {
	if (cmds:not-empty $E:_OLD_VIRTUAL_PATH) {
		set-env PATH $E:_OLD_VIRTUAL_PATH
		unset-env _OLD_VIRTUAL_PATH
	}

	if (cmds:not-empty $E:_OLD_VIRTUAL_PYTHONHOME) {
		set-env PYTHONHOME $E:_OLD_VIRTUAL_PYTHONHOME
		unset-env _OLD_VIRTUAL_PYTHONHOME
	}

	if (cmds:not-empty $E:VIRTUAL_ENV) {
		unset-env VIRTUAL_ENV
	}
}

fn list-venvs {
	all [(e:ls $venv-directory)]
}
