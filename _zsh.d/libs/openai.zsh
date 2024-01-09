#!/bin/zsh

AUTH="Authorization: Bearer ${OPENAI_SK}"
BETA="OpenAI-Beta: assistants=v1"
OPENAI_API="https://api.openai.com/v1"
OPENAI_MODEL='gpt-3.5-turbo'
HTTP_CONTENT_TYPE_JSON="Content-Type: application/json"

function chatgpt.models() {
    curl -s $OPENAI_API/models -H "$AUTH"
}

# Newer models (2023–)	gpt-4, gpt-4 turbo, gpt-3.5-turbo	                                    https://api.openai.com/v1/chat/completions
# Updated legacy models (2023)	gpt-3.5-turbo-instruct, babbage-002, davinci-002	            https://api.openai.com/v1/completions
# Legacy models (2020–2022)	text-davinci-003, text-davinci-002, davinci, curie, babbage, ada	https://api.openai.com/v1/completions

# https://platform.openai.com/docs/api-reference/chat

function chatgpt.chat() {
    lcoal model=$OPENAI_MODEL
}

function chatgpt.assistant.create() {

}

function chatgpt.simple-chat() {
    local model=$OPENAI_MODEL
    local message="$1"
    local role=user # user | system | assistant

    local _request='
{
  "model": "${model}",
  "messages": [ {"role": "${role}", "content": "${messages}"} ]
}'
    curl -s 'https://api.openai.com/v1/chat/completions' \
         -H $AUTH \
         -H $HTTP_CONTENT_TYPE_JSON \
         -d "${(e)_request}"
}
