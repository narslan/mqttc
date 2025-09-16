defmodule Mqttc.Telemetry do
  @moduledoc """
  Telemetry integration for event tracing, metrics, and logging.

  Mqttc uses [telemetry](https://github.com/beam-telemetry/telemetry) for reporting
    metrics and events.
  """

  require Logger

  @doc """
  | **Event**                                                      | **Level** |
  | -------------------------------------------------------------- | --------- |
  | `[:mqttc, :connection, :established]`  
  | `[:mqttc, :packet, :published]`  
  | `[:mqttc, :packet, :subscribed]`     
  """

  @spec attach_default_handler() :: :ok
  def attach_default_handler do
    events = [
      [:mqttc, :connection, :established],
      [:mqttc, :connection, :lost],
      [:mqttc, :connection, :reconnect],
      [:mqttc, :connection, :disconnected],
      [:mqttc, :connection, :closed],
      [:mqttc, :packet, :published],
      [:mqttc, :packet, :subscribed],
      [:mqttc, :packet, :unsubscribed]
    ]

    :telemetry.attach_many(
      "mqtcc-default-telemetry-handler",
      events,
      &__MODULE__.handle_event/4,
      :no_config
    )

    :ok
  end

  @doc false
  @spec handle_event(
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          :no_config
        ) :: :ok
  def handle_event(event, measurements, metadata, config)

  def handle_event([:mqttc | event], measurements, metadata, :no_config) do
    case event do
      [:connection, :established] ->
        Logger.info("Connection established #{inspect(metadata.data)}")

      [:connection, :lost] ->
        Logger.info("Connection lost")

      [:connection, :reconnect] ->
        Logger.info("Reconnect")

      [:connection, :disconnected] ->
        Logger.info("Disconnected, reason  #{inspect(metadata.reason)}")

      [:connection, :closed] ->
        Logger.info("Broker closed connection")

      [:packet, :published] ->
        Logger.info("Published topic #{inspect(metadata.topic)}")
        Logger.info("Publish duration #{inspect(measurements.duration)} ms")

      [:packet, :subscribed] ->
        Logger.info("Subscribed topic #{inspect(metadata.topics)}")
        Logger.info("Subscribe duration #{inspect(measurements.duration)} ms")

      [:packet, :unsubscribed] ->
        Logger.info("UnSubscribed topics #{inspect(metadata.topics)}")

      _ ->
        Logger.info("not implemented")
    end
  end
end
