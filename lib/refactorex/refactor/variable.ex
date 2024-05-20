defmodule Refactorex.Refactor.Variable do
  alias Refactorex.Refactor.AST
  alias Sourceror.Zipper, as: Z

  import Sourceror.Identifier

  @not_variable ~w(binary)a

  def find_variables(node, opts \\ []) do
    reject = opts[:reject] || fn _ -> false end
    unique = if is_nil(opts[:unique]), do: true, else: opts[:unique]

    node
    |> Z.zip()
    |> Z.traverse_while([], fn
      %{node: {id, _, nil} = variable} = zipper, variables when is_identifier(variable) ->
        cond do
          Enum.member?(@not_variable, id) ->
            {:cont, zipper, variables}

          match?(%{node: {:@, _, _}}, Z.up(zipper)) ->
            {:cont, zipper, variables}

          reject.(zipper) ->
            {:cont, zipper, variables}

          true ->
            {:cont, zipper, variables ++ [variable]}
        end

      zipper, variables ->
        {:cont, zipper, variables}
    end)
    |> elem(1)
    |> then(&if unique, do: remove_duplicates(&1), else: &1)
  end

  def remove_duplicates(variables),
    do: Enum.uniq_by(variables, fn {id, _, _} -> id end)

  def member?(variables, {variable_id, _, _} = _variable),
    do: Enum.any?(variables, fn {id, _, _} -> id == variable_id end)

  def member?(_, _), do: false

  def find_constants_used(macro) do
    macro
    |> Z.zip()
    |> Z.traverse_while([], fn
      %{node: {:@, _, [{_, _, nil} = constant]}} = zipper, constants ->
        {:cont, zipper, constants ++ [constant]}

      zipper, constants ->
        {:cont, zipper, constants}
    end)
    |> elem(1)
  end

  def find_available_variables(%{node: node} = zipper) do
    line = AST.get_start_line(node)

    zipper
    # go to outer scope
    |> Z.find(:prev, fn
      {id, _, _} when id in ~w(defmodule def defp)a -> true
      _ -> false
    end)
    |> Z.node()
    |> find_variables(reject: &(AST.get_start_line(&1.node) >= line))
  end
end
