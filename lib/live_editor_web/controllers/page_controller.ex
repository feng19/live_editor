defmodule LiveEditorWeb.PageController do
  use LiveEditorWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: "/editor")
  end
end
