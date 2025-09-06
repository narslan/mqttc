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
    {:mqttc, "~> 0.1.2"}
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
## License

Mqttc is released under the MIT license. See the [license file](LICENSE.txt).
