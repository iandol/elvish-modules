# OpenAI API / Local LLM interface Several local apps as well as several
# websites can be used with the OpenAI API to interact with an LLM. This module

use os
use ./cmds

var system_prompt = "You are a helpful technical assistant that replies in english and explains your answers in detail"
var api_base = "http://localhost:4891/v1/" #https://platform.openai.com/docs/api-reference/chat
var api_key = "NO_API_KEY"
if (os:is-regular "~/.config/elvish/.key") { set api_key = (slurp "~/.config/elvish/.key") }
var models = [
	&hermes="Nous-Hermes-2-Mistral-7B-DPO.Q4_0.gguf" 
	&openorca="mistral-7b-openorca.gguf2.Q4_0.gguf" 
	&instruct="mistral-instruct-7b-2.43bpw.gguf" 
	&instruct1="mistral-7b-instruct-v0.1.Q4_0.gguf" 
	&phi="phi-2.Q4_K_S.gguf" 
	&gemma="gemma-2b-it-q8_0.gguf"
	&gpt3="gpt-3.5-turbo"
]

# Get JSON messages from local store
fn get-messages {|&store=main|
	var p = "~/.config/elvish/store/"$store".json"
	var messages
	var syspromt = [&role=system &content=$system_prompt]
	if (cmds:is-file $p) { 
		set messages = (cmds:deserialise $p) 
	} else { set messages = [$syspromt] }
	put $messages
}

# Put JSON messages to local store
fn put-messages {|messages response &store=main|
	var p = "~/.config/elvish/store/"$store".json"
	var r = [&role=assistant &content=$response]
	var out = cmds:append $messages $r
	put $out
	cmds:serialise $p $out
}

# Clear messages
fn clear-messages {|&store=main|
	var p = "~/.config/elvish/store/"$store".json"
	echo "Clearing messages from: "$p
	os:remove-all $p
}

# Ask a question via API
fn ask { |q &model="hermes" &store=main &max=2048 &temperature=0.8|
	if (has-key $models $model) { set model = $models[$model] }
	if (==s $model "") { set max = -1 }
	var messages = get-messages &store=$store
	set q = [&role=user &content=$q]
	set messages = cmds:append $messages $q
	var message = (put [&model=$model &temperature=(num $temperature) &max_tokens=(num $max) &n=(num 1) &stream=false
		&messages=$messages] | to-json)
	put $message
	print "\n=============Question (model sent: "$model")\n\n"$q" … \n"
	var ans = (curl -s -X POST $api_base"chat/completions" -H "Content-Type: application/json" ^
		-H "Authorization: Bearer "$api_key ^
		-d $message | from-json)
	if (has-key $ans "model") { set model = [(str:split "/" $ans[model])][-1] } else { set model = "?" }
	print "\n=============Answer (model used:"$model")\n\n"
	var txt = (cmds:protect-brackets $ans[choices][0][message][content])
	md:show $txt
	if (cmds:not-empty $txt) {
		put-messages $messages $txt &store=$store
	}
}