if System.get_env("MQTTC_DEBUG") do
  Mqttc.Telemetry.attach_default_handler()
  # Mqttc.Telemetry.attach_debug_handler()
end

ExUnit.start()
