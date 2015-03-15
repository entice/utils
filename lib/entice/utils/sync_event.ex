defmodule Entice.Utils.SyncEvent do
  @moduledoc """
  Represents a gen_event where handlers are synchronized on the same state.
  """
  use Behaviour
  use GenServer
  import Set


  # Handler API


  defcallback init(state :: term, args :: term) ::
    {:ok, state :: term} |
    {:error, reason :: term}


  defcallback handle_event(event :: String.t, state :: term) ::
    {:ok, state :: term} |
    {:become, new_handler :: atom, args :: term, state :: term} |
    {:stop, reason :: term, state :: term} |
    {:error, reason :: term}


  defcallback handle_change(old_state :: map, state :: map) ::
    {:ok, state :: term} |
    {:become, new_handler :: atom, args :: term, state :: term} |
    {:stop, reason :: term, state :: term} |
    {:error, reason :: term}


  defcallback terminate(reason :: term, state :: term) ::
    {:ok, state :: term} |
    {:error, reason :: term}


  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def init(state, _args), do: {:ok, state}

      def handle_event(event, state), do: {:ok, state}

      def handle_change(old_state, state), do: {:ok, state}

      def terminate(_reason, state), do: {:ok, state}

      defoverridable [init: 2, handle_event: 2, handle_change: 2, terminate: 2]
    end
  end


  # Manager API


  def start_link(state, opts \\ []),
  do: GenServer.start_link(__MODULE__, %{handlers: HashSet.new, state: state}, opts)


  def has_handler?(manager, handler) when is_pid(manager) and is_atom(handler),
  do: GenServer.call(manager, {:has_handler, handler})


  def put_handler(manager, handler, args) when is_pid(manager) and is_atom(handler),
  do: GenServer.cast(manager, {:put_handler, handler, args})


  def remove_handler(manager, handler) when is_pid(manager) and is_atom(handler),
  do: GenServer.cast(manager, {:remove_handler, handler})


  def notify(manager, event) when is_pid(manager),
  do: GenServer.cast(manager, {:notify, event})


  defp state_changed(_manager, old, new) when old == new, do: :ok
  defp state_changed(manager, old, new) when old != new,
  do: notify(manager, {:state_changed, old, new})


  # Backend


  def init(args) do
    Process.flag(:trap_exit, true)
    {:ok, args}
  end


  def handle_call({:has_handler, handler}, _from, state),
  do: {:reply, state.handlers |> member?(handler), state}


  def handle_call(msg, from, state), do: super(msg, from, state)


  def handle_cast({:put_handler, handler, args}, state) do
    {:ok, new_handlers, new_state} =
      handler
      |> handler_init(state.state, args)
      |> handler_result(handler, state.handlers)
    state_changed(self, state.state, new_state)
    {:noreply, %{handlers: new_handlers, state: new_state}}
  end


  def handle_cast({:remove_handler, handler}, state) do
    {:ok, new_handlers, new_state} =
      handler
      |> handler_terminate(:remove_handler, state.state)
      |> handler_exit_result(handler, state.handlers)
    state_changed(self, state.state, new_state)
    {:noreply, %{handlers: new_handlers, state: new_state}}
  end


  def handle_cast({:notify, event}, state) do
    {:ok, new_handlers, new_state} =
      Enum.reduce(state.handlers, {:ok, state.handlers, state.state},
        fn (handler, {:ok, h, s}) ->
          handler
          |> handler_event(event, s)
          |> handler_result(handler, h)
        end)
    state_changed(self, state.state, new_state)
    {:noreply, %{handlers: new_handlers, state: new_state}}
  end


  def handle_cast(msg, state), do: super(msg, state)


  def terminate(reason, state) do
    Enum.reduce(state.handlers, {:ok, state.handlers, state.state},
      fn (handler, {:ok, h, s}) ->
        handler
        |> handler_terminate(reason, s)
        |> handler_exit_result(handler, h)
      end)
    :ok
  end


  # Backend Handler callbacks


  defp handler_init(handler, state, args),
  do: apply(handler, :init, [state, args])


  defp handler_event(handler, {:state_changed, old_state, new_state}, state)
  when new_state == state do
    try do
      apply(handler, :handle_change, [old_state, state])
    rescue
      _ in FunctionClauseError -> {:ok, state}
    end
  end

  defp handler_event(handler, event, state) do
    try do
      apply(handler, :handle_event, [event, state])
    rescue
      _ in FunctionClauseError -> {:ok, state}
    end
  end


  defp handler_terminate(handler, reason, state),
  do: apply(handler, :terminate, [reason, state])


  # Backend Handler results


  defp handler_result({:ok, state}, handler, handlers),
  do: {:ok, handlers |> put(handler), state}

  defp handler_result({:stop, reason, state}, handler, handlers) do
    handler
    |> handler_terminate(reason, state)
    |> handler_exit_result(handler, handlers)
  end

  defp handler_result({:become, new_handler, args, state}, handler, handlers) do
    {:ok, new_handlers, new_state} =
      handler
      |> handler_terminate(:remove_handler, state)
      |> handler_exit_result(handler, handlers)

    new_handler
    |> handler_init(new_state, args)
    |> handler_result(new_handler, new_handlers)
  end

  defp handler_result({:error, reason}, handler, _handlers),
  do: raise "Error in handler #{inspect handler} because of: #{inspect reason}"

  defp handler_result(return, handler, _handlers),
  do: raise "Return was incorrect in handler #{inspect handler}. Check the API documentation for handlers. Got: #{inspect return}"


  defp handler_exit_result({:ok, state}, handler, handlers),
  do: {:ok, handlers |> delete(handler), state}

  defp handler_exit_result({:error, reason}, handler, _handlers),
  do: raise "Error in handler #{inspect handler} because of: #{inspect reason}"

  defp handler_exit_result(return, _handler, _handlers),
  do: raise "Return was incorrect. Check the API documentation for behaviours. Got: #{inspect return}"
end