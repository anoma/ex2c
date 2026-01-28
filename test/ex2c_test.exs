defmodule Ex2cTest do
  use ExUnit.Case
  require Logger
  doctest Ex2c

  @doc """
  Compilation produces the factorial function in C which can be used as follows:
  int main(int argc, char *argv[]) {
  display(call_1(Elixir2EFactorial_factorial_1, make_small(5)));
  // Expected output: 120
  display(call_1(Elixir2EFactorial_factorial_1, make_small(6)));
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
  display(call_2(Elixir2EGCD_gcd_2, make_small(5), make_small(9)));
  // Expected output: 1
  display(call_2(Elixir2EGCD_gcd_2, make_small(123), make_small(1002)));
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
  //struct term t = Elixir_Factorial___info___1(make_atom(6, "module"));
  display(call_2(Elixir2EBezout_bezout_2, make_small(5), make_small(9)));
  // Expected output: {1, 2, -1}
  display(call_2(Elixir2EBezout_bezout_2, make_small(123), make_small(1002)));
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
  display(call_1(Elixir2EMergeSort_sort_1, make_list(make_small(3), make_nil())));
  // Expected output: [3]
  display(call_1(Elixir2EMergeSort_sort_1, make_list(make_small(3), make_list(make_small(2), make_nil()))));
  // Expected output: [2, 3]
  display(call_1(Elixir2EMergeSort_sort_1, make_list(make_small(3), make_list(make_small(2), make_list(make_small(1), make_nil())))));
  // Expected output: [1, 2, 3]
  display(call_1(Elixir2EMergeSort_sort_1, make_list(make_small(3), make_list(make_small(1), make_list(make_small(2), make_nil())))));
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

  @doc """
  Compilation produces zip and unzip functions in C which can be used as follows:
  int main(int argc, char *argv[]) {
  display(call_2(Elixir2EZip_zip_2, make_list(make_small(0), make_list(make_small(2), make_list(make_small(4), make_list(make_small(6), make_nil())))), make_list(make_small(1), make_list(make_small(3), make_list(make_small(5), make_nil())))));
  // Expected output: [{0, 1}, {2, 3}, {4, 5}]
  display(call_1(Elixir2EZip_unzip_1, make_list(make_tuple(2, (struct term []) { make_small(0), make_small(9) }), make_list(make_tuple(2, (struct term []) { make_small(1), make_small(8) }), make_list(make_tuple(2, (struct term []) { make_small(2), make_small(7) }), make_nil())))));
  // Expected output: {[0, 1, 2], [9, 8, 7]}
  return 0;
  }
  """
  test "compile the zip vs unzip functions" do
    quoted =
      quote do
        defmodule Zip do
          # Base case
          def zip(a, []), do: []
          def zip([], b), do: []
          # Recursive case
          def zip([a | as], [b | bs]), do: [{a, b} | zip(as, bs)]
          # Base case
          def unzip([]), do: {[], []}
          def unzip([{a, b} | abs]) do
            {as, bs} = unzip(abs)
            {[a | as], [b | bs]}
          end
        end
      end
    output = Ex2c.compile_bytes(Code.compile_quoted(quoted)[Zip])
    Logger.info(output)
  end

  @doc """
  Compilation process produces higher order functions in C which can be used as follows:
  int main(int argc, char *argv[]) {
  display(call_1(Elixir2EMyList_sum_left_1, make_list(make_small(5), make_list(make_small(7), make_list(make_small(1), make_nil())))));
  // Expected output: 13
  display(call_1(Elixir2EMyList_sum_left_1, make_nil()));
  // Expected output: 0
  display(call_1(Elixir2EMyList_sum_right_1, make_list(make_small(5), make_list(make_small(7), make_list(make_small(1), make_nil())))));
  // Expected output: 13
  display(call_1(Elixir2EMyList_sum_right_1, make_nil()));
  // Expected output: 0
  display(call_2(Elixir2EMyList_multiply_2, make_list(make_small(5), make_list(make_small(7), make_list(make_small(1), make_nil()))), make_small(5)));
  // Expected output: [25, 35, 5]
  display(call_1(Elixir2EMyList_evens_1, make_list(make_small(5), make_list(make_small(6), make_list(make_small(7), make_list(make_small(1), make_nil()))))));
  // Expected output: [6]
  return 0;
  }
  """
  test "compile some higher order functions" do
    quoted =
      quote do
        defmodule MyList do
          # Map each element of a list
          def map([], f), do: []
          def map([x | xs], f), do: [f.(x) | map(xs, f)]
          # Fold left over elements of a list
          def fold_left([], acc, f), do: acc
          def fold_left([x | xs], acc, f), do: fold_left(xs, f.(acc, x), f)
          # Fold right over elements of a list
          def fold_right([], acc, f), do: acc
          def fold_right([x | xs], acc, f), do: f.(x, fold_right(xs, acc, f))
          # Filter elements of a list
          def filter([], pred), do: []
          def filter([x | xs], pred) do
            xs = filter(xs, pred)
            if pred.(x) do [x | xs] else xs end
          end
          # Use the higher order functions
          def multiply(x, y), do: map(x, fn x -> y*x end)
          def sum_left(x), do: fold_left(x, 0, &(&1 + &2))
          def sum_right(x), do: fold_right(x, 0, fn x, y -> x+y end)
          def evens(x), do: filter(x, fn x -> Kernel.rem(x, 2) == 0 end)
        end
      end
    output = Ex2c.compile_bytes(Code.compile_quoted(quoted)[MyList])
    Logger.info(output)
  end
end
