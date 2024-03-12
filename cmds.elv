# General Elvish utility functions
#
# Copyright © 2023
#   Ian Max Andolina - https://github.com/iandol
#   Version: 1.03
#   This file is licensed under the terms of the MIT license.

use re
use str
use path
use file
use platform
use os
echo (styled "…loading cmds module…" bold italic yellow)

################################################ Platform shortcuts
fn is-macos		{ eq $platform:os 'darwin' }
fn is-linux		{ eq $platform:os 'linux' }
fn is-win		{ eq $platform:os 'windows' }
fn is-arm64		{ or (eq (uname -m) 'arm64') (eq (uname -m) 'aarch64') }
fn is-macarm	{ and (is-macos) (is-arm64) }
fn is-macintel	{ and (is-macos) (not (is-arm64)) }

################################################ Math shortcuts
fn dec			{|n| - $n 1 }
fn inc			{|n| + $n 1 }
fn pos			{|n| > $n 0 }
fn neg			{|n| < $n 0 }

################################################ IS
# inspired by https://github.com/crinklywrappr/rivendell 
fn is-empty		{|in| == (count $in) 0 }
fn not-empty	{|in| not (== (count $in) 0) }
fn is-member	{|li s| has-value $li $s }
fn not-member	{|li s| not (has-value $li $s) }
fn is-match		{|s re| re:match $re $s }
fn not-match	{|s re| not (re:match $re $s) }
fn is-path		{|p| os:is-dir &follow-symlink=true $p }
fn not-path		{|p| not (is-path $p) }
fn is-file		{|p| os:is-regular &follow-symlink=true $p }
fn not-file		{|p| not (is-file $p) }
fn is-zero		{|n| == 0 $n }
fn is-one		{|n| == 1 $n }
fn is-even		{|n| == (% $n 2) 0 }
fn is-odd		{|n| == (% $n 2) 1 }
fn is-fn		{|x| eq (kind-of $x) fn }
fn is-map		{|x| eq (kind-of $x) map }
fn is-list		{|x| eq (kind-of $x) list }
fn is-string	{|x| eq (kind-of $x) string }
fn is-bool		{|x| eq (kind-of $x) bool }
fn is-number	{|x| eq (kind-of $x) !!float64 }
fn is-nil		{|x| eq $x $nil }

################################################ filtering functions
# filter { |i| == 0 $i} [0 1 0 1 0 1] = [0 0 0]
fn filter {|func~ @in|
	each {|item| if (func $item) { put $item }} $@in
}
# filter-out { |i| == 0 $i} [0 1 0 1 0 1] = [1 1]
fn filter-out {|func~ @in|
	each {|item| if (not (func $item)) { put $item }} $@in
}
# filter-re 'a|b' ['a' 'b' 'c' 'd' 'e'] = ['a' 'b']
fn filter-re {|re @in|
	each {|item| if (is-match $item $re) { put $item } } $@in
}
# filter-re-out 'a|b' ['a' 'b' 'c' 'd' 'e'] = ['c' 'd' 'e']
fn filter-re-out {|re @in|
	each {|item| if (not-match $item $re) { put $item } } $@in
}
fn cond {|cond v1 v2|
	if $cond {
		put $v1
	} else {
		put $v2
	}
}

################################################ pipeline functions
fn flatten { |@in| # flatten input recursively
	each {|in| if (eq (kind-of $in) list) { flatten $in } else { put $in } } $@in
}
fn check-pipe { |@li| # use when taking @args
	if (is-empty $li) { all } else { all $li }
}
fn listify { |@in| # test to take either stdin or pipein
	var list
	if (is-empty $in) { set list = [ (all) ] } else { set list = $in }
	while (and (is-one (count $list)) (is-list $list) (is-list $list[0])) { set list = $list[0] }
	put $list
}

################################################ list functions
fn prepend	{ |item li| put [(flatten $li) $item] }
fn append	{ |item li| put [$item (flatten $li)] }
fn concat	{ |l1 l2| put (flatten $l1) (flatten $l2) }
fn pluck	{ |li n| put (flatten $li[..$n]) (flatten $li[(inc $n)..]) }
fn get		{ |li n| put $li[$n] } # put A B C D | cmds:get [(all)] 1
fn first	{ |li| put $li[0] }
fn firstf	{ |li| first [(flatten $li)] }
fn second	{ |li| put $li[1] }
fn rest		{ |li| put $li[1..] }
fn end		{ |li| put $li[-1] }
fn butlast	{ |li| put $li[..(dec (count $li))] }
fn nth		{ |li n &not-found=$false|
	if (and $not-found (> $n (count $li))) {
		put $not-found
	} else {
		drop $n $li | take 1
	}
}
# list unique: [c b b a] ===> [a b c]
fn list-unique	{ |li| put (flatten $li) | to-lines | e:sort | e:uniq - | from-lines }
# list-diff: [a b c d] [c d e f] ===> [a b e f]
fn list-diff	{ |a b|
	var c = [(order [$@a $@b])]
	var j = 0; var lastindex = (dec (count $c))
	for i $c {
		if (eq $j 0) {
			if (not (eq $i $c[(inc $j)])) { put $i }
		} elif (== $j $lastindex) {
			if (not (eq $i $c[(dec $j)])) { put $i }
		} else {
			if (not (or (eq $i $c[(dec $j)]) (eq $i $c[(inc $j)]) )) { put $i }
		}
		set j = (inc $j)
	}
}
# list-intersect: [a b c d] [c d e f] ===> [c d]
fn list-intersect { |a b|
	for i $b {
		if (is-member $a $i) {
			put $i
		}
	}
}
# list-changed: [a b c d] [c d e f] ===> [e f]
fn list-changed { |a b|
	for i $b {
		if (not-member $a $i) { put $i }
	}
}
# list-find: list-find [a b c d] c ===> 2
fn list-find { |li s|
	var n = 0
	for i $li {
		if (eq $i $s) { put $n }
		set n = (+ $n 1)
	}
}
# This function takes a file path and a map, and serializes the map to JSON and saves it to the file
fn serialise {|file map|
	put $map | to-json > $file
}
# This function takes a file path, reads the JSON from the file, and deserializes it to an Elvish map
fn deserialise {|file|
	e:cat $file | from-json
}

################################################ Utils
# if-external prog { a } { b } -- if external command exists run {a}, otherwise {b}
fn if-external { |prog fcn @ofcn|
	if (has-external $prog) { 
		try { $fcn } catch e { print "\n---> Could't run: "; pprint $fcn[def]; pprint $e[reason] } 
	} elif (not-empty $ofcn) {
		set ofcn = (flatten $ofcn)
		try { $ofcn } catch e { print "\n---> Could't run: "; pprint $ofcn[def]; pprint $e[reason] } 
	}
}
# append-to-path [path] -- appends to the path
fn append-to-path { |path|
	if (is-path $path) { var @p = (filter-re-out (re:quote $path) $paths); set paths = [ $@p $path ] }
}
# prepend-to-path [path] -- prepends to the path
fn prepend-to-path { |path|
	if (is-path $path) { var @p = (filter-re-out (re:quote $path) $paths); set paths = [ $path $@p ] }
}
# remove-from-path [regex] -- removes paths with a given regex pattern
fn remove-from-path { |pathfragment|
	set paths = [(filter-re-out (re:quote $pathfragment) $paths)]
}
# do-if-path [paths] { code } -- executes code with first existing path (should be a list)
fn do-if-path { |paths func~|
	var match = $false
	if (not (is-list $paths)) { set paths = [$paths] }
	each {|p|
		if (and (is-path $p) (eq $match $false)) {
			set match = $true
			func $p
		} 
	} $paths
}
# check-paths -- checks all paths are valid, remove any that aren't
fn check-paths {
	each {|p| if (not-path $p) { remove-from-path $p; echo (styled "🥺—"$p" in $paths no longer exists…" bg-red) } } $paths
}
fn elvish-updates { 
	var sep = "----------------------------"
	curl "https://api.github.com/repos/elves/elvish/commits?per_page=8" |
	from-json |
	all (one) |
	each {|issue| echo $sep; echo (styled $issue[sha][0..12] bold): (styled (re:replace "\n" "  " $issue[commit][message]) yellow) }
}
fn repeat-each { |n f| # takses a number and a lambda
	range $n | each {|_| $f }
}
fn hexstring { |@n|
	if (is-empty $n) {
		put (repeat-each 32 { printf '%X' (randint 0 16) })
	} else {
		put (repeat-each $@n { printf '%X' (randint 0 16) })
	}
}
fn protect-brackets { |in|
	var out = (re:replace '<' '&lt;' $in)
	put (re:replace '>' '&gt;' $out)
}
# edit current command in editor, from @Kurtis-Rader
fn external-edit-command {
	var temp-file = (os:temp-file '*.elv')
	echo $edit:current-command > $temp-file
	try {
		$E:EDITOR $temp-file[name] </dev/tty >/dev/tty 2>&1
		set edit:current-command = (str:trim-right (slurp < $temp-file[name]) " \n")
	} finally {
		file:close $temp-file
		os:remove $temp-file[name]
	}
}
# eip in out file -- edit in place
# replace all occurences of in with out in file
fn eip { |in out file|
	ruby -pi -e 'gsub(/'$in'/, '''$out''')' $file
}
