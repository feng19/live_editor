defmodule LiveEditorWeb.Panels do
  use LiveEditorWeb, :html

  embed_templates "panels/*"

  attr :label, :string, required: true
  attr :show, :boolean, default: false
  attr :class, :string, default: ""
  attr :title_class, :string, default: ""
  attr :content_class, :string, default: ""
  slot :inner_block, required: true

  def collapse(assigns)

#  defp has_active_item([]), do: false
#  defp has_active_item(nil), do: false
#
#  defp has_active_item(items) do
#    Enum.any?(items, fn item ->
#      item[:active] || has_active_item(item[:children])
#    end)
#  end
end
