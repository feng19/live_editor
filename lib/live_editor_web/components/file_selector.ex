defmodule LiveEditorWeb.FileSelector do
  @moduledoc false
  use LiveEditorWeb, :live_component

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    type = assigns.type
    socket = socket |> assign(title: "#{type} file", input: nil) |> assign(assigns)
    socket = File.cwd!() |> cwd_changed(socket)
    {:ok, socket}
  end

  # type: new | open
  def render(assigns) do
    ~H"""
    <div>
      <.modal id={@id} show={false} on_confirm={JS.push("commit", target: @myself)}>
        <:title><%= @title %></:title>
        <div class="p-2 w-full">
          <div>cwd: <%= @cwd %></div>
          <div>
            <form phx-change="file_input_changed" phx-target={@myself}>
              <div class="input-group flex justify-center">
                <input type="text" name="input_file" value={@input} class="input input-bordered w-5/6" />
              </div>
            </form>
          </div>
          <div class="grid grid-cols-4 gap-2 p-2">
            <button
              type="button"
              class="select-none p-2 rounded-lg hover:bg-gray-100 focus:ring-1 focus:ring-gray-400"
              phx-click="back"
              phx-target={@myself}
            >
              <span>..</span>
            </button>
            <button
              :for={file <- @files}
              type="button"
              class="select-none p-2 rounded-lg hover:bg-gray-100 focus:ring-1 focus:ring-gray-400"
              phx-click="select_file"
              phx-target={@myself}
              value={file}
            >
              <span><%= file %></span>
            </button>
          </div>
        </div>
        <:confirm>Save</:confirm>
        <:cancel>Cancel</:cancel>
      </.modal>
    </div>
    """
  end

  def handle_event("back", _, socket) do
    socket = socket.assigns.cwd |> Path.join("..") |> Path.expand() |> cwd_changed(socket)
    {:noreply, socket}
  end

  def handle_event("file_input_changed", %{"input_file" => file}, socket) do
    {:noreply, assign(socket, input: file)}
  end

  def handle_event("select_file", %{"value" => file}, socket) do
    filename = socket.assigns.cwd |> Path.join(file)

    socket =
      if File.dir?(filename) do
        cwd_changed(filename, socket)
      else
        assign(socket, input: file)
      end

    {:noreply, socket}
  end

  def handle_event("commit", _, socket) do
    assigns = socket.assigns
    file = maybe_add_ext_for_file(assigns.input)
    filename = socket.assigns.cwd |> Path.join(file)
    type = assigns.type

    socket =
      with {_, false} <- {:dir, File.dir?(filename)},
           {_, false} <- {:exists, File.exists?(filename)} do
        if type == "new" do
          send(self(), {"new_file", filename})
          push_event(socket, "hide_modal", %{id: assigns.id})
        else
          put_flash(socket, :error, "file not exists!")
        end
      else
        {:dir, true} ->
          cwd_changed(filename, socket)
          |> put_flash(:info, "is a dir,not a file")

        {:exists, true} ->
          if type == "open" do
            send(self(), {"open_file", filename})
            push_event(socket, "hide_modal", %{id: assigns.id})
          else
            put_flash(socket, :error, "file already exists!")
          end
      end

    {:noreply, socket}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  defp cwd_changed(cwd, socket) do
    type = socket.assigns.type

    files =
      File.ls!(cwd)
      |> Stream.map(&Path.join(cwd, &1))
      |> filter_files_by_type(type)
      |> Enum.map(&Path.basename(&1))

    assign(socket, cwd: cwd, files: files)
  end

  defp filter_files_by_type(files, "new") do
    # only show dir
    Stream.filter(files, fn filename ->
      not hidden?(filename) && File.dir?(filename)
    end)
  end

  defp filter_files_by_type(files, "open") do
    # show dir & *.html.heex
    Stream.filter(files, fn filename ->
      not hidden?(filename) &&
        (File.dir?(filename) || valid_extension?(filename, [".heex"]))
    end)
  end

  defp hidden?(filename) do
    String.starts_with?(filename, ".")
  end

  defp valid_extension?(filename, extnames) do
    Path.extname(filename) in extnames
  end

  defp maybe_add_ext_for_file(file) do
    case String.split(file, ".", parts: 2) do
      [^file] -> file <> ".html.heex"
      _other -> file
    end
  end
end
