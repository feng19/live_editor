defmodule LiveEditor.MetaTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias LiveEditor.Meta

  test "insert_at" do
    id1 = "ld-1"
    id2 = "ld-2"
    id3 = "ld-3"
    component = %{children: []}
    component2 = %{children: [], parent_id: "ld-1"}
    component1_2 = %{children: [{id2, component2}]}
    # 3 level nest
    component3 = %{children: [], parent_id: "ld-2"}
    component2_3 = %{children: [{id3, component3}], parent_id: "ld-1"}
    component1_3 = %{children: [{id2, component2_3}]}

    list = [
      {[], :root, 0, id1, component, [{id1, component}]},
      {[{id1, component}], id1, 0, id2, component, [{id1, component1_2}]},
      {[{id1, component1_2}], id2, 0, id3, component, [{id1, component1_3}]}
    ]

    for {meta_list, parent_id, index, id, component, expect_list} <- list do
      assert expect_list == Meta.insert_at(meta_list, parent_id, index, id, component)
    end
  end
end
