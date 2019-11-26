defmodule NameMarketplace do
  @moduledoc """
  Documentation for NameMarketplace.
  """
  alias AeppSDK.{AENS, Client, Chain, Middleware}
  alias AeppSDK.Utils.Keys

  use GenServer

  @selling_fee 0.10

  def start_link() do
    GenServer.start(
      __MODULE__,
      %{
        <<123>> => %{"daniela.chain" => 123, confirmed: true},
        <<234>> => %{"artur.chain" => 345, confirmed: true}
      },
      name: __MODULE__
    )
  end

  ## Sell logic

  def choose_name do
    GenServer.call(__MODULE__, :choose_name)
  end

  def state do
    GenServer.call(__MODULE__, :state)
  end

  def update_confirmed(account_id) do
    GenServer.cast(__MODULE__, {:update_confirmed, account_id})
  end


  ## Buy name
  # def buy_name() do
  #   {:ok, height} = Chain.height(client)

  #   case Middleware.get_tx_by_generation_range(client, height - 20, height) do

  #   end
  # end


  def init(state) do
    schedule_work()
    {:ok, state}
  end


  def handle_info(:work, state) do
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

  def handle_cast({:put, data, %{sender_id: sender_id}}, state) do
    new_state = Map.put(state, sender_id, data)
    {:noreply, new_state}
  end

  def handle_cast({:update_confirmed, account_id}, state) do
    new_state = Map.put(state, account_id, %{state[account_id] | confirmed: true})
    {:noreply, new_state}
  end

  def process_spend(state) do
    %Client{keypair: %{public: my_pubkey}} = client = build_client()
    {:ok, height} = Chain.height(client)

    with {:ok, %{transactions: list}} <- Middleware.get_tx_by_generation_range(client, height - 20, height),



    case Middleware.get_tx_by_generation_range(client, height - 20, height) do
      {:ok, %{transactions: list}} ->
        Enum.reduce(list, %{spend: [], transfer: []}, fn
          %{
            tx: %{
              recipient_id: ^my_pubkey,
              sender_id: sender_id,
              type: "SpendTx",
              payload: payload,
              amount: amount
            }
          } = tx,
          acc ->
            case :aeser_api_encoder.safe_decode(:bytearray, payload) do
              {:ok, ""} ->
                {:error, "No name and price in the payload"}

              {:ok, string} ->
                case String.split(string, "-") do
                  [price, name] -> AENS.validate_name(name)
                end
                # TODO: Add checks for correct name, price .....
                name_price = process_payload_string_to_price(string)
                name = process_payload_string_to_name(string)

                if amount >= round(name_price * @selling_fee) do
                  data = %{name => name_price, confirmed: false}

                  unless Map.has_key?(state, sender_id) do
                    GenServer.cast(__MODULE__, {:put, data, tx.tx})
                  end
                end

              _ ->
                {:error, "#############"}
            end

            Map.put(acc, :spend, [tx | Map.get(acc, :spend)])

          %{tx: %{account_id: account_id, recipient_id: ^my_pubkey, type: "NameTransferTx"}} = tx,
          acc ->


            if Map.has_key?(state, account_id) do
              update_confirmed(account_id)
            end

            Map.put(acc, :transfer, [tx | Map.get(acc, :transfer)])

          _, acc ->
            acc
        end)

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

  def process_payload_string_to_price(string) do
    string
    |> String.split("-")
    |> List.first()
    |> String.to_integer()
  end

  def process_payload_string_to_name(string) do
    string
    |> String.split("-")
    |> List.last()
  end

  # def process_payload(string) do
  #   case String.split(string, "-") do

  #   end
  # end

  defp schedule_work() do
    Process.send_after(self(), :work, 20_000)
  end

  defp asdf(list) do
    Enum.reduce(list, %{spend: [], transfer: []}, fn
      %{
        tx: %{
          recipient_id: ^my_pubkey,
          sender_id: sender_id,
          type: "SpendTx",
          payload: payload,
          amount: amount
        }
      } = tx,
      acc ->
        with {:ok, valid_string} <- check_name(payload),
        name_price = process_payload_string_to_price(valid_string),
        name = process_payload_string_to_name(valid_string),
        {:ok, ""} <- :aeser_api_encoder.safe_decode(:bytearray, payload)



        case :aeser_api_encoder.safe_decode(:bytearray, payload) do
          {:ok, ""} ->
            {:error, "No name and price in the payload"}

          {:ok, string} ->
            case String.split(string, "-") do
              [price, name] -> AENS.validate_name(name)
            end
            # TODO: Add checks for correct name, price .....
            name_price = process_payload_string_to_price(string)
            name = process_payload_string_to_name(string)

            if amount >= round(name_price * @selling_fee) do
              data = %{name => name_price, confirmed: false}

              unless Map.has_key?(state, sender_id) do
                GenServer.cast(__MODULE__, {:put, data, tx.tx})
              end
            end

          _ ->
            {:error, "#############"}
        end

        Map.put(acc, :spend, [tx | Map.get(acc, :spend)])

      %{tx: %{account_id: account_id, recipient_id: ^my_pubkey, type: "NameTransferTx"}} = tx,
      acc ->


        if Map.has_key?(state, account_id) do
          update_confirmed(account_id)
        end

        Map.put(acc, :transfer, [tx | Map.get(acc, :transfer)])

      _, acc ->
        acc
    end)
  end

  defp check_name(string) do
   with [price, name] <- String.split(string, "-"),
   {:ok, name} <- AENS.validate_name(name) do
     name
   else
    {:error, reason} = error -> error
    _ -> {:error, "Not valid format"}
   end
  end


end
