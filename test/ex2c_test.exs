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

  test "compile the gcd function" do
    quoted =
      quote do
        defmodule GCD do
          # Base case
          def gcd(a, 0), do: a
          # Recursive case
          def gcd(a, b), do: gcd(b, Kernel.rem(a, b))
        end
      end
    output = Ex2c.compile_bytes(Code.compile_quoted(quoted)[GCD])
    Logger.info(output)
  end
end
