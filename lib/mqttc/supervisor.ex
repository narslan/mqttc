defmodule Mqttc.Supervisor do
  use DynamicSupervisor

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(opts) do
    name = Keyword.get(opts, :name, nil)
    IO.inspect(name, label: "name")

    spec = %{
      id: name,
      start: {Mqttc.Manager, :start_link, [[name: name] ++ opts]},
      restart: :temporary,
      shutdown: 5000,
      type: :worker
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
