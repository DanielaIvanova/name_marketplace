defmodule NameMarketplace do
  @moduledoc """
  Documentation for NameMarketplace.
  """
  alias AeppSDK.{AENS, Client, Chain, Middleware}
  alias AeternityNode.Api.NameService
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
    client = build_client()
    schedule_work(client)
    {:ok, state}
  end

  def handle_info({:work, client}, state) do
    track_sellings(client)
    schedule_work(client)

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

  def track_sellings(%Client{} = client) do

    {:ok, height} = Chain.height(client)
    IO.inspect("bang")

    case(Middleware.get_tx_by_generation_range(client, height - 20, height)) do
      {:ok, %{transactions: txs_list}} ->
        process_txs(txs_list, client, height)

      _ ->
        Logger.info("#{__MODULE__}: Could not get txs from mdw")
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
    IO.inspect Client.new(key_pair, network_id, url, internal_url, gas_price: gas_price)
  end

  defp schedule_work(client) do
    Process.send_after(self(), {:work, client}, 5_000)
  end

  defp process_txs(list, %Client{keypair: %{public: my_pubkey}} = client, height) do
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
             {:ok, name, name_id, price} <-
               check_name_and_price(string, amount, sender_id, height, client) do
          state = StateManager.get()
          case Map.has_key?(state, sender_id) do
            false ->
              data = %{name => %{confirmed: false, price: price, name_id: name}}
              StateManager.put(sender_id, data)

            true ->
              old_state = Map.get(state, sender_id)

              new_data =
                Map.put(old_state, name, %{confirmed: false, price: price, name_id: name_id})

              StateManager.put(sender_id, new_data)
          end
        else
          {:error, _} = err -> err #Logger.info(fn -> "Error: #{inspect(err)}" end)
        end

      %{
        tx: %{
          account_id: account_id,
          recipient_id: ^my_pubkey,
          type: "NameTransferTx",
          name_id: name_id
        }
      } = tx ->
        IO.inspect(tx)
        with true <- StateManager.account_exists?(account_id),
             {:ok, {name, _v}} <- StateManager.find_name_record_by_name_id(account_id, name_id) do
          StateManager.update_confirmation(account_id, name)
        else
          false ->
            :ok
            #Logger.error("Given account: #{account_id},  is not selling any names at this moment or is not registered as buyer")

          {:error, reason} = err ->
            #Logger.error(reason)
            err
        end

      _ ->
        :ok
    end)
  end

  defp check_name_and_price(string, amount, name_owner, height, %Client{} = client) do
    with [price, name] <- String.split(string, "-"),
         {:ok, name} <- AENS.validate_name(name),
         {:ok,
          [
            %{
              auction_end_height: auction_end_height,
              name: ^name,
              owner: ^name_owner,
              name_hash: name_id,
              pointers: _,
              tx_hash: _,
              expires_at: _,
              created_at_height: _
            }
          ]} <- Middleware.search_name(client, name),
         true <- height > auction_end_height,
         {:ok, price} <- validate_price(price, amount) do
      {:ok, name, name_id, price}
    else
      {:error, _} = error -> error
      false -> {:error, "Name is still in auction, therefore cannot be sold!"}
      _ = rsn -> {:error, "Invalid request, reason: #{inspect(rsn)}"}
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
