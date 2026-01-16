defmodule Ex2c do
  @moduledoc """
  Documentation for `Ex2c`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Ex2c.hello()
      :world

  """
  def hello do
    :world
  end

  # Extract the components of a type name

  def specifier({:type_name, spec, _}), do: spec

  def declarator({:type_name, _, decl}), do: decl

  def beam_label_to_c(lbl), do: "L#{lbl}"

  def compile_label({:f, index}), do: beam_label_to_c(index)

  def compile_label({module, function, arity}), do: Atom.to_string(function)

  def compile_operand({:integer, val}), do: {:literal_expr, val}

  def compile_operand(name = nil), do: {:symbol_expr, Atom.to_string(name)}

  def compile_operand({:atom, name}), do: {:symbol_expr, Atom.to_string(name)}

  def compile_operand({:x, reg}), do: {:symbol_expr, "x#{reg}"}

  def compile_operand({:y, slot}), do: {:subscript_expr, {:symbol_expr, "E"}, {:literal_expr, slot + 1}}

  def compile_operand(_), do: {:literal_expr, 0}

  def compile_code(code = {:jump, label}) do
    [{:comment_stmt, Kernel.inspect(code)}, {:goto_stmt, compile_label(label)}]
  end

  def compile_code(code = {:label, lbl}) do
    [{:comment_stmt, Kernel.inspect(code)}, {:label_stmt, beam_label_to_c(lbl)}]
  end

  def compile_code(code = {:allocate, need_stack, live}) do
    [{:comment_stmt, Kernel.inspect(code)}, {:expr_stmt, {:binary_expr, :"-=", {:symbol_expr, "E"}, {:literal_expr, need_stack + 1}}}]
  end

  def compile_code(code = {:deallocate, deallocate}) do
    [{:comment_stmt, Kernel.inspect(code)}, {:expr_stmt, {:binary_expr, :"+=", {:symbol_expr, "E"}, {:literal_expr, deallocate + 1}}}]
  end

  def compile_code(code = {:move, src, dest}) do
    [{:comment_stmt, Kernel.inspect(code)}, {:expr_stmt, {:binary_expr, :=, compile_operand(dest), compile_operand(src)}}]
  end

  def compile_code(code = {:test, name, label, arguments}) do
    [{:comment_stmt, Kernel.inspect(code)},
     {:if_stmt, {:not_expr, {:call_expr, {:symbol_expr, Atom.to_string(name)}, Enum.map(arguments, &Ex2c.compile_operand/1)}},
      [{:goto_stmt, compile_label(label)}], []}]
  end

  def compile_code(code = {name = :get_list, source, head, tail}) do
    cargs = [
      compile_operand(source),
      {:address_of_expr, compile_operand(head)},
      {:address_of_expr, compile_operand(tail)}
    ]
    ccall = {:expr_stmt, {:call_expr, {:symbol_expr, Atom.to_string(name)}, cargs}}
    [{:comment_stmt, Kernel.inspect(code)}, ccall]
  end

  def compile_code(code = {name = :put_list, head, tail, dest}) do
    cargs = [
      compile_operand(head),
      compile_operand(tail),
      {:address_of_expr, compile_operand(dest)}
    ]
    ccall = {:expr_stmt, {:call_expr, {:symbol_expr, Atom.to_string(name)}, cargs}}
    [{:comment_stmt, Kernel.inspect(code)}, ccall]
  end

  def compile_code(code = {name = :get_tl, src, tail}) do
    cargs = [
      compile_operand(src),
      {:address_of_expr, compile_operand(tail)}
    ]
    ccall = {:expr_stmt, {:call_expr, {:symbol_expr, Atom.to_string(name)}, cargs}}
    [{:comment_stmt, Kernel.inspect(code)}, ccall]
  end

  def compile_code(code = {:call, arity, label}) do
    cargs =  for idx <- 0..(arity-1)//1, do: {:symbol_expr, "x#{idx}"}
    ccall = {:call_expr, {:symbol_expr, compile_label(label)}, cargs}
    [{:comment_stmt, Kernel.inspect(code)}, {:expr_stmt, {:binary_expr, :=, {:symbol_expr, "x0"}, ccall}}]
  end

  def compile_code(code = {:call_only, arity, label}) do
    cargs =  for idx <- 0..(arity-1)//1, do: {:symbol_expr, "x#{idx}"}
    ccall = {:call_expr, {:symbol_expr, compile_label(label)}, cargs}
    [{:comment_stmt, Kernel.inspect(code)}, {:return_stmt, {:binary_expr, :=, {:symbol_expr, "x0"}, ccall}}]
  end

  def compile_code(code = :return) do
    [{:comment_stmt, Kernel.inspect(code)}, {:return_stmt, {:symbol_expr, "x0"}}]
  end

  def compile_code(code) do
    [{:comment_stmt, Kernel.inspect(code)}]
  end

  def compile_function({:function, name, arity, entry, code}) do
    cparams =
      for idx <- 0..(arity-1)//1,
          do:
            {"uintptr_t",
             {:identifier_declarator, "x#{idx}"}}

    cfunc_decl =
      {:function_declarator,
       {:identifier_declarator, Atom.to_string(name)}, cparams}
    cfunc_type = {:type_name, "uintptr_t", cfunc_decl}
    cfunc_body = Enum.flat_map(code, &Ex2c.compile_code/1)
    {:function_stmt, specifier(cfunc_type), cfunc_decl, cfunc_body}
  end

  def compile do
    f = '/home/murisi/Documents/Heliax/Elixir.Playground.beam'
    {:ok, beam} = File.read(f)
    {:beam_file, module, labeled_exports, attributes, compile_info, code} = :beam_disasm.file(beam)
    IO.puts program_to_string(Enum.map(code, &Ex2c.compile_function/1))
  end

  # Convert C expression to string

  def cexpr_to_string({:literal_expr, value}) when is_number(value),
    do: "#{value}"

  def cexpr_to_string({:literal_expr, value}) when is_boolean(value),
    do: "#{value}"

  def cexpr_to_string({:literal_expr, value}) when is_binary(value),
    do: "\"#{value}\""

  def cexpr_to_string({:symbol_expr, value}) when is_binary(value),
    do: "#{value}"

  def cexpr_to_string({:address_of_expr, expr}),
    do: "&#{cexpr_to_string(expr)}"

  def cexpr_to_string({:indirection_expr, expr}),
    do: "*#{cexpr_to_string(expr)}"

  def cexpr_to_string({:binary_expr, op, expr1, expr2}),
    do: "(#{cexpr_to_string(expr1)} #{op} #{cexpr_to_string(expr2)})"

  def cexpr_to_string({:not_expr, expr}),
    do: "!#{cexpr_to_string(expr)}"

  def cexpr_to_string({:subscript_expr, expr1, expr2}),
    do: "#{cexpr_to_string(expr1)}[#{cexpr_to_string(expr2)}]"

  def cexpr_to_string({:cast_expr, typename, expr}) do
    "((#{specifier(typename)} #{declarator_to_string(declarator(typename))}) #{cexpr_to_string(expr)})"
  end

  def cexpr_to_string({:call_expr, reference, args}) do
    str = cexpr_to_string(reference) <> "("

    str =
      case args do
        [arg0 | rest] ->
          for arg <- rest, reduce: str <> cexpr_to_string(arg0) do
            str -> str <> ", " <> cexpr_to_string(arg)
          end

        [] ->
          str
      end

    str <> ")"
  end

  # Convert C declaration to string

  def declarator_to_string({:identifier_declarator, ident})
      when is_binary(ident),
      do: "#{ident}"

  def declarator_to_string({:pointer_declarator, decl}),
    do: "(*#{declarator_to_string(decl)})"

  def declarator_to_string({:array_declarator, decl, expr}),
    do: "(#{declarator_to_string(decl)}[#{cexpr_to_string(expr)}])"

  def declarator_to_string({:function_declarator, declarator, params}) do
    str = declarator_to_string(declarator) <> "("

    case params do
      [{spec0, decl0} | rest] ->
        str = str <> spec0 <> " " <> declarator_to_string(decl0)

        str =
          for {spec, decl} <- rest, reduce: str do
            str ->
              str <> ", " <> spec <> " " <> declarator_to_string(decl)
          end

        str <> ")"

      [] ->
        str <> ")"
    end
  end

  # Convert C initializer to string

  def initializer_to_string(nil), do: ""

  def initializer_to_string(init), do: " = " <> cexpr_to_string(init)

  # Convert C statement to string

  def stmt_to_string({:if_stmt, condition, cons, alt}) do
    str = "if(" <> cexpr_to_string(condition) <> ") {\n"

    str =
      for stmt <- cons, reduce: str do
        str -> str <> stmt_to_string(stmt)
      end

    if alt == [] do
      str <> "}\n"
    else
      str =
        for stmt <- alt, reduce: str <> "} else {\n" do
          str -> str <> stmt_to_string(stmt)
        end

      str <> "}\n"
    end
  end

  def stmt_to_string({:return_stmt, val}),
    do: "return " <> cexpr_to_string(val) <> ";\n"

  def stmt_to_string({:comment_stmt, comment}),
    do: "// " <> comment <> "\n"

  def stmt_to_string({:expr_stmt, expr}),
    do: cexpr_to_string(expr) <> ";\n"

  def stmt_to_string({:label_stmt, identifier})
      when is_binary(identifier),
      do: identifier <> ":\n"

  def stmt_to_string({:goto_stmt, identifier})
      when is_binary(identifier),
      do: "goto " <> identifier <> ";\n"

  def stmt_to_string({:declaration_stmt, spec, decls}) do
    str = spec

    case decls do
      [{decl0, init0} | rest] ->
        str =
          str <>
            " " <>
            declarator_to_string(decl0) <> initializer_to_string(init0)

        str =
          for {decl, init} <- rest, reduce: str do
            str ->
              str <>
                ", " <>
                declarator_to_string(decl) <>
                initializer_to_string(init)
          end

        str <> ";\n"

      [] ->
        ";\n"
    end
  end

  def stmt_to_string({:function_stmt, spec, decl, body}) do
    str = spec <> " " <> declarator_to_string(decl) <> " {\n"

    str =
      for stmt <- body, reduce: str do
        str -> str <> stmt_to_string(stmt)
      end

    str <> "}\n"
  end

  # Convert C program to string

  def program_to_string(program) do
    for stmt <- program, reduce: "" do
      str -> str <> stmt_to_string(stmt)
    end
  end
end
