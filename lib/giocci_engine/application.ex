defmodule GiocciEngine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    {my_process_name, _} = System.get_env("MY_PROCESS_NAME") |> Code.eval_string()

    children = [
      # Starts a worker by calling: GiocciEngine.Worker.start_link(arg)
      # {GiocciEngine.Worker, arg}
      Supervisor.child_spec({CubDB, [data_dir: "./cubdb/database", name: GiocciEngine.Database]}, id: :database),
      Supervisor.child_spec({CubDB, [data_dir: "./cubdb/module_db", name: GiocciEngine.ModuleDB]}, id: :module_db),
      {GiocciEngine.Cubdb.Store, [my_process_name, []]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GiocciEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
