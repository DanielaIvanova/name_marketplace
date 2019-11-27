defmodule NameMarketplace do
  @moduledoc """
  Documentation for NameMarketplace.
  """
  alias AeppSDK.{AENS, Client, Chain, Middleware}
  alias AeppSDK.Utils.Keys
  alias StateManager

  use GenServer

  require Logger

  @selling_fee 0.10

  def start_link() do
    GenServer.start(
      __MODULE__,
      %{},
      name: __MODULE__
    )
  end

  ## Sell logic

  def choose_name do
    GenServer.call(__MODULE__, :choose_name)
  end

  def state do
    StateManager.get()
  end

  # def update_confirmed(account_id) do
  #   GenServer.cast(__MODULE__, {:update_confirmed, account_id})
  # end

  ## Buy name
  # def buy_name() do
  #   {:ok, height} = Chain.height(client)

  #   case Middleware.get_tx_by_generation_range(client, height - 20, height) do

  #   end
  # end

  def init(state) do
    StateManager.start_link()
    schedule_work()
    {:ok, state}
  end

  def handle_info(:work, _state) do
    state = StateManager.get()
    process_spend(state)
    schedule_work()

    {:noreply, state}
  end

  def handle_call(:choose_name, _from, state) do
    info =
      Enum.reduce(state, [], fn
        {_key, %{confirmed: true} = value}, acc ->
          [value | acc]

        _, acc ->
          acc
      end)

    {:reply, info, state}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  # def handle_call({:put, data, %{sender_id: sender_id}}, from, state) do
  #   new_state = Map.put(state, sender_id, data)
  #   {:reply, :ok, new_state}
  # end

  # def handle_cast({:update_confirmed, account_id}, state) do
  #   new_state = Map.put(state, account_id, %{state[account_id] | confirmed: true})
  #   {:noreply, new_state}
  # end

  def process_spend(state) do
    %Client{keypair: %{public: my_pubkey}} = client = build_client()
    {:ok, height} = Chain.height(client)

    case(Middleware.get_tx_by_generation_range(client, height - 20, height)) do
      {:ok, %{transactions: list}} ->
        process_txs(list, my_pubkey)

      _ ->
        {:error, "Could not get txs"}
    end
  end

  def build_client() do
    client_configuration = Application.get_env(:name_marketplace, :client)
    password = Application.get_env(:name_marketplace, :password)

    secret_key =
      client_configuration
      |> Keyword.get(:key_store_path)
      |> Keys.read_keystore(password)

    network_id = Keyword.get(client_configuration, :network_id)
    url = Keyword.get(client_configuration, :url)
    internal_url = Keyword.get(client_configuration, :internal_url)
    gas_price = Keyword.get(client_configuration, :gas_price)
    public_key = Keys.get_pubkey_from_secret_key(secret_key)
    key_pair = %{public: public_key, secret: secret_key}
    Client.new(key_pair, network_id, url, internal_url, gas_price: gas_price)
  end

  # def process_payload_string_to_price(string) do
  #   string
  #   |> String.split("-")
  #   |> List.first()
  #   |> String.to_integer()
  # end

  # def process_payload_string_to_name(string) do
  #   string
  #   |> String.split("-")
  #   |> List.last()
  # end

  # def process_payload(string) do
  #   case String.split(string, "-") do

  #   end
  # end

  defp schedule_work() do
    Process.send_after(self(), :work, 20_000)
  end

  defp process_txs(list, my_pubkey) do
    Enum.each(list, fn
      %{
        tx: %{
          recipient_id: ^my_pubkey,
          sender_id: sender_id,
          type: "SpendTx",
          payload: payload,
          amount: amount
        }
      } ->
        with {:ok, string} <- :aeser_api_encoder.safe_decode(:bytearray, payload),
             {:ok, name, price} <- check_name_and_price(string, amount) do
          state = StateManager.get()

          case Map.has_key?(state, sender_id) do
            false ->
              data = %{name => %{confirmed: false, price: price}}
              StateManager.put(sender_id, data)

            true ->
              old_state = Map.get(state, sender_id)
              new_data = Map.put(old_state, name, %{confirmed: false, price: price})
              StateManager.put(sender_id, new_data)
          end
        else
          {:error, _} = err -> Logger.info(fn -> "Error: #{inspect(err)}" end)
        end

      %{tx: %{account_id: account_id, recipient_id: ^my_pubkey, type: "NameTransferTx"}} = tx ->
        if Map.has_key?(state, account_id) do
          IO.inspect(tx, label: "tx")
          # StateManager.update(account_id, name)
        end

      _ ->
        :ok
    end)
  end

  defp check_name_and_price(string, amount) do
    with [price, name] <- String.split(string, "-"),
         {:ok, name} <- AENS.validate_name(name),
         {:ok, price} <- validate_price(price, amount) do
      {:ok, name, price}
    else
      {:error, reason} = error -> error
      _ -> {:error, "Not valid format"}
    end
  end

  defp validate_price(price_str, amount) do
    with {price, ""} <- Integer.parse(price_str),
         true <- price > 0,
         true <- amount >= round(price * @selling_fee) do
      {:ok, price}
    else
      {_, _} -> {:error, "Invalid price format"}
      false -> {:error, "Invalid price"}
    end
  end
end
