defmodule LiveEditor.UI.Core do
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
      children: [%{type: :text, value: "Are you sure?"}]
    }
  end

  defp example_preview(:flash) do
    %{
      attrs: [kind: :info],
      children: [%{type: :text, value: "Welcome Back!"}]
    }
  end

  defp example_preview(:button) do
    %{
      children: [%{type: :text, value: "Send!"}]
    }
  end

  defp example_preview(:input) do
    %{
      attrs: [id: "ld-input", name: "username", label: "Username", value: "Kevin", errors: []]
    }
  end

  defp example_preview(:label) do
    %{
      children: [
        %{
          type: :text,
          value: """
          <.error>please input new value for this input</.error>
          <input name="username" value="Kevin" />
          """
        }
      ]
    }
  end

  defp example_preview(:error) do
    %{
      children: [%{type: :text, value: "error message"}]
    }
  end

  defp example_preview(:header) do
    %{
      children: [%{type: :text, value: "<div>I'm header</div>"}]
    }
  end

  defp example_preview(:table) do
    %{
      attrs: [id: "ld-table", rows: [%{id: 1, username: "kevin"}, %{id: 2, username: "bob"}]],
      children: [
        %{
          type: :text,
          slot: :item,
          value: ~S|<:col :let={user} label="id"><%= user.id %></:col>|
        },
        %{
          type: :text,
          slot: :item,
          value: ~S|<:col :let={user} label="username"><%= user.username %></:col>|
        }
      ]
    }
  end

  defp example_preview(:list) do
    %{
      assigns: %{post: %{title: "1-title", views: "1-views"}},
      attrs: [],
      children: [
        %{
          type: :text,
          slot: :item,
          value: ~S|<:item title="Title"><%= @post.title %></:item>|
        },
        %{
          type: :text,
          slot: :item,
          value: ~S|<:item title="Views"><%= @post.views %></:item>|
        }
      ]
    }
  end

  defp example_preview(:back) do
    %{
      attrs: [navigate: "/"],
      children: [%{type: :text, value: "Back to home"}]
    }
  end

  defp example_preview(_name), do: %{}
end
