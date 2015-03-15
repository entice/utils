defmodule Entice.Utils.ETSSupervisor do
  @moduledoc """
  Idea taken from José Valim:
  https://gist.github.com/josevalim/233ae30533a9ad51861b
  """
  use GenServer
  alias Entice.Utils.ETSSupervisor


  @doc """
  Starts the server, invoked by the app supervisor.
  """
  def start_link(name, opts \\ []),
  do: GenServer.start_link(__MODULE__, name, opts)


  @doc """
  Looks up an entry for the given id.
  """
  def lookup(name, id) do
    case :ets.lookup(name, id) do
      [{^id, pid}] -> {:ok, pid}
      _            -> {:error, :id_not_found}
    end
  end


  @doc """
  Retrieves all currently registered entries, as a
  list of id and process.
  """
  def get_all(name), do: :ets.tab2list(name)


  @doc """
  Manually requests a worker to be started.
  """
  def start(name, id, args \\ []),
  do: GenServer.call(name, {:start, id, args})


  @doc """
  Kills a worker if it exists. Does nothing otherwise.
  """
  def terminate(name, id),
  do: GenServer.call(name, {:terminate, id})


  @doc """
  Terminate all servers, cleaning up the ets table. Used by tests.
  """
  def clear(name), do: GenServer.call(name, :clear)


  ## Backend


  def init(name) do
    :ets.new(name, [:set, :protected, :named_table, {:read_concurrency, true}])
    {:ok, name}
  end

  def handle_call({:start, id, args}, _from, name) do
    case :ets.lookup(name, id) do
      [{^id, other_pid}] ->
        {:reply, {:error, :process_already_registered, other_pid}, name}
      _ ->
        {:ok, pid} = ETSSupervisor.Spawner.start_child(Module.concat(name, Spawner), args)
        Process.monitor(pid)
        :ets.insert(name, {id, pid})
        {:reply, {:ok, pid}, name}
    end
  end

  def handle_call({:terminate, id}, _from, name) do
    case :ets.lookup(name, id) do
      [{^id, pid}] ->
        :ok = ETSSupervisor.Spawner.terminate_child(Module.concat(name, Spawner), pid)
        :ets.delete(name, id)
        {:reply, :ok, name}
      _ -> {:reply, :error, name}
    end
  end

  def handle_call(:clear, _from, name) do
    for {id, pid} <- :ets.tab2list(name) do
      :ok = ETSSupervisor.Spawner.terminate_child(Module.concat(name, Spawner), pid)
      :ets.delete(name, id)
    end

    {:reply, :ok, name}
  end

  def handle_call(msg, from, name), do: super(msg, from, name)

  def handle_info({:DOWN, _ref, :process, pid, _reason}, name) do
    :ets.match_delete(name, {:_, pid})
    {:noreply, name}
  end

  def handle_info(msg, name), do: super(msg, name)
end


defmodule Entice.Utils.ETSSupervisor.Spawner do
  @moduledoc false
  use Supervisor

  def start_link(spawned, opts \\ []),
  do: Supervisor.start_link(__MODULE__, spawned, opts)

  def start_child(spawner, args),
  do: Supervisor.start_child(spawner, args)

  def terminate_child(spawner, id),
  do: Supervisor.terminate_child(spawner, id)

  def init(spawned) do
    children = [
      worker(spawned, [], restart: :temporary)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end


defmodule Entice.Utils.ETSSupervisor.Sup do
  @moduledoc false
  use Supervisor
  alias Entice.Utils.ETSSupervisor

  def start_link(name, spawned),
  do: Supervisor.start_link(__MODULE__, {name, spawned})

  def init({name, spawned}) do
    children = [
      worker(ETSSupervisor, [name, [name: name]]),
      supervisor(ETSSupervisor.Spawner, [spawned, [name: Module.concat(name, Spawner)]])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
