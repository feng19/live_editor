defmodule LiveEditor.UI.Base do
  @moduledoc false
  import Phoenix.Component

  def components(_endpoint) do
    module = LiveEditorWeb.CoreComponents

    module.__components__()
    |> Stream.filter(&match?({_, %{kind: :def}}, &1))
    |> Enum.map(fn {name, component} ->
      Map.merge(component, %{
        name: to_string(name),
        module: module,
        fun_name: name,
        assigns: get_default_assigns(name),
        preview: Phoenix.HTML.raw("<button>#{name}</button>")
      })
    end)
  end

  defp get_default_assigns(:modal) do
    assigns = []
    [inner_block: %{inner_block: fn _, _ -> ~H"Are you sure?" end}]
  end

  defp get_default_assigns(:simple_form) do
    assigns = []

    [
      inner_block: %{
        inner_block: fn _, _ ->
          ~H"""
          <input type="text" , name="username" label="Username" />
          """
        end
      }
    ]
  end

  defp get_default_assigns(:button) do
    assigns = []
    [inner_block: %{inner_block: fn _, _ -> ~H"Send!" end}]
  end

  defp get_default_assigns(:error) do
    [message: "error message"]
  end

  defp get_default_assigns(name) do
    []
  end
end
