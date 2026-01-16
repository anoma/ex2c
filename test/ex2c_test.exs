defmodule Ex2cTest do
  use ExUnit.Case
  doctest Ex2c

  test "greets the world" do
    assert Ex2c.hello() == :world
  end
end
