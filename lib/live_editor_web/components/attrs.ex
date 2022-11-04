defmodule LiveEditorWeb.Attrs do
  use LiveEditorWeb, :html

  embed_templates "attrs/*"

  attr :attr, :map, required: true

  def attr(%{attr: %{type: :atom}} = assigns), do: ~H"<%= atom(assigns) %>"
  def attr(%{attr: %{type: :string}} = assigns), do: ~H"<%= string(assigns) %>"
  def attr(%{attr: %{type: :any}} = assigns), do: ~H"<%= any(assigns) %>"
  def attr(%{attr: %{type: :global}} = assigns), do: ~H"<%= global(assigns) %>"
  def attr(%{attr: %{type: :boolean}} = assigns), do: ~H"<%= boolean(assigns) %>"
  def attr(%{attr: %{type: :integer}} = assigns), do: ~H"<%= integer(assigns) %>"
  def attr(%{attr: %{type: :float}} = assigns), do: ~H"<%= integer(assigns) %>"
  def attr(%{attr: %{type: :list}} = assigns), do: ~H"<%= a_list(assigns) %>"
  def attr(%{attr: %{type: :map}} = assigns), do: ~H"<%= map(assigns) %>"
  def attr(assigns), do: ~H""
end
