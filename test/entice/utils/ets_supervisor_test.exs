defmodule Entice.Utils.ETSSupervisorTest do
  use ExUnit.Case
  alias Entice.Utils.ETSSupervisor


  defmodule TestServer do
    use GenServer

    def start_link(state),
    do: GenServer.start_link(__MODULE__, state)

    def init(state) do
      Process.flag(:trap_exit, true)
      send state, :received_init
      {:ok, state}
    end

    def handle_call(:test_call, _from, state) do
      send state, :received_call
      {:reply, state, state}
    end

    def terminate(_reason, state) do
      send state, :received_terminate
    end
  end


  setup_all do
    {:ok, _pid} = ETSSupervisor.Sup.start_link(__MODULE__, TestServer)
    :ok
  end


  test "creation" do
    assert {:ok, _pid} = ETSSupervisor.start(__MODULE__, "some_id1", [self])
    assert_receive :received_init
    assert {:error, _reason, _other_pid} = ETSSupervisor.start(__MODULE__, "some_id1", [self])
  end


  test "deletion" do
    {:ok, pid} = ETSSupervisor.start(__MODULE__, "some_id2", [self])
    assert_receive :received_init
    assert Process.alive?(pid) == true

    assert ETSSupervisor.terminate(__MODULE__, "some_id2") == :ok
    assert ETSSupervisor.terminate(__MODULE__, "some_id2") == :error
    assert ETSSupervisor.terminate(__MODULE__, "no_id") == :error

    assert Process.alive?(pid) == false
    assert_receive :received_terminate
  end


  test "retrieval" do
    ETSSupervisor.start(__MODULE__, "some_id3", [self])
    assert_receive :received_init
    assert {:ok, _pid} = ETSSupervisor.lookup(__MODULE__, "some_id3")
    assert {:error, _reason} = ETSSupervisor.lookup(__MODULE__, "no_id")
  end
end
