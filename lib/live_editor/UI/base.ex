defmodule LiveEditor.UI.Base do
  @moduledoc false
  alias LiveEditor.UI.Helper

  def components do
    module = LiveEditorWeb.CoreComponents

    module.__components__()
    |> Stream.filter(&match?({_, %{kind: :def}}, &1))
    |> Stream.map(fn {name, c} -> {name, Map.delete(c, :kind)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {name, component} ->
      Map.merge(component, %{
        name: to_string(name),
        module: module,
        fun_name: name,
        attrs: Helper.trans_attrs(component.attrs),
        slots: Helper.trans_slots(component.slots),
        menu_button: Phoenix.HTML.raw("<button>#{name}</button>"),
        example_preview: example_preview(name)
      })
    end)
  end

  defp example_preview(:modal) do
    %{
      attrs: [id: "modal", show: true],
      slots: [inner_block: "Are you sure?"]
    }
  end

  defp example_preview(:flash) do
    %{
      attrs: [kind: :info],
      slots: [inner_block: "Welcome Back!"]
    }
  end

  defp example_preview(:button) do
    %{
      slots: [inner_block: "Send!"]
    }
  end

  defp example_preview(:input) do
    %{
      attrs: [id: "ld-input", name: "username", label: "Username", value: "Kevin", errors: []]
    }
  end

  defp example_preview(:label) do
    %{
      slots: [inner_block: ~s(<input name="username" value="Kevin" />)]
    }
  end

  defp example_preview(:error) do
    %{
      attrs: [message: "error message"]
    }
  end

  defp example_preview(:header) do
    %{
      slots: [inner_block: "<div>I'm header</div>"]
    }
  end

  defp example_preview(:table) do
    %{
      attrs: [id: "ld-table", rows: [%{id: 1, username: "kevin"}, %{id: 2, username: "bob"}]],
      slots: [
        col: """
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
        """
      ]
    }
  end

  defp example_preview(:list) do
    %{
      assigns: %{post: %{title: "1-title", views: "1-views"}},
      attrs: [],
      slots: [
        item: """
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
        """
      ]
    }
  end

  defp example_preview(:back) do
    %{
      attrs: [navigate: "/"],
      slots: [inner_block: "Back to home"]
    }
  end

  defp example_preview(_name), do: %{}
end
