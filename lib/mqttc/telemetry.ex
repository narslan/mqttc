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
      [:mqttc, :connected]
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

  def handle_event([:mqttc, event], _measurements, metadata, :no_config) do
    case event do
      [:connected] -> Logger.info("Connection established", metadata.client_id)
      _ -> Logger.info("not implemented")
    end
  end
end
