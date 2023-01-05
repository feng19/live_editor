defmodule LiveEditorWeb.Router do
  use LiveEditorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LiveEditorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LiveEditorWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/editor", EditorLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", LiveEditorWeb do
  #   pipe_through :api
  # end
end
