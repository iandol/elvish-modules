# OpenAI API / OpenRouter / Local LLM interface This module provides an LLM
# interface to the OpenAI API. Several local apps as well as several
# websites can be used with the OpenAI API to interact with an LLM. This
# module stores each question and answer in a store, you can use different
# stores to send different message contexts to the LLM. Optional values are
# passed using named options like &model and &store. You can store an API
# key in ~/.config/elvish/.key
# API: https://platform.openai.com/docs/api-reference/chat
# ------------------------------------------------------------------------
# > ai:ask "Question" &model="hermes" &store="main" &max=2048 &temperature=0.8
#
# model = a map key to $ai:models, default=hermes | store = name of store file
# (keeps the list of questions) in ~/.config/elvish/store max = max tokens,
# default 2048 temperature = 0.0 - 2.0, default 0.8
# -------------------------------------------------------------------------
# > ai:show-messages &store="main" — shows messages in that store
# -------------------------------------------------------------------------
#
# Copyright © 2024 Ian Max Andolina - https://github.com/iandol 
# Version:   1.01
# This file is licensed under the terms of the MIT license.

use os
use str
use md
use ./cmds

# Variables can be changed at load time
var system_prompt = "You are a helpful technical assistant that replies in english and explains your answers in detail"
var api_base = "http://localhost:4891"
var api_key = "NO_API_KEY"
if (os:is-regular $E:HOME"/.config/elvish/.key") { set api_key = (e:cat $E:HOME"/.config/elvish/.key") }
var models = [
	&hermes="Hermes-2-Pro-Mistral-7B.Q4_0.gguf"
	&hermes2="Nous-Hermes-2-Mistral-7B-DPO.Q4_0.gguf" 
	&openorca="mistral-7b-openorca.gguf2.Q4_0.gguf" 
	&instruct="mistral-instruct-7b-2.43bpw.gguf" 
	&instruct01="mistral-7b-instruct-v0.1.Q4_0.gguf" 
	&phi="phi-2.Q4_K_S.gguf" 
	&gemma="gemma-2b-it-q8_0.gguf"
	&openaigpt3="gpt-3.5-turbo"
	&ormistral="mistralai/mistral-7b-instruct:free"
]
var msg-folder = $E:HOME"/.config/elvish/store/"

fn info {
	echo (styled "Ask AI Parameters" bold italic white)
	echo (styled "API endpoint: " bold blue)(styled $api_base italic yellow)
	echo (styled "API key: " bold blue)(styled $api_key italic yellow)
	echo (styled "Available models: " bold blue)
	each {|m| echo (styled "  Key: " bold blue)(styled $m italic yellow)(styled " Model: " bold blue)(styled $models[$m] italic yellow) } [(keys $models)]
	echo (styled "System prompt: " bold blue)(styled $system_prompt italic yellow)
	echo (styled "Message stores: " bold italic white)
	put (e:ls $msg-folder)
}

# Get JSON messages from local store
fn get-messages {|&store=main|
	var p = $msg-folder$store".json"
	var messages
	var syspromt = [&role=system &content=$system_prompt]
	if (cmds:is-file $p) { 
		set messages = (cmds:deserialise $p) 
	} else { set messages = [$syspromt] }
	put $messages
}

# Put JSON messages to local store
fn put-messages {|messages response &store=main|
	os:mkdir-all $msg-folder
	var p = $msg-folder$store".json"
	var r = [&role=assistant &content=$response]
	var out = (cmds:append $r $messages)
	cmds:serialise $p $out
}

# Clear messages
fn clear-messages {|&store=main|
	var p = $msg-folder$store".json"
	echo "Clearing messages from: "$p
	os:remove-all $p
}

fn show-messages {|&store=main|
	var p = $msg-folder$store".json"
	if (cmds:not-path $p) { return }
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
fn ask { |q &model="hermes" &store=main &max=2048 &temperature=0.8|
	if (has-key $models $model) { set model = $models[$model] }
	if (==s $model "") { set max = -1 }
	var messages = (get-messages &store=$store)
	set q = [&role=user &content=$q]
	set messages = (cmds:append $q $messages)
	var message = (put [&model=$model &temperature=(num $temperature) &max_tokens=(num $max) 
		&n=(num 1) &stream="false" &messages=$messages] | to-json)
	echo (styled "\n=============Question (model sent: "$model")\n\n"$q[content]" … \n\n" bold yellow italic)
	var ans = (curl -s -X POST $api_base"/v1/chat/completions" -H "Content-Type: application/json" ^
		-H "Authorization: Bearer "$api_key ^
		-d $message | from-json)
	if (has-key $ans "model") { set model = [(str:split "/" $ans[model])][-1] } else { set model = "?" }
	echo (styled "\n=============Answer (model used:"$model")\n\n" bold yellow italic)
	var txt = (cmds:protect-brackets $ans[choices][0][message][content])
	md:show $txt
	if (cmds:not-empty $txt) {
		put-messages $messages $txt &store=$store
	}
}