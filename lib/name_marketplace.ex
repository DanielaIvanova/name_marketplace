defmodule NameMarketplace do
  use WebSockex

  alias AeppSDK.{AENS, Client, Chain, Middleware}
  alias AeppSDK.Utils.Keys

  require Logger

  @default_pubkey Application.get_env(
                    :name_marketplace,
                    :pubkey,
                    "ak_2q5ESPrAyyxXyovUaRYE6C9is93ZCXmfTfJxGH9oWkDV6SEa1R"
                  )
  @gc_time Application.get_env(
             :name_marketplace,
             :gc_time,
             120
           )


  @selling_fee 0.10
  @awaiting_for_confirmation :awaiting_for_transfer
  @received_name_transfer :received_name_transfer
  @infinite_expiry :never
  @spend_tx_type "SpendTx"
  @name_transfer_tx_type "NameTransferTx"

  def start_link() do
    WebSockex.start("wss://testnet.aeternal.io/websocket", __MODULE__, %{client: build_client()},
      name: __MODULE__,
      debug: [:trace]
    )
  end

  def subscribe(<<"ak_"::binary, _::binary>> = account \\ @default_pubkey) do
    request = %{target: account, payload: "Object", op: "Subscribe"}

    WebSockex.send_frame(__MODULE__, {:text, Poison.encode!(request)})
  end

  def handle_frame({:text, "connected"}, state) do
    {:ok, state}
  end

  def handle_frame({:text, msg}, %{client: client} = state) do
    {:ok, height} = Chain.height(client)

    case Poison.decode(msg, keys: :atoms) do
      {:ok, %{payload: %{hash: hash, tx: %{type: @spend_tx_type} = tx}}} ->
        process_tx(tx, hash, height, state)

      {:ok, %{payload: %{tx: %{type: @name_transfer_tx_type} = tx}}} ->
        process_tx(tx, state)

      _ ->
        {:ok, state}
    end
  end

  def handle_disconnect(disconnect_map, state) do
    super(disconnect_map, state)
  end

  defp process_tx(
         %{type: @spend_tx_type, payload: payload, amount: amount, sender_id: sender_id} = tx,
         hash,
         height,
         %{client: client} = state
       ) do
    if Map.has_key?(state, hash) do
      {:ok, garbage_collect(state)}
    else
      with {:ok, string} <- :aeser_api_encoder.safe_decode(:bytearray, payload),
           {:ok, name, name_id, price} <-
             check_name_and_price(string, amount, sender_id, height, client) do
        tx_data =
          Map.put(tx, :name_tx, %{
            name: name,
            name_id: name_id,
            price: price,
            status: @awaiting_for_confirmation
          })
          |> Map.put(:delete_at, :os.system_time(:seconds) + @gc_time)

        {:ok, garbage_collect(Map.put(state, hash, tx_data))}
      else
        {:error, _} = err ->
          Logger.error(fn -> "Error: #{inspect(err)}" end)
          {:ok, garbage_collect(state)}
      end
    end
  end

  defp process_tx(
         %{
           type: @name_transfer_tx_type,
           name_id: name_id,
           account_id: account_id
         } = tx,
         state
       ) do
    res =
      Enum.find(state, :not_found, fn
        {<<_::binary>>, v} ->
          v.name_tx.name_id === name_id && v.sender_id === account_id &&
            v.name_tx.status === @awaiting_for_confirmation

        _ ->
          false
      end)

    case res do
      {spend_tx_hash, %{name_tx: name_tx_info} = record} ->
        new_name_tx_info = Map.merge(%{name_tx_info | status: @received_name_transfer}, tx)
        updated_record = %{record | name_tx: new_name_tx_info, delete_at: @infinite_expiry}
        {:ok, garbage_collect(Map.put(state, spend_tx_hash, updated_record))}

      :not_found ->
        {:ok, garbage_collect(state)}
    end
  end

  defp build_client() do
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

  defp check_name_and_price(string, amount, name_owner, height, client) do
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
         true <- height >= auction_end_height,
         {:ok, price} <- validate_price(price, amount) do
      {:ok, name, name_id, price}
    else
      {:error, _} = error -> error
      false -> {:error, "Name is still in auction, therefore cannot be sold!"}
      _ -> {:error, "Name is not owned by #{inspect(name_owner)}, rejected!"}
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

  defp garbage_collect(state) do
    current_time = :os.system_time(:seconds)
    Logger.info("GC TIME! Current state: #{inspect(state)}")

    new_state =
      Enum.reduce(state, %{}, fn
        {:client = k, v}, acc ->
          Map.put(acc, k, v)

        {<<_::binary>> = k, %{delete_at: @infinite_expiry} = v}, acc ->
          Map.put(acc, k, v)

        {<<_::binary>> = k, %{delete_at: delete_at} = v}, acc ->
          if delete_at <= current_time do
            acc
          else
            Map.put(acc, k, v)
          end
      end)

    Logger.info("State after GC: #{inspect(new_state)}")
    new_state
  end
end
