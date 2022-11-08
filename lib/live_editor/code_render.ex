defmodule LiveEditor.CodeRender do
  @moduledoc false

  alias Phoenix.HTML
  alias Makeup.Formatters.HTML.HTMLFormatter
  alias Makeup.Lexers.{ElixirLexer, HEExLexer}
  alias LiveEditor.ComponentRender

  def render_heex(component) do
    %{string: string, assigns: assigns} = ComponentRender.component_code(component)

    attrs =
      Enum.map_join(assigns.attrs, " ", fn
        {k, "{" <> v} -> Enum.join([k, "{" <> v], "=")
        {k, v} when is_binary(v) -> Enum.join([k, "\"" <> v <> "\""], "=")
        {k, v} -> Enum.join([k, "\"#{v}\""], "=")
      end)

    string
    |> String.replace("{@attrs}", attrs)
    |> format_heex(true)
  end

  def format_heex(code, format? \\ false)
  def format_heex(nil, _), do: nil
  def format_heex("", _), do: nil

  def format_heex(code, format?) do
    if format? do
      Phoenix.LiveView.HTMLFormatter.format(code, [])
    else
      code
    end
    |> String.trim()
    |> HEExLexer.lex()
    |> HTMLFormatter.format_inner_as_binary([])
    |> HTML.raw()
  end

  def format_elixir(nil), do: nil
  def format_elixir(""), do: nil

  def format_elixir(code) do
    code
    |> String.trim()
    |> ElixirLexer.lex()
    |> HTMLFormatter.format_inner_as_binary([])
    |> HTML.raw()
  end
end