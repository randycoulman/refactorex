defmodule Refactorex.Refactor.Function.UseRegularSyntax do
  use Refactorex.Refactor,
    title: "Rewrite keyword function using regular syntax",
    kind: "refactor.rewrite",
    works_on: :line

  alias Refactorex.Refactor.Function

  def can_refactor?(%{node: node} = zipper, line) do
    cond do
      not Function.definition?(node) ->
        false

      Sourceror.get_line(node) != line ->
        false

      true ->
        %{node: {{:__block__, block_meta, _}, _}} = Function.go_to_block(zipper)

        # only keyword functions have format tag
        block_meta[:format] == :keyword
    end
  end

  def can_refactor?(_, _), do: false

  def refactor(zipper) do
    zipper
    |> Z.update(fn {function, meta, macro} ->
      {function, Keyword.merge(meta, do: [], end: []), macro}
    end)
    |> Function.go_to_block()
    |> Z.update(fn {{:__block__, meta, [:do]}, macro} ->
      {{:__block__, Keyword.drop(meta, [:format]), [:do]}, macro}
    end)
  end
end
