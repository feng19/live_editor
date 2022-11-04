defmodule LiveEditorWeb.Code do
  use LiveEditorWeb, :html

  embed_templates "code/*"

  attr :id, :string, required: true
  attr :code, :string, required: true
  attr :rest, :global

  def heex(assigns)

  attr :id, :string, required: true
  attr :code, :string, required: true
  attr :rest, :global

  def elixir(assigns)
end
