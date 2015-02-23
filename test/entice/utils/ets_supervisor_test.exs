defmodule Entice.Utils.ETSSupervisorTest do
  use ExUnit.Case
  alias Entice.Utils.ETSSupervisor


  defmodule TestServer do
    use GenServer

    def start_link(_id, state),
    do: GenServer.start_link(__MODULE__, state)

    def init(state), do: {:ok, state}

    def handle_call(:test_call, _from, state),
    do: {:reply, state, state}
  end


  setup_all do
    {:ok, _pid} = ETSSupervisor.Sup.start_link(__MODULE__, TestServer)
    :ok
  end


  test "creation" do
    assert {:ok, _pid} = ETSSupervisor.start(__MODULE__, "some_id1", [:some_state])
    assert {:error, _reason, _other_pid} = ETSSupervisor.start(__MODULE__, "some_id1", :some_state)
  end

  test "deletion" do
    {:ok, pid} = ETSSupervisor.start(__MODULE__, "some_id2", [:some_state])
    assert Process.alive?(pid) == true
    assert ETSSupervisor.terminate(__MODULE__, "some_id2") == :ok
    assert ETSSupervisor.terminate(__MODULE__, "some_id2") == :error
    assert ETSSupervisor.terminate(__MODULE__, "no_id") == :error
    assert Process.alive?(pid) == false
  end

  test "retrieval" do
    ETSSupervisor.start(__MODULE__, "some_id3", [:some_state])
    assert {:ok, _pid} = ETSSupervisor.lookup(__MODULE__, "some_id3")
    assert {:error, _reason} = ETSSupervisor.lookup(__MODULE__, "no_id")
  end
end
