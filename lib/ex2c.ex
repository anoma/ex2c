defmodule Ex2c do
  @moduledoc """
  Documentation for `Ex2c`.
  """

  import Bitwise

  # Extract the components of a type name

  def specifier({:type_name, spec, _}), do: spec

  def declarator({:type_name, _, decl}), do: decl

  def beam_label_to_c(lbl), do: "L#{lbl}"

  def compile_label({:f, index}), do: beam_label_to_c(index)

  def compile_label({module, function, arity}), do: String.replace(String.replace(String.replace("#{module}_#{function}_#{arity}", "-", "_"), ".", "_"), "/", "_")

  def compile_goto({:f, 0}), do: {:expr_stmt, {:call_expr, {:symbol_expr, "abort"}, []}}

  def compile_goto(label), do: {:goto_stmt, compile_label(label)}

  def compile_literal([]), do: {:call_expr, {:symbol_expr, "make_nil"}, []}

  def compile_literal([head | tail]), do: {:call_expr, {:symbol_expr, "make_list"}, [compile_literal(head), compile_literal(tail)]}

  def compile_literal(tuple) when is_tuple(tuple), do: {:call_expr, {:symbol_expr, "make_tuple"}, [{:literal_expr, tuple_size(tuple)}, {:compound_literal_expr, "struct term []", Enum.map(Tuple.to_list(tuple), fn x -> {:expr_initializer, Ex2c.compile_literal(x)} end)}]}

  def compile_literal(nil), do: {:call_expr, {:symbol_expr, "make_atom"}, [{:literal_expr, 3}, {:literal_expr, "nil"}]}

  def compile_literal(atom) when is_atom(atom) do
    atom_string = to_string(atom)
    {:call_expr, {:symbol_expr, "make_atom"}, [{:literal_expr, String.length(atom_string)}, {:literal_expr, atom_string}]}
  end

  def compile_literal(val) when is_number(val), do: {:call_expr, {:symbol_expr, "make_small"}, [{:literal_expr, val}]}

  def compile_literal(bits) when is_bitstring(bits) do
    size = bit_size(bits)
    size_rounded_up = (size + 7) &&& ~~~7
    padded_bits = <<bits::bitstring, 0::size(size_rounded_up - size)>>
    byte_list = :binary.bin_to_list(padded_bits)
    byte_array = {:compound_literal_expr, "unsigned char []", Enum.map(byte_list, fn x -> {:expr_initializer, {:literal_expr, x}} end)}
    {:call_expr, {:symbol_expr, "make_bitstring"}, [{:literal_expr, size}, byte_array]}
  end

  def compile_operand({:integer, val}), do: {:call_expr, {:symbol_expr, "make_small"}, [{:literal_expr, val}]}

  def compile_operand(nil), do: compile_literal([])

  def compile_operand({:atom, name}), do: compile_literal(name)

  def compile_operand({:x, reg}), do: {:subscript_expr, {:symbol_expr, "xs"}, {:literal_expr, reg}}

  def compile_operand({:y, slot}), do: {:subscript_expr, {:symbol_expr, "E"}, {:literal_expr, slot + 1}}

  def compile_operand({:literal, literal}), do: compile_literal(literal)

  def compile_operand({:tr, val, _type}), do: compile_operand(val)

  def compile_code(code = {:select_val, _selector, fail, {:list, []}}), do: [{:comment_stmt, Kernel.inspect(code)}, {:goto_stmt, compile_label(fail)}]

  def compile_code(code = {:select_val, selector, fail, {:list, [value, label | rest]}}) do
    [{:comment_stmt, Kernel.inspect(code)},
     {:if_stmt, {:call_expr, {:symbol_expr, "is_eq_exact"}, [compile_operand(selector), compile_operand(value)]},
      [{:goto_stmt, compile_label(label)}], compile_code({:select_val, selector, fail, {:list, rest}})}]
  end

  def compile_code(code = {:jump, label}) do
    [{:comment_stmt, Kernel.inspect(code)}, {:goto_stmt, compile_label(label)}]
  end

  def compile_code(code = {:label, lbl}) do
    [{:comment_stmt, Kernel.inspect(code)}, {:label_stmt, beam_label_to_c(lbl)}]
  end

  def compile_code(code = {:allocate, need_stack, _live}) do
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
      [compile_goto(label)], []}]
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
    cargs =  for idx <- 0..(arity-1)//1, do: compile_operand({:x, idx})
    ccall = {:call_expr, {:symbol_expr, compile_label(label)}, cargs}
    [{:comment_stmt, Kernel.inspect(code)}, {:expr_stmt, {:binary_expr, :=, compile_operand({:x, 0}), ccall}}]
  end

  def compile_code(code = {:call_only, arity, label}) do
    cargs =  for idx <- 0..(arity-1)//1, do: compile_operand({:x, idx})
    ccall = {:call_expr, {:symbol_expr, compile_label(label)}, cargs}
    [{:comment_stmt, Kernel.inspect(code)}, {:return_stmt, {:binary_expr, :=, compile_operand({:x, 0}), ccall}}]
  end

  def compile_code(code = {:gc_bif, :-, label, _live, arguments, reg}) do
    [{:comment_stmt, Kernel.inspect(code)},
     {:if_stmt, {:not_expr, {:call_expr, {:symbol_expr, "bif_sub"}, Enum.map(arguments, &Ex2c.compile_operand/1) ++ [{:address_of_expr, compile_operand(reg)}]}},
      [compile_goto(label)], []}]
  end

  def compile_code(code = {:gc_bif, :*, label, _live, arguments, reg}) do
    [{:comment_stmt, Kernel.inspect(code)},
     {:if_stmt, {:not_expr, {:call_expr, {:symbol_expr, "bif_mul"}, Enum.map(arguments, &Ex2c.compile_operand/1) ++ [{:address_of_expr, compile_operand(reg)}]}},
      [compile_goto(label)], []}]
  end

  def compile_code(code = {:gc_bif, :+, label, _live, arguments, reg}) do
    [{:comment_stmt, Kernel.inspect(code)},
     {:if_stmt, {:not_expr, {:call_expr, {:symbol_expr, "bif_add"}, Enum.map(arguments, &Ex2c.compile_operand/1) ++ [{:address_of_expr, compile_operand(reg)}]}},
      [compile_goto(label)], []}]
  end

  def compile_code(code = {:gc_bif, :rem, label, _live, arguments, reg}) do
    [{:comment_stmt, Kernel.inspect(code)},
     {:if_stmt, {:not_expr, {:call_expr, {:symbol_expr, "bif_rem"}, Enum.map(arguments, &Ex2c.compile_operand/1) ++ [{:address_of_expr, compile_operand(reg)}]}},
      [compile_goto(label)], []}]
  end

  def compile_code(code = {:gc_bif, :div, label, _live, arguments, reg}) do
    [{:comment_stmt, Kernel.inspect(code)},
     {:if_stmt, {:not_expr, {:call_expr, {:symbol_expr, "bif_div"}, Enum.map(arguments, &Ex2c.compile_operand/1) ++ [{:address_of_expr, compile_operand(reg)}]}},
      [compile_goto(label)], []}]
  end

  def compile_code(code = {:swap, op1, op2}) do
    [{:comment_stmt, Kernel.inspect(code)},
     {:declaration_stmt, "struct term", [{{:identifier_declarator, "tmp"}, compile_operand(op1)}]},
     {:expr_stmt, {:binary_expr, :=, compile_operand(op1), compile_operand(op2)}},
     {:expr_stmt, {:binary_expr, :=, compile_operand(op2), {:symbol_expr, "tmp"}}}
    ]
  end

  def compile_code(code = {:get_tuple_element, src, idx, dst}) do
    [{:comment_stmt, Kernel.inspect(code)},
    {:expr_stmt, {:binary_expr, :=, compile_operand(dst), {:subscript_expr, {:member_access_expr, {:member_access_expr, compile_operand(src), "tuple"}, "values"}, {:literal_expr, idx}}}}]
  end

  def compile_code(code = {:put_tuple2, dst, {:list, elts}}) do
    [{:comment_stmt, Kernel.inspect(code)},
     {:expr_stmt, {:binary_expr, :=, compile_operand(dst), {:call_expr, {:symbol_expr, "make_tuple"}, [{:literal_expr, length(elts)}, {:compound_literal_expr, "struct term []", Enum.map(elts, fn x -> {:expr_initializer, compile_operand(x)} end)}]}}}]
  end

  def compile_code(code = :return) do
    [{:comment_stmt, Kernel.inspect(code)}, {:return_stmt, compile_operand({:x, 0})}]
  end

  def compile_code(code = {:make_fun3, label, _index, _unique, dst, {:list, env}}) do
    cfunc_decl =
      {:function_declarator,
       {:pointer_declarator, {:identifier_declarator, ""}}, []}
    cfunc_type = {:type_name, "struct term", cfunc_decl}
    [{:comment_stmt, Kernel.inspect(code)},
     {:expr_stmt, {:binary_expr, :=, compile_operand(dst), {:call_expr, {:symbol_expr, "make_fun"}, [
      {:cast_expr, cfunc_type, {:address_of_expr, {:symbol_expr, compile_label(label)}}},
      {:literal_expr, length(env)},
      {:compound_literal_expr, "struct term []", Enum.map(env, fn x -> {:expr_initializer, compile_operand(x)} end)}
    ]}}}]
  end

  def compile_code(code = {:call_fun, arity}) do
    xs = {:symbol_expr, "xs"}
    tmp = "tmp"
    num_free = {:member_access_expr, {:member_access_expr, {:symbol_expr, tmp}, "fun"}, "num_free"}
    counter = "i"
    counter_symbol = {:symbol_expr, "i"}
    env = {:member_access_expr, {:member_access_expr, {:symbol_expr, tmp}, "fun"}, "env"}
    ptr = {:member_access_expr, {:member_access_expr, {:symbol_expr, tmp}, "fun"}, "ptr"}
    cargs =  for idx <- 0..(arity-1)//1, do: compile_operand({:x, idx})
    cparams =  for _idx <- 0..(arity-1)//1, do: {"struct term", {:identifier_declarator, ""}}
    cfunc_decl =
      {:function_declarator,
       {:pointer_declarator, {:identifier_declarator, ""}}, cparams}
    cfunc_type = {:type_name, "struct term", cfunc_decl}
    [{:comment_stmt, Kernel.inspect(code)},
     {:declaration_stmt, "struct term", [{{:identifier_declarator, tmp}, {:subscript_expr, xs, {:literal_expr, arity}}}]},
     {:for_stmt, {:declaration_stmt, "int", [{{:identifier_declarator, counter}, {:literal_expr, 0}}]}, {:binary_expr, :<, counter_symbol, num_free}, {:postfix_expr, :++, counter_symbol},
      [{:expr_stmt, {:binary_expr, :=, {:subscript_expr, xs, {:binary_expr, :+, counter_symbol, {:literal_expr, arity}}}, {:subscript_expr, env, counter_symbol}}}]},
     {:expr_stmt, {:call_expr, {:cast_expr, cfunc_type, ptr}, cargs}}
    ]
  end

  def compile_code(code = {:trim, n, _remaining}) do
    [{:comment_stmt, Kernel.inspect(code)},
     {:expr_stmt, {:binary_expr, :=, {:subscript_expr, {:symbol_expr, "E"}, {:literal_expr, n}}, {:subscript_expr, {:symbol_expr, "E"}, {:literal_expr, 0}}}},
     {:expr_stmt, {:binary_expr, :"+=", {:symbol_expr, "E"}, {:literal_expr, n}}}
    ]
  end

  def compile_code(code) do
    [{:comment_stmt, Kernel.inspect(code)}]
  end

  def compile_function({module, {:function, name, arity, entry, code}}, acc) do
    cparams =
      for idx <- 0..(arity-1)//1,
          do:
            {"struct term",
             {:identifier_declarator, "x#{idx}"}}
    cfunc_decl =
      {:function_declarator,
       {:identifier_declarator, compile_label({module, name, arity})}, cparams}
    cfunc_type = {:type_name, "struct term", cfunc_decl}
    cfunc_prologue =
      for idx <- 0..(arity-1)//1,
          do:
            {:expr_stmt, {:binary_expr, :=, compile_operand({:x, idx}), {:symbol_expr, "x#{idx}"}}}
    cfunc_body = Enum.flat_map(code, &Ex2c.compile_code/1)
    [{:declaration_stmt, "struct term", [{cfunc_decl, nil}]} | acc] ++
    [{:comment_stmt, Kernel.inspect({:function, name, arity, entry, []})},
     {:function_stmt, specifier(cfunc_type), cfunc_decl, cfunc_prologue ++ cfunc_body}]
  end

  def compile_bytes(beam) do
    {:beam_file, module, _labeled_exports, _attributes, _compile_info, code} = :beam_disasm.file(beam)
    program_to_string(Enum.reduce(code, [], fn x, acc -> Ex2c.compile_function({module, x}, acc) end))
  end

  def compile_file(path) do
    {:ok, beam} = File.read(path)
    compile_bytes(beam)
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

  def cexpr_to_string({:postfix_expr, op, expr}),
    do: "(#{cexpr_to_string(expr)}#{op})"

  def cexpr_to_string({:prefix_expr, op, expr}),
    do: "(#{op}#{cexpr_to_string(expr)})"

  def cexpr_to_string({:not_expr, expr}),
    do: "!#{cexpr_to_string(expr)}"

  def cexpr_to_string({:subscript_expr, expr1, expr2}),
    do: "#{cexpr_to_string(expr1)}[#{cexpr_to_string(expr2)}]"

  def cexpr_to_string({:member_access_expr, expr, member}),
    do: "#{cexpr_to_string(expr)}.#{member}"

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

  def cexpr_to_string({:compound_literal_expr, type, initializer_list}) do
    "(" <> type <> ") " <> cinitialization_to_string({:initializer_list_initializer, initializer_list})
  end

  # Convert C initialization to string

  def cinitialization_to_string({:expr_initializer, expr}), do: cexpr_to_string(expr)

  def cinitialization_to_string({:initializer_list_initializer, []}), do: "{}"

  def cinitialization_to_string({:initializer_list_initializer, [init0 | rest]}) do
    str = "{" <> cinitialization_to_string(init0)

    str =
      for init <- rest, reduce: str do
        str -> str <> ", " <> cinitialization_to_string(init)
      end

    str <> "}"
  end

  def cinitialization_to_string({:member_designator_initializer, designators, initializer}) do
    str =
      for des <- designators, reduce: "" do
        str -> str <> "." <> des
      end
    str <> " = " <> cinitialization_to_string(initializer)
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

  def stmt_to_string({:if_stmt, condition, cons, [{:comment_stmt, _comment}, alt = {:if_stmt, _, _, _}]}) do
    str = "if(" <> cexpr_to_string(condition) <> ") {\n"

    str =
      for stmt <- cons, reduce: str do
        str -> str <> stmt_to_string(stmt)
      end

    str <> "} else " <> stmt_to_string(alt)
  end

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

  def stmt_to_string({:for_stmt, init_stmt, cond_expr, expr_expr, body}) do
    str = "for(" <> String.replace(stmt_to_string(init_stmt), "\n", " ") <> cexpr_to_string(cond_expr) <> "; " <> cexpr_to_string(expr_expr) <> ") {\n"
    str =
      for stmt <- body, reduce: str do
        str -> str <> stmt_to_string(stmt)
      end
    str <> "}\n"
  end

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
