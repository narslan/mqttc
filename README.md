# Mqttc

> A fast and robust ** MQTT v5 client** for Elixir.  
It aims to provide a reliable MQTT client with a simple user-facing API.

## Features

- Interface for sending MQTT v5 support (CONNECT, SUBSCRIBE, PUBLISH, UNSUBSCRIBE, PING, DISCONNECT).
- Automatic Reconnections
- SSL
- Telemetry support
---

## Installation

Add `mqttc` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mqttc, "~> 0.2"}
  ]
end
```
## Usage: 
 
```elixir
# Connect
{:ok, pid} = Mqttc.start_link(host: "test.mosquitto.org", port: 1883)
# or Start connection and wait until CONNACK received.  
{:ok, pid} = Mqttc.start_link_sync(host: "test.mosquitto.org", port: 1883)


# Subscribe to topics with handlers
Mqttc.subscribe(pid, [
  {"sensors/temp", fn msg -> IO.inspect(msg, label: "Temperature") end},
  {"sensors/humidity", fn msg -> IO.inspect(msg, label: "Humidity") end}
])

# Publish 
Mqttc.publish(pid, "sensors/temp", "25°C")

# Unsubscribe
Mqttc.unsubscribe(pid, "sensors/humidity")

# Disconnect
Mqttc.disconnect(pid)
```
 

Authenticate and connect: 
```elixir
{:ok, pid} =  Mqttc.start_link_sync( host: "test.mosquitto.org", port: 1884, username: "rw", password: "readwrite" )
```
 
 Usage with ssl:
```elixir
{:ok, pid} = Mqttc.start_link(host: "broker.hivemq.com", port: 8883, ssl: true, ssl_opts: [  verify: :verify_peer, cacerts: :public_key.cacerts_get()])
```

### Test:
Integration test requires a running mosquitto instance.
```sh
mix test # run all tests, 
mix test --exclude integration  # test packet encoding and decoding, excludes tests with mosquitto
```

### Telemetry integration 

mqttc provides native support for Telemetry and exposes metrics for published messages. These metrics allow you to monitor payload sizes and publish durations, which can be visualized using tools like Telemetry.ConsoleReporter, Prometheus.

Example of defining the metrics:
```elixir
defmodule MqttObserve.Telemetry do
  import Telemetry.Metrics

  def metrics do
    [
      last_value("mqttc.packet.published.size", unit: :byte),
      summary("mqttc.packet.published.duration", unit: {:native, :millisecond})
    ]
  end
end
```

Example of integrating into an application with ConsoleReporter:
```elixir
defmodule MqttObserve.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Telemetry.Metrics.ConsoleReporter, metrics: MqttObserve.Telemetry.metrics()}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```


## License

Mqttc is released under the MIT license. See the [license file](LICENSE.txt).
