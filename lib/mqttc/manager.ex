defmodule Mqttc.Manager do
  @moduledoc false
  use GenServer
  require Logger
  alias Mqttc.Connection

  # ------------------------------------------------------------
  # Public API
  # ------------------------------------------------------------
  def start_link(options \\ []) when is_list(options) do
    {genserver_opts, opts} = Keyword.split(options, [:name])
    GenServer.start_link(__MODULE__, opts, genserver_opts)
  end

  # ------------------------------------------------------------
  # Callbacks
  # ------------------------------------------------------------
  @impl true
  def init(options) do
    {notify, options} = Keyword.pop(options, :notify)

    case Connection.start_link(Keyword.put(options, :manager_pid, self())) do
      {:ok, conn} ->
        {:ok,
         %{
           conn: conn,
           connected?: false,
           notify: notify,
           pending_subs: %{},
           pending_subs_calls: %{},
           pending_unsubs: %{},
           active_subs: %{}
         }}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  # ------------------------------------------------------------
  # Connection events
  # ------------------------------------------------------------
  @impl true
  def handle_cast(:connection_ready, %{notify: caller} = state) do
    if caller, do: send(caller, {:mqttc_connected, self()})
    {:noreply, %{state | connected?: true}}
  end

  def handle_cast(:connection_failed, %{notify: caller} = state) do
    if caller, do: send(caller, {:mqtt_error, :connection_failed})
    {:stop, :connection_failed, state}
  end

  def handle_cast({:disconnect, disc}, %{conn: conn, connected?: true} = state) do
    Connection.send_disconnect(conn, disc)
    {:stop, :normal, state}
  end

  def handle_cast({:disconnect, _}, state), do: {:stop, :normal, state}

  # ------------------------------------------------------------
  # Subscription / Unsubscription
  # ------------------------------------------------------------
  def handle_cast({:pending_subscribe, id, topics_with_handlers}, state) do
    new_pending = Map.put(state.pending_subs, id, topics_with_handlers)
    {:noreply, %{state | pending_subs: new_pending}}
  end

  def handle_cast({:pending_unsubscribe, id, topics}, state) do
    new_pending = Map.put(state.pending_unsubs, id, topics)
    {:noreply, %{state | pending_unsubs: new_pending}}
  end

  @impl true
  def handle_info({:suback, %{identifier: id, reason_codes: codes}}, state) do
    topics_with_handlers = Map.get(state.pending_subs, id, [])
    pairs = Enum.zip(topics_with_handlers, codes)

    new_active =
      Enum.reduce(pairs, state.active_subs, fn
        {{topic, handler}, code}, acc when code in [0, 1, 2] ->
          Map.put(acc, topic, %{handler: handler})

        _, acc ->
          acc
      end)

    {from, pending_subs_calls} = Map.pop(state.pending_subs_calls || %{}, id)
    if from, do: GenServer.reply(from, :ok)

    {:noreply,
     %{
       state
       | active_subs: new_active,
         pending_subs: Map.delete(state.pending_subs, id),
         pending_subs_calls: pending_subs_calls
     }}
  end

  @impl true
  def handle_info({:unsuback, %{identifier: id, reason_codes: _codes}}, state) do
    {from, pending_unsubs} = Map.pop(state.pending_unsubs || %{}, id)

    if from, do: GenServer.reply(from, :ok)

    {:noreply, %{state | pending_unsubs: pending_unsubs}}
  end

  def handle_info({:incoming_publish, %{topic: topic} = pub}, %{active_subs: active} = state) do
    Enum.each(active, fn {filter, %{handler: h}} ->
      if topic_matches_filter?(topic, filter), do: h.(pub)
    end)

    {:noreply, state}
  end

  def handle_info(
        {:DOWN, _ref, :process, _pid, {:shutdown, {:connection_refused, reason}}},
        state
      ) do
    Logger.error("Connection refused, not retrying. Reason: #{inspect(reason)}")

    if state.notify, do: send(state.notify, {:connection_refused, reason})
    {:stop, {:connection_refused, reason}, state}
  end

  # ------------------------------------------------------------
  # Call API
  # ------------------------------------------------------------
  @impl true
  def handle_call({:publish, pub}, _from, %{conn: conn, connected?: true} = state) do
    reply =
      call_safe(fn ->
        Connection.send_publish(conn, pub)
        :ok
      end)

    {:reply, reply, state}
  end

  def handle_call({:publish, _pub}, _from, %{conn: _conn, connected?: false} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call({:subscribe, sub_packet}, from, %{conn: conn, connected?: true} = state) do
    reply =
      call_safe(fn ->
        Connection.send_subscribe(conn, sub_packet)
        :ok
      end)

    case reply do
      :ok ->
        pending_subs_calls =
          Map.put(state.pending_subs_calls || %{}, sub_packet.identifier, from)

        {:noreply, %{state | pending_subs_calls: pending_subs_calls}}

      {:error, :no_connection_process} ->
        {:reply, reply, state}
    end
  end

  def handle_call({:subscribe, _pub}, _from, %{conn: _conn, connected?: false} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  # ------------------------------------------------------------
  # Call API for unsubscribe
  # ------------------------------------------------------------
  def handle_call({:unsubscribe, unsub_packet}, from, state) do
    reply =
      call_safe(fn ->
        Connection.send_unsubscribe(state.conn, unsub_packet)
        :ok
      end)

    case reply do
      :ok ->
        pending_unsubs = Map.put(state.pending_unsubs || %{}, unsub_packet.identifier, from)
        {:noreply, %{state | pending_unsubs: pending_unsubs}}

      {:error, :no_connection_process} ->
        {:reply, reply, state}
    end

    # Store Caller, until UNSUBACK arrives
  end

  def handle_call(_req, _from, %{connected?: false} = state),
    do: {:reply, {:error, :not_connected}, state}

  # ------------------------------------------------------------
  # Convenience wrappers
  # ------------------------------------------------------------
  def call_publish(pid, req), do: GenServer.call(pid, {:publish, req})
  def call_subscribe(pid, req), do: GenServer.call(pid, {:subscribe, req})
  def call_unsubscribe(pid, req), do: GenServer.call(pid, {:unsubscribe, req})
  def cast_disconnect(pid, req), do: GenServer.cast(pid, {:disconnect, req})

  # ------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------
  defp topic_matches_filter?(topic, filter) do
    topic_levels = String.split(topic, "/", trim: true)
    filter_levels = String.split(filter, "/", trim: true)
    match_levels(topic_levels, filter_levels)
  end

  defp match_levels([], []), do: true
  # "#" match all others
  defp match_levels(_, ["#"]), do: true

  defp match_levels([_t | t_rest], ["+" | f_rest]),
    do: match_levels(t_rest, f_rest)

  defp match_levels([t | t_rest], [t | f_rest]),
    do: match_levels(t_rest, f_rest)

  defp match_levels(_, _), do: false

  def call_safe(fun) when is_function(fun, 0) do
    try do
      fun.()
    catch
      :exit, {:noproc, _} ->
        {:error, :no_connection_process}
    end
  end
end
