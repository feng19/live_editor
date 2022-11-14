defmodule LiveEditorWeb.Panels do
  use LiveEditorWeb, :html

  embed_templates "panels/*"

  defp has_active_item([]), do: false
  defp has_active_item(nil), do: false

  defp has_active_item(items) do
    Enum.any?(items, fn item ->
      item[:active] || has_active_item(item[:children])
    end)
  end
end
