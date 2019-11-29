defmodule StateManager do
  use Agent

  def start_link() do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def get_name_records(account_id) do
    Agent.get(__MODULE__, fn state -> Map.get(state, account_id) end)
  end

  def put(key, data) do
    Agent.update(__MODULE__, fn state -> Map.put(state, key, data) end)
  end

  def update_confirmation(account_id, name) do
    IO.inspect("UPDATE CONFIRMATION")
    Agent.update(__MODULE__, fn state ->
      Map.put(state, account_id, %{state[account_id][name] | confirmed: true})
    end)
  end

  def account_exists?(account_id) do
    Agent.get(__MODULE__, fn
      state-> Map.has_key?(state, account_id)
    end)
  end

  def find_name_record_by_name(account, name) do
    Agent.get(__MODULE__, fn
      %{^account => %{^name => _} = record} -> {:ok, record}
      _ -> {:error, "Name or account is not found"}
    end)
  end

  def find_name_record_by_name_id(account_id, name_id) do
    IO.inspect("find name record by name id")
    #all_records = get_name_records(account_id)
    all_records = Agent.get(__MODULE__, fn st -> st end)[account_id]
    Enum.find(all_records, {:error, "Name : #{inspect(name_id)} is not found"}, fn
      {_k, %{name_id: ^name_id}} -> true
      _ -> false
    end)
  end
end
