defmodule Ex2cTest do
  use ExUnit.Case
  require Logger
  doctest Ex2c

  @doc """
  Compilation produces the factorial function in C which can be used as follows:
  int main(int argc, char *argv[]) {
  display(Elixir_Factorial_factorial_1(make_small(5)));
  // Expected output: 120
  display(Elixir_Factorial_factorial_1(make_small(6)));
  // Expected output: 720
  return 0;
  }
  """
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

  @doc """
  Compilation produces the gcd function in C which can be used as follows:
  int main(int argc, char *argv[]) {
  display(Elixir_GCD_gcd_2(make_small(5), make_small(9)));
  // Expected output: 1
  display(Elixir_GCD_gcd_2(make_small(123), make_small(1002)));
  // Expected output: 3
  return 0;
  }
  """
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

  @doc """
  Compilation produces the bezout function in C which can be used as follows:
  int main(int argc, char *argv[]) {
  display(Elixir_Bezout_bezout_2(make_small(5), make_small(9)));
  // Expected output: {1, 2, -1}
  display(Elixir_Bezout_bezout_2(make_small(123), make_small(1002)));
  // Expected output: {3, -57, 7}
  return 0;
  }
  """
  test "compile the bezout function" do
    quoted =
      quote do
        defmodule Bezout do
          # Base case
          def bezout(0, b), do: {b, 0, 1}
          # Recursive case
          def bezout(a, b) do
            {e, f, g} = bezout(Kernel.rem(b, a), a)
            {e, g - (f * Kernel.div(b, a)), f}
          end
        end
      end
    output = Ex2c.compile_bytes(Code.compile_quoted(quoted)[Bezout])
    Logger.info(output)
  end

  @doc """
  Compilation produces a merge sort function in C which can be used as follows:
  int main(int argc, char *argv[]) {
  display(Elixir_MergeSort_sort_1(make_list(make_small(3), make_nil())));
  // Expected output: [3]
  display(Elixir_MergeSort_sort_1(make_list(make_small(3), make_list(make_small(2), make_nil()))));
  // Expected output: [2, 3]
  display(Elixir_MergeSort_sort_1(make_list(make_small(3), make_list(make_small(2), make_list(make_small(1), make_nil())))));
  // Expected output: [1, 2, 3]
  display(Elixir_MergeSort_sort_1(make_list(make_small(3), make_list(make_small(1), make_list(make_small(2), make_nil())))));
  // Expected output: [1, 2, 3]
  return 0;
  }
  """
  test "compile the merge-sort function" do
    quoted =
      quote do
        defmodule MergeSort do
          # Extract slice from list
          def slice(a, l, l), do: []
          def slice([a | as], 0, u), do: [a | slice(as, 0, u-1)]
          def slice([a | as], l, u), do: slice(as, l-1, u-1)
          # Merge two ordered sequences
          def merge(a, []), do: a
          def merge([], b), do: b
          def merge([a | as], bs = [b | _]) when a <= b, do: [a | merge(as, bs)]
          def merge(as = [a | _], [b | bs]) when a > b, do: [b | merge(as, bs)]
          # Base case 1
          def sort([]), do: []
          # Base case 2
          def sort([x]), do: [x]
          # Recursive case
          def sort(a) do
            len = Kernel.length(a)
            half = Kernel.div(len, 2)
            merge(sort(slice(a, 0, half)), sort(slice(a, half, len)))
          end
        end
      end
    output = Ex2c.compile_bytes(Code.compile_quoted(quoted)[MergeSort])
    Logger.info(output)
  end
end
