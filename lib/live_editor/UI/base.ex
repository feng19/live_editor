defmodule LiveEditor.UI.Base do
  @moduledoc false

  @list [
    :div,
    :hr,
    :h1,
    :h2,
    :h3,
    :h4,
    :h5,
    :h6,
    :p,
    :span
  ]
  @group_list [
    :main,
    :nav,
    :header,
    :footer,
    :section,
    :article,
    :aside,
    :details,
    :dialog,
    :summary
  ]
  @only_attr_list [:br]
  @attrs [
    {"rest",
     %{
       name: :rest,
       type: :global,
       value: nil,
       opts: [],
       required: false,
       slot: nil,
       doc: nil
     }}
  ]
  @slots [
    {"inner_block",
     %{
       name: :inner_block,
       value: nil,
       attrs: [],
       opts: [],
       required: false,
       doc: nil
     }}
  ]

  def components do
    [
      %{list: @list, type: :base, attrs: @attrs, slots: @slots},
      %{list: @only_attr_list, type: :base, attrs: @attrs, slots: []},
      %{list: @group_list, type: :group, attrs: @attrs, slots: @slots}
    ]
    |> Enum.flat_map(fn %{list: list, type: type, attrs: attrs, slots: slots} ->
      list
      |> Enum.sort()
      |> Enum.map(fn name ->
        %{
          name: to_string(name),
          module: :tag,
          fun_name: name,
          type: type,
          attrs: attrs,
          slots: slots,
          menu_button: Phoenix.HTML.raw("<button>#{name}</button>"),
          example_preview: example_preview(name)
        }
      end)
    end)
  end

  defp example_preview(:div) do
    %{
      attrs: [rest: [class: "w-full h-15"]],
      slots: [inner_block: "add something here"]
    }
  end

  defp example_preview(tag) when tag in [:p, :span] do
    %{
      slots: [inner_block: "add something here"]
    }
  end

  defp example_preview(tag) when tag in @group_list do
    %{
      slots: [inner_block: "add something here"]
    }
  end

  defp example_preview(tag) when tag in [:h1, :h2, :h3, :h4, :h5, :h6] do
    %{
      slots: [inner_block: to_string(tag)]
    }
  end

  defp example_preview(_name), do: nil
end
