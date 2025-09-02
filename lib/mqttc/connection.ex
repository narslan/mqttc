defmodule Mqttc.Connection do
  @moduledoc false
  @behaviour :gen_statem
  require Logger

  alias Mqttc.Packet

  alias Mqttc.Packet.{
    Connack,
    Publish,
    Puback,
    Pubrec,
    Pubrel,
    Pubcomp,
    Subscribe,
    Suback,
    Pingreq,
    Pingresp,
    Disconnect,
    Unsubscribe,
    Unsuback,
    Auth
  }

  @impl true
  def callback_mode() do
    :state_functions
  end

  defstruct [
    :host,
    :port,
    :socket,
    :manager_pid,
    :connect_options,
    :ping_ref,
    :ping_interval,
    :buffer,
    pending_pubs: %{},
    tcp_opts: [:binary, active: :once],
    ssl: false,
    ssl_opts: []
  ]

  @spec start_link(keyword()) :: :gen_statem.start_ret()
  def start_link(opts) when is_list(opts) do
    {gen_statem_opts, other_opts} = Keyword.split(opts, [:debug, :hibernate_after, :spawn_opt])
    gen_statem_opts = Keyword.merge(gen_statem_opts, Keyword.take(other_opts, [:name]))
    {gen_statem_opts, other_opts}

    {tcp_options, mqtt_connect_packet_options} =
      Keyword.split(opts, [:host, :port, :manager_pid, :ping_interval, :ssl, :ssl_opts])

    case NimbleOptions.validate(mqtt_connect_packet_options, Mqttc.Options.connect_opts_schema()) do
      {:ok, validated_connect_options} ->
        connect_packet = Mqttc.Packet.Connect.build(validated_connect_options)
        :gen_statem.start_link(__MODULE__, {tcp_options, connect_packet}, gen_statem_opts)

      {:error, %NimbleOptions.ValidationError{} = err} ->
        {:error, {:invalid_connect_options, Exception.message(err)}}
    end
  end

  @impl true
  def init({tcp_options, connect_packet}) do
    case Keyword.fetch(tcp_options, :manager_pid) do
      :error ->
        {:stop, {:invalid_connect_options, ":manager_pid is required"}}

      {:ok, manager_pid} ->
        host = Keyword.get(tcp_options, :host, "localhost")
        port = Keyword.get(tcp_options, :port, 1883)
        ssl = Keyword.get(tcp_options, :ssl, false)
        ssl_opts = Keyword.get(tcp_options, :ssl_opts, [])
        interval = Keyword.get(tcp_options, :ping_interval, 60_000)

        data = %__MODULE__{
          host: String.to_charlist(host),
          port: port,
          manager_pid: manager_pid,
          connect_options: connect_packet,
          ping_ref: nil,
          ping_interval: interval,
          ssl: ssl,
          ssl_opts: ssl_opts
        }

        {:ok, :disconnected, data, [{:state_timeout, 0, :reconnect}]}
    end
  end

  ## --- disconnected ---
  def disconnected(:enter, _old, _data) do
    Logger.info("Entering disconnected state")
    {:keep_state_and_data, [{:state_timeout, 1000, :reconnect}]}
  end

  def disconnected(event_type, event_content, data)
      when {event_type, event_content} in [{:internal, :connect}, {:state_timeout, :reconnect}] do
    case Mqttc.Sock.connect(data.host, data.port, data.tcp_opts, data.ssl, data.ssl_opts) do
      {:ok, socket} ->
        Logger.info("Socket connected, sending CONNECT")
        set_active_once(socket)
        Mqttc.Sock.send(socket, Packet.encode(data.connect_options))
        {:next_state, :connecting, %{data | socket: socket}}

      {:error, reason} ->
        Logger.error("Connection failed: #{inspect(reason)}")
        {:keep_state_and_data, [{:state_timeout, 2000, :reconnect}]}
    end
  end

  def disconnected(:info, {:ssl_closed, _reason}, data) do
    {:stop, :normal, data}
  end

  def disconnected(:info, {:tcp_closed, _socket}, data) do
    {:stop, :normal, data}
  end

  ## --- connecting ---
  def connecting(:info, %Mqttc.Packet.Connack{} = ack, data) do
    if ack.reason_code == :success do
      Logger.info("Connected to broker")
      {:next_state, :connected, data}
    else
      Logger.error("Connack rejected: #{inspect(ack)}")
      {:next_state, :disconnected, %{data | socket: nil}, [{:state_timeout, 2000, :reconnect}]}
    end
  end

  def connecting(:info, {transport, socket, packet}, data) when transport in [:tcp, :ssl] do
    # Convert packet to binary in case it's an iolist
    packet_bin = :erlang.iolist_to_binary(packet)
    buffer = (data.buffer || <<>>) <> packet_bin
    {packets, leftover} = decode_all(buffer, [])

    case Enum.find(packets, fn p -> match?(%Connack{}, p) end) do
      %Connack{reason_code: :accepted} ->
        # Activate the socket again for further messages
        set_active_once({transport, socket})

        GenServer.cast(data.manager_pid, :connection_ready)

        actions = [
          {:next_event, :internal, :connection_established}
        ]

        {:next_state, :connected, %{data | buffer: leftover}, actions}

      %Connack{reason_code: {:refused, reason}} ->
        {:stop, {:shutdown, {:connection_refused, reason}}, data}

      nil ->
        {:keep_state, %{data | buffer: leftover}}
    end
  end

  def connecting(:info, {transport_closed, _sock}, data)
      when transport_closed in [:tcp_closed, :ssl_closed] do
    {:next_state, :disconnected, data, [{{:timeout, :reconnect}, 1500, nil}]}
  end

  def connecting(:info, {transport_error, _sock, _reason}, data)
      when transport_error in [:tcp_error, :ssl_error] do
    {:next_state, :disconnected, data, [{{:timeout, :reconnect}, 1500, nil}]}
  end

  def connected(:internal, {:incoming_puback, %Puback{identifier: id}}, data) do
    case Map.pop(data.pending_pubs, id) do
      {%{from: from}, new_pending} ->
        :gen_statem.reply(from, :ok)
        {:keep_state, %{data | pending_pubs: new_pending}}

      _ ->
        {:keep_state, data}
    end
  end

  def connected(:info, :pingreq, data) do
    Mqttc.Sock.send(data.socket, Packet.encode(%Pingreq{}))
    # schedule the next ping
    ping_ref = Process.send_after(self(), :pingreq, data.ping_interval)
    {:keep_state, %{data | ping_ref: ping_ref}}
  end

  def connected({:call, from}, {:subscription_request, %Subscribe{} = subscription_packet}, data) do
    Mqttc.Sock.send(data.socket, Packet.encode(subscription_packet))
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def connected({:call, from}, {:pub_request, %Publish{qos: 0} = pub}, data) do
    Logger.debug("call from pub request")
    Mqttc.Sock.send(data.socket, Packet.encode(pub))
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def connected({:call, from}, {:pub_request, %Publish{qos: 1} = pub}, data) do
    Mqttc.Sock.send(data.socket, Packet.encode(pub))

    new_pending = Map.put(data.pending_pubs, pub.identifier, %{pub: pub, from: from})

    {:keep_state, %{data | pending_pubs: new_pending}}
  end

  def connected({:call, from}, {:pub_request, %Publish{qos: 2} = pub}, data) do
    Mqttc.Sock.send(data.socket, Packet.encode(pub))

    pending = Map.put(data.pending_pubs, pub.identifier, %{from: from, stage: :waiting_pubrec})

    {:keep_state, %{data | pending_pubs: pending}}
  end

  def connected({:call, from}, {:unsub_request, %Unsubscribe{} = unsubscribe_packet}, data) do
    Mqttc.Sock.send(data.socket, Packet.encode(unsubscribe_packet))
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  def connected({:call, from}, :pubrel_request, data) do
    {:keep_state, data, [{:reply, from}]}
  end

  def connected({:call, from}, :wait_connection, data) do
    {:keep_state, data, [{:reply, from, :ok}]}
  end

  # Handle disconnect event fom state machine if we disconnect on purpose.
  def connected({:call, from}, {:disconnect_request, %Disconnect{} = packet}, data) do
    Mqttc.Sock.send(data.socket, Packet.encode(packet))
    clean_disconnect(data, from)
  end

  # Handle disconnect event fom state machine if our application get disconnected from broker.
  def connected(:internal, :broker_disconnect, data) do
    clean_disconnect(data)
  end

  def connected(:internal, :connection_established, data) do
    ping_ref = Process.send_after(self(), :pingreq, data.ping_interval)

    {:keep_state, %{data | ping_ref: ping_ref}}
  end

  def connected(:internal, {:incoming_puback, identifier}, data) do
    case Map.pop(data.pending_pubs, identifier) do
      {nil, _} ->
        Logger.warning("received PUBACK for unknown id #{identifier}")
        {:keep_state, data}

      {%{from: from}, new_pending} ->
        Logger.debug("puback received #{identifier}")
        {:keep_state, %{data | pending_pubs: new_pending}, [{:reply, from, :ok}]}
    end
  end

  def connected(:internal, {:incoming_pubrec, id}, data) do
    case Map.get(data.pending_pubs, id) do
      nil ->
        Logger.warning("unexpected PUBREC #{id}")
        {:keep_state, data}

      %{stage: :waiting_pubrec} ->
        Logger.debug("sending PUBREL #{id}")
        pubrel = %Pubrel{identifier: id}
        Mqttc.Sock.send(data.socket, Packet.encode(pubrel))

        new_pending =
          Map.update!(data.pending_pubs, id, fn entry ->
            %{entry | stage: :waiting_pubcomp}
          end)

        {:keep_state, %{data | pending_pubs: new_pending}}
    end
  end

  def connected(:internal, {:incoming_pubcomp, id}, data) do
    case Map.pop(data.pending_pubs, id) do
      {nil, _} ->
        {:keep_state, data}

      {%{from: from}, new_pending} ->
        {:keep_state, %{data | pending_pubs: new_pending}, [{:reply, from, :ok}]}
    end
  end

  # Unexpected TCP/SSL close, reconnect.

  def connected(:info, {transport_closed, _sock}, data)
      when transport_closed in [:tcp_closed, :ssl_closed] do
    schedule_reconnect(data)
  end

  def connected(:info, {transport, socket, packet}, data) when transport in [:tcp, :ssl] do
    packet_bin = :erlang.iolist_to_binary(packet)
    buffer = (data.buffer || <<>>) <> packet_bin

    {packets, leftover} = decode_all(buffer, [])

    {new_data, actions} =
      Enum.reduce(packets, {%{data | buffer: leftover}, []}, fn
        %Suback{} = suback, {acc, acts} ->
          send(
            acc.manager_pid,
            {:suback, %{identifier: suback.identifier, reason_codes: suback.reason_codes}}
          )

          {acc, acts}

        %Unsuback{} = unsuback, {acc, acts} ->
          send(
            acc.manager_pid,
            {:unsuback, %{identifier: unsuback.identifier, reason_codes: unsuback.reason_codes}}
          )

          {acc, acts}

        %Puback{} = puback, {acc, acts} ->
          Logger.info("got puback")
          {acc, acts ++ [{:next_event, :internal, {:incoming_puback, puback.identifier}}]}

        %Publish{} = pub, {acc, acts} ->
          send(acc.manager_pid, {:incoming_publish, pub})
          {acc, acts}

        %Disconnect{}, {acc, acts} ->
          Logger.info("got disconnect from broker")
          {acc, acts ++ [{:next_event, :internal, :broker_disconnect}]}

        %Pubrec{} = pubrec, {acc, acts} ->
          {acc, acts ++ [{:next_event, :internal, {:incoming_pubrec, pubrec.identifier}}]}

        %Pubcomp{} = pubcomp, {acc, acts} ->
          {acc, acts ++ [{:next_event, :internal, {:incoming_pubcomp, pubcomp.identifier}}]}

        %Pingresp{}, {acc, acts} ->
          Logger.info("got ping")
          {acc, acts}

        %Auth{}, {acc, acts} ->
          Logger.info("got auth")
          {acc, acts}
      end)

    set_active_once({transport, socket})
    {:keep_state, new_data, actions}
  end

  # Helper: pull out as many packets as possible from buffer
  defp decode_all(buffer, acc) do
    case Packet.decode(buffer) do
      {:ok, packet, leftover} when not is_nil(packet) ->
        decode_all(leftover, [packet | acc])

      {:ok, nil, leftover} ->
        {Enum.reverse(acc), leftover}

      {:error, :incomplete, leftover} ->
        {Enum.reverse(acc), leftover}

      {:error, _reason, leftover} ->
        {Enum.reverse(acc), leftover}
    end
  end

  # Unexpected loss → reconnect
  defp schedule_reconnect(data) do
    cancel_ping(data)

    {:next_state, :disconnected, %{data | socket: nil, ping_ref: nil},
     [{:next_event, :internal, :connect}]}
  end

  # Clean stop (broker or client requested) → no reconnect
  defp clean_disconnect(data) do
    cancel_ping(data)

    {:next_state, :disconnected, %{data | socket: nil, ping_ref: nil}}
  end

  # Clean stop, but reply to a caller too
  defp clean_disconnect(data, from) do
    cancel_ping(data)
    {:next_state, :disconnected, %{data | socket: nil, ping_ref: nil}, [{:reply, from, :ok}]}
  end

  defp cancel_ping(%{ping_ref: ref}) when is_reference(ref) do
    Process.cancel_timer(ref)
    :ok
  end

  defp cancel_ping(%{ping_ref: nil}), do: :ok
  # --------------
  # Public API
  # --------------
  def send_subscribe(pid, sub_packet) do
    :gen_statem.call(pid, {:subscription_request, sub_packet})
  end

  def send_publish(pid, pub_packet) do
    :gen_statem.call(pid, {:pub_request, pub_packet})
  end

  def send_unsubscribe(pid, unsub_packet) do
    :gen_statem.call(pid, {:unsub_request, unsub_packet})
  end

  def send_disconnect(pid, disconnect_packet) do
    :gen_statem.call(pid, {:disconnect_request, disconnect_packet})
  end

  defp set_active_once({:tcp, socket}), do: :inet.setopts(socket, active: :once)
  defp set_active_once({:ssl, socket}), do: :ssl.setopts(socket, active: :once)
end
