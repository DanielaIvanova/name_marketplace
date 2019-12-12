defmodule NameMarketplace.MixProject do
  use Mix.Project

  def project do
    [
      app: :name_marketplace,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :websockex]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:aepp_sdk_elixir, git: "https://github.com/aeternity/aepp-sdk-elixir.git", tag: "v0.5.2"},
      {:websockex, git: "https://github.com/Azolo/websockex"}
    ]
  end
end
