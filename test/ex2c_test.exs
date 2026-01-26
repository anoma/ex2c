defmodule Ex2cTest do
  use ExUnit.Case
  require Logger
  doctest Ex2c

  test "compile the factorial function" do
    quoted =
      quote do
        defmodule Factorial do
          # Base case
          def factorial(0), do: 1
          # Recursive case
          def factorial(n), do: n * factorial(n-1)
        end
      end
    output = Ex2c.compile_bytes(Code.compile_quoted(quoted)[Factorial])
    Logger.info(output)
  end
end
