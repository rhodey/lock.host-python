import os
import sys
import json
import base64
import asyncio
from aiohttp import web
from urllib.parse import unquote
from openai import AsyncOpenAI
from solders.keypair import Keypair
from solders.pubkey import Pubkey
from solana.rpc.async_api import AsyncClient
from solders.message import Message
from solders.transaction import Transaction
from solders.system_program import transfer, TransferParams

# oai works unmodified
oai = os.environ["openai_key"]
oai = AsyncOpenAI(api_key=oai)

# persistent keys arrive soon
sol_key = "2oRZ/SaFEQRo+hyf4SrZS1W6yNVcovMwDPhGJ0nkGji1gNIodfEGlzzravS6oQbFngilk9fchPv8Cfl9Iqkkhg=="
sol_key = base64.b64decode(sol_key)
sol_key = Keypair.from_bytes(sol_key)

is_test = os.environ["PROD"] != "true"

class MySolClient:
    @classmethod
    async def create(cls):
        solana_env = os.environ["solana_environment"]
        # solana works unmodified
        self = AsyncClient(solana_env)
        await self.is_connected()
        return self

async def cors_handler(request):
    return web.Response(status=204)

@web.middleware
async def add_cors_headers(request, handler):
    response = await handler(request)
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "OPTIONS, POST, GET"
    response.headers["Access-Control-Max-Age"] = "9999999"
    return response

# called by user
async def wallet_handler(request):
    print("got wallet request")
    pubkey = request.query.get("addr", "")
    pubkey = Pubkey.from_string(pubkey) if pubkey != "" else sol_key.pubkey()
    sol_client = request.app["sol_client"]
    balance = await sol_client.get_balance(pubkey)
    balance = balance.value / 1_000_000_000
    return web.json_response({"balance": balance, "addr": str(pubkey)})

tools = [{
  "type": "function",
  "function": {
    "name": "record_if_joke_was_funny",
    "description": "Record if joke was funny",
    "parameters": {
      "type": "object",
      "properties": {
        "thoughts": { "type": "string" },
        "decision": {
          "type": "string",
          "enum": ["funny", "not"],
        },
      },
      "required": ["thoughts", "decision"],
      "additionalProperties": False,
    },
    "strict": True,
  }
}]

# called by user
async def ask_handler(request):
    print("got oai request")
    addr = request.query.get("addr", "")
    addr = Pubkey.from_string(addr)
    message = unquote(request.query.get("message", ""))
    messages = [
        { "role": "system", "content": "You are to decide if a joke is funny or not" },
        { "role": "user", "content": message }
    ]
    reply = await oai.chat.completions.create(
        model="gpt-4o-mini", temperature=1,
        tools=tools, tool_choice={ "type": "function", "function": { "name": "record_if_joke_was_funny" }},
        messages=messages
    )

    reply = reply.choices[0].message.tool_calls[0]
    reply = json.loads(reply.function.arguments)
    print(f"got oai reply {reply}")
    funny = reply["decision"] == "funny"

    if funny == False:
        print("oai = not funny")
        return web.json_response({"thoughts": reply["thoughts"]})

    print("oai = funny")
    lamports_to_send = 1_000_000
    ixns = [transfer(
        TransferParams(
            lamports=lamports_to_send,
            from_pubkey=sol_key.pubkey(),
            to_pubkey=addr
        )
    )]

    message = Message(ixns, sol_key.pubkey())
    sol_client = request.app["sol_client"]
    latest_blockhash = await sol_client.get_latest_blockhash()
    txn = Transaction([sol_key], message, latest_blockhash.value.blockhash)
    signature = await sol_client.send_transaction(txn)
    print(f"signature = {str(signature.value)}")

    latest_blockhash = await sol_client.get_latest_blockhash()
    await sol_client.confirm_transaction(tx_sig=signature.value, last_valid_block_height=latest_blockhash.value.last_valid_block_height)

    signature = str(signature.value)
    fromm = str(sol_key.pubkey())
    to = request.query.get("addr", "")
    return web.json_response({"signature": signature, "from": fromm, "to": to, "thoughts": reply["thoughts"]})

async def create_app():
    sol_client = await MySolClient.create()
    app = web.Application(middlewares=[add_cors_headers])
    app["sol_client"] = sol_client
    app.router.add_route("OPTIONS", "/api/wallet", cors_handler)
    app.router.add_route("OPTIONS", "/api/ask", cors_handler)
    app.router.add_route("GET", "/api/wallet", wallet_handler)
    app.router.add_route("GET", "/api/ask", ask_handler)
    return app

# connections arrive from runtime
# runtime handles send attest doc and encrypt session
if __name__ == "__main__":
    print("ready")
    print(f"test = {is_test}")
    print(f"addr = {sol_key.pubkey()}")
    port = int(sys.argv[1])
    web.run_app(create_app(), port=port)
