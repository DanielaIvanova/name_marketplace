defmodule WebSocket do
  use WebSockex

  def start_link() do
    WebSockex.start_link("wss://testnet.aeternal.io/websocket", __MODULE__, %{}, name: __MODULE__)
  end

  def get_info() do
    WebSockex.send_frame(__MODULE__, {:binary, "{\"payload\":\"transactions\",\"op\":\"Subscribe\"}"})
  end

  def handle_frame({type, msg}, state) do
    IO.puts "Received Message - Type: #{inspect type} -- Message: #{inspect msg}"
    {:ok, state}
  end

  def handle_cast({:send, {type, msg} = frame}, state) do
    IO.puts "Sending #{type} frame with payload: #{msg}"
    {:reply, frame, state}
  end
end
