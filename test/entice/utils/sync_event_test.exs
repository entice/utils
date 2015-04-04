defmodule Entice.Utils.SyncEventTest do
  use ExUnit.Case
  alias Entice.Utils.SyncEvent


  defmodule CompilationTestHandler do
    use Entice.Utils.SyncEvent
    # test if the compiler can make sense of what the macro produces
  end


  defmodule TestHandler do
    use Entice.Utils.SyncEvent
    alias Entice.Utils.SyncEventTest.TestHandler2

    def init({:state, %{} = state}, test_pid), do: {:ok, {:state, Map.merge(state, %{pid: test_pid, test: 1})}}

    def handle_event(:bar, {:state, %{pid: test_pid}} = state) do
      send(test_pid, {:got, :bar})
      {:ok, state}
    end

    def handle_event(:set, {:state, %{pid: test_pid} = state}) do
      send(test_pid, {:got, :set})
      {:ok, {:state, %{state | test: 2}}}
    end

    def handle_event(:become, {:state, %{pid: test_pid}} = state) do
      send(test_pid, {:got, :become})
      {:become, TestHandler2, {:cool, test_pid}, state}
    end

    def handle_event(:stop, {:state, %{pid: test_pid}} = state) do
      send(test_pid, {:got, :stop})
      {:stop, :some_reason, state}
    end

    def handle_change({:state, %{test: 1}}, {:state, %{pid: test_pid, test: 2}} = state) do
      send(test_pid, {:got, :change})
      :ok
    end

    def handle_call(:calling, {:state, %{pid: test_pid}} = state) do
      send(test_pid, {:got, :call})
      {:ok, :call_reply, state}
    end

    def handle_call(:call_set, {:state, %{pid: test_pid} = state}) do
      send(test_pid, {:got, :call_set})
      {:ok, :call_reply, {:state, %{state | test: 2}}}
    end

    def terminate(reason, {:state, %{pid: test_pid}} = state) do
      send(test_pid, {:got, :terminate, reason})
      {:ok, state}
    end
  end


  defmodule TestHandler2 do
    use Entice.Utils.SyncEvent

    def init({:state, %{pid: test_pid} = state}, {:cool, test_pid}),
    do: {:ok, {:state, Map.merge(state, %{cool: test_pid, test: 3})}}

    def handle_event(:bar2, {:state, %{pid: test_pid, cool: test_pid, test: 3}} = state) do
      send(test_pid, {:got, :bar2})
      {:ok, state}
    end

    def terminate(_reason, {:state, %{pid: test_pid}} = state) do
      send(test_pid, {:got, :terminate2})
      {:ok, state}
    end
  end


  setup do
    {:ok, pid} = SyncEvent.start_link({:state, %{}})
    SyncEvent.put_handler(pid, TestHandler, self)

    {:ok, [handler: pid]}
  end


  test "handler adding & event reaction", %{handler: pid} do
    assert SyncEvent.has_handler?(pid, TestHandler) == true

    # send normal event
    SyncEvent.notify(pid, :bar)
    assert_receive {:got, :bar}

    # send unhandled event (no handler handles it)
    SyncEvent.notify(pid, :nop)
    refute_receive _

    # send normal event, should still behave the same
    SyncEvent.notify(pid, :bar)
    assert_receive {:got, :bar}
  end


  test "state manipulation from handler", %{handler: pid} do
    SyncEvent.notify(pid, :set)
    assert_receive {:got, :set}
    assert_receive {:got, :change}
  end


  test "state manipulation from handler w/ call", %{handler: pid} do
    SyncEvent.call(pid, TestHandler, :call_set)
    assert_receive {:got, :call_set}
    assert_receive {:got, :change}
  end


  test "becoming", %{handler: pid} do
    SyncEvent.notify(pid, :become)
    assert_receive {:got, :become}
    assert_receive {:got, :terminate, :remove_handler}

    assert SyncEvent.has_handler?(pid, TestHandler2) == true
    assert SyncEvent.has_handler?(pid, TestHandler) == false

    SyncEvent.notify(pid, :bar2)
    assert_receive {:got, :bar2}
  end


  test "stopping", %{handler: pid} do
    SyncEvent.notify(pid, :stop)
    assert_receive {:got, :stop}
    assert_receive {:got, :terminate, :some_reason}

    assert SyncEvent.has_handler?(pid, TestHandler) == false

    # send normal event, now shouldnt respond
    SyncEvent.notify(pid, :bar)
    refute_receive {:got, :bar}
  end


  test "calling", %{handler: pid} do
    :call_reply = SyncEvent.call(pid, TestHandler, :calling)
    assert_receive {:got, :call}

    {:error, :not_found} = SyncEvent.call(pid, TestHandler2, :calling)
  end


  test "handler removal", %{handler: pid} do
    # shouldnt do anything if handler not present
    SyncEvent.remove_handler(pid, TestHandler2)
    refute_receive {:got, :terminate2}

    SyncEvent.remove_handler(pid, TestHandler)
    assert_receive {:got, :terminate, :remove_handler}

    assert SyncEvent.has_handler?(pid, TestHandler) == false

    # send normal event, now shouldnt respond
    SyncEvent.notify(pid, :bar)
    refute_receive {:got, :bar}
  end


  test "handler terminated when SyncEvent terminates", %{handler: pid} do
    Process.exit(pid, :normal)
    assert_receive {:got, :terminate, :normal}

    # send normal event, now shouldnt respond
    SyncEvent.notify(pid, :bar)
    refute_receive {:got, :bar}
  end
end
