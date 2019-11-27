defmodule StateManager do
  use Agent

  def start_link() do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def put(key, data) do
    Agent.update(__MODULE__, fn state -> Map.put(state, key, data) end)
  end

  def update(account_id, name) do
    Agent.update(__MODULE__, fn state ->
      Map.put(state, account_id, %{state[account_id][name] | confirmed: true})
    end)
  end
end
