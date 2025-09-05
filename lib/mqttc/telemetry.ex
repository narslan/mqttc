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
  | `[:mqtcc, :connected]`     
  """

  @spec attach_default_handler() :: :ok
  def attach_default_handler do
    events = [
      [:mqttc, :connection, :established],
      [:mqttc, :packet, :published]
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

      [:packet, :published] ->
        Logger.info("Published topic #{inspect(metadata.topic)}")
        Logger.info("Publish duration #{inspect(measurements.duration)}")

      _ ->
        Logger.info("not implemented")
    end
  end
end
