defmodule Mqttc.Packet.AllPacketsTest do
  use ExUnit.Case
  import Mqttc.PacketCase

  # List of Packet variants.  
  @packet_variants [
    # Connect mit Username & Password
    {Mqttc.Packet.Connect,
     [
       %{
         client_id: "user_client",
         clean_start: true,
         keep_alive: 30,
         username: "user",
         password: "secret"
       },

       # Connect mit Will Message
       %{
         client_id: "will_client",
         clean_start: true,
         keep_alive: 10,
         will: true,
         will_topic: "last/will",
         will_payload: "disconnected",
         will_qos: 1,
         will_retain: true,
         will_properties: []
       }
     ]},
    {Mqttc.Packet.Connack,
     [
       %{session_present: true, reason_code: {:refused, :unsupported_protocol_version}},
       %{session_present: false}
     ]},
    {Mqttc.Packet.Publish,
     [
       %{qos: 0, retain: false, topic: "home/temperature", payload: "22°C"},
       %{qos: 1, retain: true, topic: "home/humidity", payload: "50%", identifier: 42}
     ]},
    {Mqttc.Packet.Pingreq,
     [
       %{}
     ]},
    {Mqttc.Packet.Pingresp,
     [
       %{}
     ]},
    # PUBLISH
    {Mqttc.Packet.Publish,
     [
       %{qos: 0, topic: "sensors/temp", payload: "21.5"},
       %{qos: 1, retain: true, topic: "alerts/fire", payload: "smoke!", identifier: 1234},
       %{
         qos: 2,
         topic: "logs/system",
         payload: "critical error",
         identifier: 999,
         properties: [
           {:message_expiry_interval, 300},
           {:user_property, {"source", "server1"}}
         ]
       }
     ]},
    # PUBACK
    {Mqttc.Packet.Puback,
     [
       %{identifier: 1234},
       %{identifier: 2222, reason_code: 0x92, properties: [{:reason_string, "Quota exceeded"}]}
     ]},

    # PUBREC
    {Mqttc.Packet.Pubrec,
     [
       %{identifier: 42},
       %{identifier: 77, reason_code: 0x91}
     ]},

    # PUBREL
    {Mqttc.Packet.Pubrel,
     [
       %{identifier: 42},
       %{identifier: 99, reason_code: 0x80, properties: [{:reason_string, "test_reason"}]}
     ]},

    # PUBCOMP
    {Mqttc.Packet.Pubcomp,
     [
       %{identifier: 42},
       %{identifier: 99, reason_code: 0x92}
     ]},
    {Mqttc.Packet.Subscribe,
     [
       %{identifier: 65535},
       %{
         identifier: 65535,
         payload: [{"home/electricity", 0, 0, 0, 1}, {"home/kitchen", 0, 0, 0, 0}]
       },
       %{
         identifier: 65535,
         properties: [
           {:subscription_identifier, 268_435_455},
           {:user_property, {"p1", "p2"}},
           {:user_property, {"t3", "p3"}}
         ],
         payload: [{"home/electricity", 0, 0, 0, 1}, {"home/kitchen", 0, 0, 0, 0}]
       }
     ]},
    # SUBACK
    {Mqttc.Packet.Suback,
     [
       %{identifier: 100, reason_codes: [0, 1]},
       %{identifier: 101, reason_codes: [0x80], properties: [{:reason_string, "Denied"}]}
     ]},

    # UNSUBSCRIBE
    {Mqttc.Packet.Unsubscribe,
     [
       %{identifier: 200, payload: ["home/lights"]},
       %{identifier: 201, payload: ["alerts/+", "sensors/#"]}
     ]},

    # UNSUBACK
    {Mqttc.Packet.Unsuback,
     [
       %{identifier: 200},
       %{identifier: 201, reason_codes: [0x11, 0x80]}
     ]},

    # DISCONNECT
    {Mqttc.Packet.Disconnect,
     [
       %{},
       %{reason_code: 0x81, properties: [{:reason_string, "We disconnected you!"}]}
     ]}
  ]

  # Produce test cases
  for {packet_module, variants} <- @packet_variants do
    for variant <- variants do
      test_name = "#{inspect(packet_module)} with #{inspect(variant)}"

      test test_name do
        packet = struct(unquote(packet_module), unquote(Macro.escape(variant)))
        assert_roundtrip(packet)
      end
    end
  end
end
