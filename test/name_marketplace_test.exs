defmodule NameMarketplaceTest do
  use ExUnit.Case
  doctest NameMarketplace

  test "greets the world" do
    assert NameMarketplace.hello() == :world
  end
end
