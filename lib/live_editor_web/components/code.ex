defmodule LiveEditorWeb.Code do
  use LiveEditorWeb, :html

  embed_templates "code/*"

  attr :id, :string, required: true
  attr :lang, :string, default: "heex"
  attr :code, :string, required: true
  attr :rest, :global

  def editor(assigns)

  attr :id, :string, required: true
  attr :code, :string, required: true
  attr :rest, :global, default: %{}

  def heex(assigns)

  attr :id, :string, required: true
  attr :code, :string, required: true
  attr :rest, :global, default: %{}

  def elixir(assigns)
end
