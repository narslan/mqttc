defmodule Mqttc do
  @moduledoc """
  An **Elixir MQTT v5 client**.

  ## Overview 
  This module provides the user-facing API to interact with MQTT Brokers.
  It provides tools for managing MQTT connections, subscriptions, and publishing.

  `start_link/1` starts a process that connects to a MQTT Broker. Each process
  starts with this function maps a client TCP/SSL connection to the specified
  an MQTT Server.

  ## Reconnections: 

  If there's a network error or if the connection to the MQTT Server
  drops, Mqttc tries to reconnect. The disconnect packets from server
  or the execution of `disconnect/1` does not trigger this behaviour.

  ## Example

      {:ok, pid} = Mqttc.start_link_sync(host: "test.mosquitto.org", port: 1883)

      # Subscribe with handlers
      Mqttc.subscribe(pid, [
        {"sensors/temp", fn msg -> IO.inspect(msg, label: "Temperature") end}
      ])

      # Publish a message
      Mqttc.publish(pid, "sensors/temp", "25°C")

      # Disconnect
      Mqttc.disconnect(pid)

  #{NimbleOptions.docs(Mqttc.Options.connect_opts_schema())}

  """
  alias Mqttc.Manager

  def ensure_supervisor_started() do
    case Process.whereis(Mqttc.Supervisor) do
      nil -> Mqttc.Supervisor.start_link([])
      pid -> {:ok, pid}
    end
  end

  def start_link(opts \\ []) do
    {:ok, _sup} = ensure_supervisor_started()
    Mqttc.Supervisor.start_child(opts)
  end

  @doc """
  Starts a new MQTT connection and waits until the **CONNACK**
  packet is received from the broker. This function ensures that a connection 
  established between the client and the broker, before returning.

  #{NimbleOptions.docs(Mqttc.Options.connect_opts_schema())}

  ## Examples

      iex> {:ok, pid} = Mqttc.start_link_sync(host: "test.mosquitto.org")
      {:ok, #PID<0.123.0>}
      
  """
  def start_link_sync(opts \\ [], timeout \\ 5_000) do
    caller = self()
    {:ok, pid} = start_link(Keyword.put(opts, :notify, caller))
    # Wait until connected.
    if wait_until_connected(pid, timeout) do
      {:ok, pid}
    else
      {:error, :timeout}
    end
  end

  defp wait_until_connected(pid, timeout) do
    ref = Process.monitor(pid)

    receive do
      {:mqttc_connected, ^pid} ->
        Process.demonitor(ref, [:flush])
        true

      {:DOWN, ^ref, :process, ^pid, _reason} ->
        false
    after
      timeout ->
        false
    end
  end

  @doc """
  Publishes a message to the given topic.

  #{NimbleOptions.docs(Mqttc.Options.publish_schema())}

  ## Example

      iex> Mqttc.publish(pid, "sensors/temp", "25°C", qos: 1)
      :ok
  """
  def publish(pid, topic, payload, opts \\ []) do
    qos = Keyword.get(opts, :qos, 0)
    retain = Keyword.get(opts, :retain, false)
    dup = Keyword.get(opts, :dup, 0)

    {pub_properties, _} =
      Keyword.split(opts, [
        :payload_format_indicator,
        :message_expiry_interval,
        :topic_alias,
        :response_topic,
        :correlation_data,
        :user_property,
        :subscription_identifier,
        :content_type
      ])

    input = Keyword.merge(opts, payload: payload, topic: topic)

    case NimbleOptions.validate(input, Mqttc.Options.publish_schema()) do
      {:ok, _} ->
        packet =
          Mqttc.Packet.Publish.build(
            topic: topic,
            payload: payload,
            qos: qos,
            dup: dup,
            retain: retain,
            properties: pub_properties
          )

        start_time = System.monotonic_time(:millisecond)

        case Mqttc.Manager.call_publish(pid, packet) do
          :ok ->
            :telemetry.execute(
              [:mqttc, :packet, :published],
              %{
                duration: System.monotonic_time(:millisecond) - start_time,
                size: byte_size(payload)
              },
              %{topic: topic, qos: qos}
            )

            :ok

          {:error, reason} ->
            {:error, reason}
        end

      {:error, %NimbleOptions.ValidationError{} = err} ->
        {:error, {:invalid_options, Exception.message(err)}}
    end
  end

  @doc """
  Subscribes to one or multiple topics.

  Each topic must be given with a handler function with arity one that will
  be invoked whenever a message is received.

    * `{"topic/name", fn msg -> ... end}`

  The `opts` keyword list allows you to configure the MQTT v5
  **Subscription Options**, which are applied to all given topics.

  Available options:

  #{NimbleOptions.docs(Mqttc.Options.subscribe_schema())}
  Returns `:ok` once the SUBSCRIBE packet has been sent. The acknowledgement
  (`SUBACK`) is handled asynchronously.

  ## Example

      iex> Mqttc.subscribe(pid, [
        ...>   {"sensors/temp", fn msg -> IO.inspect(msg, label: "Temp") end},
        ...>   {"sensors/humidity", fn msg -> IO.inspect(msg, label: "Humidity") end}
        ...> ])
       :ok

  Subscribe with custom QoS and retain handling for all topics:

      iex> Mqttc.subscribe(pid, [
        ...>   {"alerts/critical", fn msg -> IO.inspect(msg, label: "ALERT") end}
        ...> ], qos: 1, retain_handling: 2)
      :ok

  """
  def subscribe(pid, topics_with_handlers, opts \\ []) do
    # make sure topics is a list of tuples (so single tuple also works)
    topics = List.wrap(topics_with_handlers)

    # put the topics into the options we validate (positional arg wins)
    input = Keyword.put_new(opts, :topics, topics)

    case NimbleOptions.validate(input, Mqttc.Options.subscribe_schema()) do
      {:ok, v} ->
        identifier = :rand.uniform(65_535)

        # store pending subs (handlers are kept in v[:topics])
        GenServer.cast(pid, {:pending_subscribe, identifier, v[:topics]})

        sub_payload =
          Enum.map(v[:topics], fn {topic, _handler} ->
            {topic, v[:retain_handling], v[:retain_as_published], v[:no_local], v[:qos]}
          end)

        {sub_properties, _} = Keyword.split(opts, [:subscription_id, :user_property])

        packet =
          Mqttc.Packet.Subscribe.build(
            identifier: identifier,
            properties: sub_properties,
            payload: sub_payload
          )

        start_time = System.monotonic_time(:millisecond)

        case Mqttc.Manager.call_subscribe(pid, packet) do
          :ok ->
            :telemetry.execute(
              [:mqttc, :packet, :subscribed],
              %{
                duration: System.monotonic_time(:millisecond) - start_time
              },
              %{topics: Enum.map(v[:topics], &elem(&1, 0)), qos: v[:qos]}
            )

            :ok

          {:error, reason} ->
            {:error, reason}
        end

      {:error, %NimbleOptions.ValidationError{} = err} ->
        {:error, {:invalid_options, Exception.message(err)}}
    end
  end

  @doc """
  Unsubscribes from a given topic.

  ## Example

      iex> Mqttc.unsubscribe(pid, "sensors/temp")
      :ok
  """

  def unsubscribe(pid, topics) do
    topics = List.wrap(topics)
    identifier = :rand.uniform(65_535)

    # Store pending unsubscribe packets. 
    GenServer.cast(pid, {:pending_unsubscribe, identifier, topics})

    unsub_packet = %Mqttc.Packet.Unsubscribe{
      identifier: identifier,
      payload: topics
    }

    start_time = System.monotonic_time(:millisecond)

    case Manager.call_unsubscribe(pid, unsub_packet) do
      :ok ->
        :telemetry.execute(
          [:mqttc, :packet, :unsubscribed],
          %{duration: System.monotonic_time(:millisecond) - start_time},
          %{topics: topics}
        )

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Disconnects cleanly from the broker.

  ## Example

      iex> Mqttc.disconnect(pid)
      :ok
  """
  def disconnect(pid, opts \\ []) do
    disc_packet = Mqttc.Packet.Disconnect.new(opts)

    Manager.cast_disconnect(pid, disc_packet)

    :telemetry.execute(
      [:mqttc, :connection, :disconnected],
      %{},
      %{reason: Keyword.get(opts, :reason, :client_request)}
    )
  end
end
