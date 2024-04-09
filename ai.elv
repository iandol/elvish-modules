# ------------------------------------------------------------------------
# OpenAI API (includes OpenRouter.ai & Local LLM interface) This module
# provides an LLM interface to the OpenAI API. Several local apps as well as
# several websites can be used with the OpenAI API to interact with an LLM.
# This module stores each question and answer in a store, you can use
# different stores to send different message contexts to the LLM. Optional
# values are passed using named options like &model and &store. You can keep
# an API key in ~/.config/elvish/.key or set it with $ai:api_key variable.
#
# API: https://platform.openai.com/docs/api-reference/chat 
# Local LLMs: https://gpt4all.io/index.html & https://lmstudio.ai
#
# ------------------------------------------------------------------------
# > set ai:api_key = xxx
# > set ai:system_prompt = "Please provide detailed point-by-point answers."
# > ai:ask "My question here" &model="gemma" &store="main" &max=2048 &temperature=0.8
#
# optional: model = a map key in $ai:models, default=hermes | store = name of store file
# (keeps the list of questions) in ~/.config/elvish/store | max = max tokens,
# default 2048 | temperature = 0.0 - 2.0, default 0.8
#
# -------------------------------------------------------------------------
# > ai:show-messages &store="main" — shows messages in that store
#
# -------------------------------------------------------------------------
# > ai:info
#  Ask AI Parameters
#  API endpoint: http://localhost:4891
#  API key: xxx
#  Available models: 
#    Key: instruct Model: mistral-instruct-7b-2.43bpw.gguf
#    Key: ormistral Model: mistralai/mistral-7b-instruct:free
#    Key: phi Model: phi-2.Q4_K_S.gguf
#    Key: hermes Model: Nous-Hermes-2-Mistral-7B-DPO.Q4_0.gguf
#    Key: default Model: Nous-Hermes-2-Mistral-7B-DPO.Q4_0.gguf
#    Key: gemma Model: gemma-2b-it-q8_0.gguf
#  System prompt: You are a helpful technical assistant that replies in english and explains your answers in detail
#  Message stores: 
#  ▶ curl.json
#  ▶ main.json
#
# -------------------------------------------------------------------------
# Copyright © 2024 Ian Max Andolina - https://github.com/iandol 
# Version:   1.04
# This file is licensed under the terms of the MIT license.
# -------------------------------------------------------------------------

use os
use str
use md
use ./cmds

# Variables can be changed at load time
var system_prompt = "You are a helpful technical assistant that replies in english and explains your answers in detail"
var api_base = "http://localhost:4891"
var api_key = "NO_API_KEY"
if (cmds:is-file $E:HOME"/.config/elvish/store/.key") { set api_key = (e:cat $E:HOME"/.config/elvish/store/.key") }
var models = [ # models list
	&hermes="Nous-Hermes-2-Mistral-7B-DPO.Q4_0.gguf"
	&hermespro="Hermes-2-Pro-Mistral-7B.Q4_0.gguf"
	&openorca="mistral-7b-openorca.gguf2.Q4_0.gguf"
	&instruct="mistral-instruct-7b-2.43bpw.gguf"
	&instructq="mistral-7b-instruct-v0.1.Q4_0.gguf"
	&phi="phi-2.Q4_K_S.gguf"
	&gemma="gemma-1.1-2b-it-Q4_0.gguf"
	&openaigpt3="gpt-3.5-turbo"
	&ormistral="mistralai/mistral-7b-instruct:free"
	&orgemma="google/gemma-7b-it:free"
]
set models[default] = $models[gemma]
# message store folder
var msg-folder = $E:HOME"/.config/elvish/store/"
var debug = $false

# Get general info about this module
fn info {
	echo (styled "Ask AI Parameters" bold italic white)
	echo (styled "API endpoint: " bold blue)(styled $api_base italic yellow)
	echo (styled "API key: " bold blue)(styled $api_key italic yellow)
	echo (styled "Available models: " bold blue)
	each {|m| echo (styled "  Key: " bold blue)(styled $m italic yellow)(styled " Model: " bold blue)(styled $models[$m] italic yellow) } [(keys $models)]
	echo (styled "System prompt: " bold blue)(styled $system_prompt italic yellow)
	echo (styled "Message stores: " bold blue)
	put (e:ls $msg-folder)
}

# Get JSON messages from local store output as elvish map
fn get-messages {|&store=main|
	var p = $msg-folder$store".json"
	var messages
	var syspromt = [&role=system &content=$system_prompt]
	if (cmds:is-file $p) { 
		set messages = (cmds:deserialise $p) 
	} else { set messages = [$syspromt] }
	put $messages
}

# Put messages into JSON local store
fn put-messages {|messages response &store=main|
	os:mkdir-all $msg-folder
	var p = $msg-folder$store".json"
	var r = [&role=assistant &content=$response]
	var out = (cmds:append $r $messages)
	if (cmds:not-empty $out) { 
		cmds:serialise $p $out
		if $debug { echo "Saved messages to: "$p }
	}
}

# Clear messages
fn clear-messages {|&store=main|
	var p = $msg-folder$store".json"
	echo "Clearing messages from: "$p
	os:remove-all $p
}

# Show messages
fn show-messages {|&store=main|
	var p = $msg-folder$store".json"
	if (cmds:not-file $p) { echo "No messages found in: "$p; return }
	var messages = (cmds:deserialise $p)
	each {|m| 
		if (and (has-key $m "role") (==s $m[role] "user")) {
			md:show "-------- "
			md:show "# "(str:to-upper $m[role])" - "$m[content]
		} else {
			md:show $m[content] 
		}	
	} $messages
}

# Ask a question via API
fn ask { |q &model="default" &store=main &max=2048 &temperature=0.8|
	if (cmds:is-empty (str:trim $q " ")) { echo "No question provided, please use > ai:ask \"Your question\""; return }
	if (has-key $models $model) { set model = $models[$model] }
	if (==s $model "") { set max = -1 }
	set q = [&role=user &content=$q]
	var messages = (cmds:append $q (get-messages &store=$store))
	var msg = (put [&model=$model &temperature=(num $temperature) &max_tokens=(num $max) 
		&n=(num 1) &stream="false" &messages=$messages] | to-json)
	echo (styled "\n=============Question (model sent: "$model")\n\n"$q[content]" … \n\n" bold yellow italic)
	if $debug { echo (styled $msg italic blue) }
	
	# Call API using curl, convert result from JSON back to elvish map
	var ans = (curl -s -X POST $api_base"/v1/chat/completions" ^
		-H "Content-Type: application/json" ^
		-H "Authorization: Bearer "$api_key ^
		-d $msg ^
		| from-json)

	if (has-key $ans "model") { set model = [(str:split "/" $ans[model])][-1] } else { set model = "?" }
	echo (styled "\n=============Answer (model used:"$model")\n\n" bold yellow italic)
	var txt = (cmds:protect-brackets $ans[choices][0][message][content])
	if $debug { echo (styled (to-string $ans) italic blue) }
	if (cmds:not-empty $txt) {
		md:show $txt
		put-messages $messages $txt &store=$store
	}
}