import Config

config :name_marketplace,
  password: "123456",
  pubkey: "ak_2q5ESPrAyyxXyovUaRYE6C9is93ZCXmfTfJxGH9oWkDV6SEa1R",
  gc_time: 120

config :name_marketplace, :client,
  key_store_path: "my_keystore",
  network_id: "ae_uat",
  url: "https://sdk-testnet.aepps.com/v2",
  internal_url: "https://sdk-testnet.aepps.com/v2",
  gas_price: 1_000_000_000,
  auth: []
