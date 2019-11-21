defmodule NameMarketplace do
  @moduledoc """
  Documentation for NameMarketplace.
  """
  use GenServer

  def start_link() do
    GenServer.start(__MODULE__, %{<<123>> => %{"daniela.chain" => 123}, <<234>> => %{"artur.chain" => 345}}, name: __MODULE__)
  end

  ## Sell logic

  # def sell_name(client, name) do
  #   AeppSDK.Middleware.
  # end

  def choose_name do
    GenServer.call(__MODULE__, :choose_name)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:choose_name, _from, state) do
    info =
      Enum.reduce(state, [], fn({_key, value}, acc)->
        [value | acc]
      end)

    {:reply, info, state}
  end
end
