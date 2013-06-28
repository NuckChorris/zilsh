#!/usr/bin/env zsh

[[ -z "$ZILSH_VERBOSITY" ]] && ZILSH_VERBOSITY=3

_zilsh_error () {
	if (( $ZILSH_VERBOSITY >= 1 )); then
		printf "${fg_bold[red]}[Zilsh Error]${reset_color} $1\n" 1>&2
	fi
}

_zilsh_warn () {
	if (( $ZILSH_VERBOSITY >= 2 )); then
		printf "${fg_bold[yellow]}[Zilsh Warning]${reset_color} $1\n" 1>&2
	fi
}

_zilsh_debug () {
	if (( $ZILSH_VERBOSITY >= 3 )); then
		printf "${fg_bold[blue]}[Zilsh Debug]${reset_color} $1\n" 1>&2
	fi
}

_zilsh_load_bundle () {
	_zilsh_debug "Loading bundle from $1"

	# Warn for missing directories
	[[ -d "$1/configs" ]]     || _zilsh_debug "No configs directory found."
	[[ -d "$1/completions" ]] || _zilsh_debug "No completions directory found."
	[[ -d "$1/functions" ]]   || _zilsh_debug "No functions directory found."
	[[ -d "$1/themes" ]]      || _zilsh_debug "No themes directory found."

	# Warn for missing init file
	[[ -f "$1/init.zsh" ]]    || _zilsh_debug "No init.zsh file found."

	# Load all the .zsh files in configs/
	if [[ -d "$1/configs" ]]; then
		for config_file ($1/configs/*.zsh); do
			source $config_file && _zilsh_debug "Config loaded from $config_file"
		done
	fi

	# Add themes to $zsh_themes array
	if [[ -d "$1/themes" ]]; then
		for theme_file ($1/themes/*.zsh-theme); do
			zsh_themes[$theme_name]=$theme_file
		done
	fi

	# Add functions and completions to the fpath
	[[ -d "$1/completions" ]] && fpath=($1/completions $fpath) && _zilsh_debug "Completions loaded."
	[[ -d "$1/functions" ]] && fpath=($1/functions $fpath) && _zilsh_debug "Functions loaded."

	# Source the init.zsh file
	[[ -f "$1/init.zsh" ]] && source "$1/init.zsh" && _zilsh_debug "Initialized."
	_zilsh_debug "Done loading $1"
}

_zilsh_init () {
	_zilsh_debug "Starting..."

	# Throw errors for missing or nonexistent path parameter.
	if [[ -z "$1" ]]; then
		_zilsh_error "No path was passed to the zilsh_init function."
		return
	elif [[ ! -d "$1" ]]; then
		_zilsh_error "Nonexistent path passed to the zilsh_init function."
		return
	fi

	# So basically, this is a roundabout way to ensure that all directories are absolute.
	command -v greadlink >/dev/null 2>&1 && {
		# On OS X, if the GNU readlink(1) is installed, we use that instead of readlink
		local zilshdir="$(greadlink --canonicalize $1)" && _zilsh_debug "Initialized in $zilshdir"
	} || {
		# We feed the path into readlink using the --canonicalize flag to turn it absolute.
		local zilshdir="$(readlink --canonicalize $1)" && _zilsh_debug "Initialized in $zilshdir"
	} 2>/dev/null || {
		_zilsh_error "Your readlink implementation lacks the --canonicalize flag.\nIf you are on OS X, install the GNU coreutils package."
		return
	}

	typeset -A zsh_themes

	# Load the bundles
	for bundle ($zilshdir/*); do
		if [[ -d $zilshdir/$bundle ]]; then
			_zilsh_load_bundle "$zilshdir/$bundle"
		else
			_zilsh_warn "$zilshdir/$bundle is not a directory.  You really have no reason to put a file in your bundle directory."
		fi
	done

	# Load and run compinit
	autoload -U compinit
	compinit -id "/tmp/.zcompdump"

	# Load the theme
	if (( ${+ZILSH_THEME} )); then
		if [[ -f $zsh_themes[$ZILSH_THEME] ]]; then
			source $zsh_themes[$ZSH_THEME]
		fi
	fi
}
