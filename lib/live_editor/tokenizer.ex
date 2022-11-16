defmodule LiveEditor.Tokenizer do
  @moduledoc false

  # copy from Phoenix.LiveView.HTMLFormatter

  alias Phoenix.LiveView.HTMLTokenizer

  @inline_elements ~w(a abbr acronym audio b bdi bdo big br button canvas cite
  code data datalist del dfn em embed i iframe img input ins kbd label map
  mark meter noscript object output picture progress q ruby s samp select slot
  small span strong sub sup svg template textarea time u tt var video wbr)

  @eex_expr [:start_expr, :expr, :end_expr, :middle_expr]

  def tokenize(contents) do
    {:ok, eex_nodes} = EEx.tokenize(contents)
    {tokens, cont} = Enum.reduce(eex_nodes, {[], :text}, &do_tokenize/2)
    HTMLTokenizer.finalize(tokens, "nofile", cont)
  end

  defp do_tokenize({:text, text, meta}, {tokens, cont}) do
    text
    |> List.to_string()
    |> HTMLTokenizer.tokenize("nofile", 0, [line: meta.line, column: meta.column], tokens, cont)
  end

  defp do_tokenize({:comment, text, meta}, {tokens, cont}) do
    {[{:eex_comment, List.to_string(text), meta} | tokens], cont}
  end

  defp do_tokenize({type, opt, expr, %{column: column, line: line}}, {tokens, cont})
       when type in @eex_expr do
    meta = %{opt: opt, line: line, column: column}
    {[{:eex, type, expr |> List.to_string() |> String.trim(), meta} | tokens], cont}
  end

  defp do_tokenize(_node, acc) do
    acc
  end

  # Build an HTML Tree according to the tokens from the EEx and HTML tokenizers.
  #
  # This is a recursive algorithm that will build an HTML tree from a flat list of
  # tokens. For instance, given this input:
  #
  # [
  #   {:tag_open, "div", [], %{column: 1, line: 1}},
  #   {:tag_open, "h1", [], %{column: 6, line: 1}},
  #   {:text, "Hello", %{column_end: 15, line_end: 1}},
  #   {:tag_close, "h1", %{column: 15, line: 1}},
  #   {:tag_close, "div", %{column: 20, line: 1}},
  #   {:tag_open, "div", [], %{column: 1, line: 2}},
  #   {:tag_open, "h1", [], %{column: 6, line: 2}},
  #   {:text, "World", %{column_end: 15, line_end: 2}},
  #   {:tag_close, "h1", %{column: 15, line: 2}},
  #   {:tag_close, "div", %{column: 20, line: 2}}
  # ]
  #
  # The output will be:
  #
  # [
  #   {:tag_block, "div", [], [{:tag_block, "h1", [], [text: "Hello"]}]},
  #   {:tag_block, "div", [], [{:tag_block, "h1", [], [text: "World"]}]}
  # ]
  #
  # Note that a `tag_block` has been created so that its fourth argument is a list of
  # its nested content.
  #
  # ### How does this algorithm work?
  #
  # As this is a recursive algorithm, it starts with an empty buffer and an empty
  # stack. The buffer will be accumulated until it finds a `{:tag_open, ..., ...}`.
  #
  # As soon as the `tag_open` arrives, a new buffer will be started and we move
  # the previous buffer to the stack along with the `tag_open`:
  #
  #   ```
  #   defp build([{:tag_open, name, attrs, _meta} | tokens], buffer, stack) do
  #     build(tokens, [], [{name, attrs, buffer} | stack])
  #   end
  #   ```
  #
  # Then, we start to populate the buffer again until a `{:tag_close, ...} arrives:
  #
  #   ```
  #   defp build([{:tag_close, name, _meta} | tokens], buffer, [{name, attrs, upper_buffer} | stack]) do
  #     build(tokens, [{:tag_block, name, attrs, Enum.reverse(buffer)} | upper_buffer], stack)
  #   end
  #   ```
  #
  # In the snippet above, we build the `tag_block` with the accumulated buffer,
  # putting the buffer accumulated before the tag open (upper_buffer) on top.
  #
  # We apply the same logic for `eex` expressions but, instead of `tag_open` and
  # `tag_close`, eex expressions use `start_expr`, `middle_expr` and `end_expr`.
  # The only real difference is that also need to handle `middle_buffer`.
  #
  # So given this eex input:
  #
  # ```elixir
  # [
  #   {:eex, :start_expr, "if true do", %{column: 0, line: 0, opt: '='}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:eex, :expr, "\"Hello\"", %{column: 3, line: 1, opt: '='}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:eex, :middle_expr, "else", %{column: 1, line: 2, opt: []}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:eex, :expr, "\"World\"", %{column: 3, line: 3, opt: '='}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:eex, :end_expr, "end", %{column: 1, line: 4, opt: []}}
  # ]
  # ```
  #
  # The output will be:
  #
  # ```elixir
  # [
  #   {:eex_block, "if true do",
  #    [
  #      {[{:eex, "\"Hello\"", %{column: 3, line: 1, opt: '='}}], "else"},
  #      {[{:eex, "\"World\"", %{column: 3, line: 3, opt: '='}}], "end"}
  #    ]}
  # ]
  # ```
  def to_tree([], buffer, [], _source) do
    {:ok, Enum.reverse(buffer)}
  end

  def to_tree([], _buffer, [{name, _, %{line: line, column: column}, _} | _], _source) do
    message = "end of template reached without closing tag for <#{name}>"
    {:error, line, column, message}
  end

  def to_tree([{:text, text, %{context: [:comment_start]}} | tokens], buffer, stack, source) do
    to_tree(tokens, [], [{:comment, text, buffer} | stack], source)
  end

  def to_tree(
        [{:text, text, %{context: [:comment_end]}} | tokens],
        buffer,
        [{:comment, start_text, upper_buffer} | stack],
        source
      ) do
    buffer = Enum.reverse([{:text, String.trim_trailing(text), %{}} | buffer])
    text = {:text, String.trim_leading(start_text), %{}}
    to_tree(tokens, [{:html_comment, [text | buffer]} | upper_buffer], stack, source)
  end

  def to_tree(
        [{:text, text, %{context: [:comment_start, :comment_end]}} | tokens],
        buffer,
        stack,
        source
      ) do
    to_tree(tokens, [{:html_comment, [{:text, String.trim(text), %{}}]} | buffer], stack, source)
  end

  def to_tree([{:text, text, _meta} | tokens], buffer, stack, source) do
    buffer = may_set_preserve_on_block(buffer, text)

    if line_html_comment?(text) do
      to_tree(tokens, [{:comment, text} | buffer], stack, source)
    else
      meta = %{newlines: count_newlines_until_text(text, 0)}
      to_tree(tokens, [{:text, text, meta} | buffer], stack, source)
    end
  end

  def to_tree([{:eex_comment, text, _meta} | tokens], buffer, stack, source) do
    to_tree(tokens, [{:eex_comment, text} | buffer], stack, source)
  end

  def to_tree([{:tag_open, name, attrs, %{self_close: true}} | tokens], buffer, stack, source) do
    to_tree(tokens, [{:tag_self_close, name, attrs} | buffer], stack, source)
  end

  @void_tags ~w(area base br col hr img input link meta param command keygen source)
  def to_tree([{:tag_open, name, attrs, _meta} | tokens], buffer, stack, source)
      when name in @void_tags do
    to_tree(tokens, [{:tag_self_close, name, attrs} | buffer], stack, source)
  end

  def to_tree([{:tag_open, name, attrs, meta} | tokens], buffer, stack, source) do
    to_tree(tokens, [], [{name, attrs, meta, buffer} | stack], source)
  end

  def to_tree(
        [{:tag_close, name, close_meta} | tokens],
        buffer,
        [{name, attrs, open_meta, upper_buffer} | stack],
        source
      ) do
    {mode, block} =
      if (name in ["pre", "textarea"] or contains_special_attrs?(attrs)) and buffer != [] do
        content = content_from_source(source, open_meta.inner_location, close_meta.inner_location)
        {:preserve, [{:text, content, %{newlines: 0}}]}
      else
        mode =
          cond do
            preserve_format?(name, upper_buffer) -> :preserve
            name in @inline_elements -> :inline
            true -> :block
          end

        {mode,
         buffer
         |> Enum.reverse()
         |> may_set_preserve_on_text(mode, name)}
      end

    tag_block = {:tag_block, name, attrs, block, %{mode: mode}}

    to_tree(tokens, [tag_block | upper_buffer], stack, source)
  end

  # handle eex

  def to_tree([{:eex, :start_expr, expr, _meta} | tokens], buffer, stack, source) do
    to_tree(tokens, [], [{:eex_block, expr, buffer} | stack], source)
  end

  def to_tree(
        [{:eex, :middle_expr, middle_expr, _meta} | tokens],
        buffer,
        [{:eex_block, expr, upper_buffer, middle_buffer} | stack],
        source
      ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr} | middle_buffer]
    to_tree(tokens, [], [{:eex_block, expr, upper_buffer, middle_buffer} | stack], source)
  end

  def to_tree(
        [{:eex, :middle_expr, middle_expr, _meta} | tokens],
        buffer,
        [{:eex_block, expr, upper_buffer} | stack],
        source
      ) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr}]
    to_tree(tokens, [], [{:eex_block, expr, upper_buffer, middle_buffer} | stack], source)
  end

  def to_tree(
        [{:eex, :end_expr, end_expr, _meta} | tokens],
        buffer,
        [{:eex_block, expr, upper_buffer, middle_buffer} | stack],
        source
      ) do
    block = Enum.reverse([{Enum.reverse(buffer), end_expr} | middle_buffer])
    to_tree(tokens, [{:eex_block, expr, block} | upper_buffer], stack, source)
  end

  def to_tree(
        [{:eex, :end_expr, end_expr, _meta} | tokens],
        buffer,
        [{:eex_block, expr, upper_buffer} | stack],
        source
      ) do
    block = [{Enum.reverse(buffer), end_expr}]
    to_tree(tokens, [{:eex_block, expr, block} | upper_buffer], stack, source)
  end

  def to_tree([{:eex, _type, expr, meta} | tokens], buffer, stack, source) do
    to_tree(tokens, [{:eex, expr, meta} | buffer], stack, source)
  end

  # -- HELPERS

  defp count_newlines_until_text(<<char, rest::binary>>, counter) when char in '\s\t\r',
    do: count_newlines_until_text(rest, counter)

  defp count_newlines_until_text(<<?\n, rest::binary>>, counter),
    do: count_newlines_until_text(rest, counter + 1)

  defp count_newlines_until_text(_, counter),
    do: counter

  # We just want to handle as :comment when the whole line is a HTML comment.
  #
  #   <!-- Modal content -->
  #   <%= render_slot(@inner_block) %>
  #
  # Thefore the case above will stay as is. Otherwise it would put them in the
  # same line.
  defp line_html_comment?(text) do
    trimmed_text = String.trim(text)
    String.starts_with?(trimmed_text, "<!--") and String.ends_with?(trimmed_text, "-->")
  end

  # We want to preserve the format:
  #
  # * In case the head is a text that doesn't end with whitespace.
  # * In case the head is eex.
  defp preserve_format?(name, upper_buffer) do
    name in @inline_elements and head_may_not_have_whitespace?(upper_buffer)
  end

  defp head_may_not_have_whitespace?([{:text, text, _meta} | _]),
    do: String.trim_leading(text) != "" and :binary.last(text) not in '\s\t'

  defp head_may_not_have_whitespace?([{:eex, _, _} | _]), do: true
  defp head_may_not_have_whitespace?(_), do: false

  # In case the given tag is inline and the there is no white spaces in the next
  # text, we want to set mode as preserve. So this tag will not be formatted.
  defp may_set_preserve_on_block([{:tag_block, name, attrs, block, meta} | list], text)
       when name in @inline_elements do
    mode =
      if String.trim_leading(text) != "" and :binary.first(text) not in '\s\t\n\r' do
        :preserve
      else
        meta.mode
      end

    [{:tag_block, name, attrs, block, %{mode: mode}} | list]
  end

  @non_ws_preserving_elements ["button"]

  defp may_set_preserve_on_block(buffer, _text), do: buffer

  defp may_set_preserve_on_text([{:text, text, meta}], :inline, tag_name)
       when tag_name not in @non_ws_preserving_elements do
    {mode, text} =
      if meta.newlines == 0 and whitespace_around?(text) do
        text =
          text
          |> cleanup_extra_spaces_leading()
          |> cleanup_extra_spaces_trailing()

        {:preserve, text}
      else
        {:normal, text}
      end

    [{:text, text, Map.put(meta, :mode, mode)}]
  end

  defp may_set_preserve_on_text(buffer, _mode, _tag_name), do: buffer

  defp whitespace_around?(text), do: :binary.first(text) in '\s\t' or :binary.last(text) in '\s\t'

  defp cleanup_extra_spaces_leading(text) do
    if :binary.first(text) in '\s\t' do
      " " <> String.trim_leading(text)
    else
      text
    end
  end

  defp cleanup_extra_spaces_trailing(text) do
    if :binary.last(text) in '\s\t' do
      String.trim_trailing(text) <> " "
    else
      text
    end
  end

  defp contains_special_attrs?(attrs) do
    Enum.any?(attrs, fn
      {"contenteditable", {:string, "false", _meta}, _} -> false
      {"contenteditable", _v, _} -> true
      {"phx-no-format", _v, _} -> true
      _ -> false
    end)
  end

  defp content_from_source({source, newlines}, {line_start, column_start}, {line_end, column_end}) do
    lines = Enum.slice([{0, 0} | newlines], (line_start - 1)..(line_end - 1))
    [first_line | _] = lines
    [last_line | _] = Enum.reverse(lines)

    offset_start = line_byte_offset(source, first_line, column_start)
    offset_end = line_byte_offset(source, last_line, column_end)

    binary_part(source, offset_start, offset_end - offset_start)
  end

  defp line_byte_offset(source, {line_before, line_size}, column) do
    line_offset = line_before + line_size

    line_extra =
      source
      |> binary_part(line_offset, byte_size(source) - line_offset)
      |> String.slice(0, column - 1)
      |> byte_size()

    line_offset + line_extra
  end
end
