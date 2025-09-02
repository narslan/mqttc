defmodule Mqttc.Packet.Subscribe do
  @moduledoc false
  alias Mqttc.Packet
  alias Mqttc.Packet.Property
  @opcode 8
  @flags 0b0010

  @type t :: %__MODULE__{
          __META__: Packet.Meta.t(),
          identifier: Mqttc.packet_identifier() | nil,
          properties: [{String.t(), any()}],
          payload: keyword() | nil
        }

  defstruct __META__: %Packet.Meta{opcode: @opcode, flags: @flags},
            identifier: nil,
            properties: [],
            payload: []

  def build(opts) do
    struct(__MODULE__, opts)
  end

  @spec decode(binary()) :: t()
  def decode(header_and_properties) do
    <<identifier::16, rest::binary>> = header_and_properties
    {properties, payload_bin} = Packet.parse_properties(rest, :subscribe)

    %__MODULE__{
      identifier: identifier,
      properties: properties,
      payload: parse_payload(payload_bin)
    }
  end

  defp parse_payload(<<>>), do: []

  defp parse_payload(
         <<length::16, topic::binary-size(length),
           <<0::2, retain_handling::2, retain_as_published::1, no_local::1, qos::2>>,
           rest::binary>>
       ) do
    [{topic, retain_handling, retain_as_published, no_local, qos} | parse_payload(rest)]
  end

  defimpl Mqttc.Encodable do
    def encode(%Packet.Subscribe{} = t) do
      [
        Packet.Meta.encode(t.__META__),
        Packet.variable_length_encode([
          encode_variable_header(t),
          encode_payload(t.payload)
        ])
      ]
    end

    defp encode_variable_header(%Packet.Subscribe{identifier: identifier, properties: props})
         when identifier in 0x0001..0xFFFF do
      [
        <<identifier::16>>,
        Packet.encode_properties(props, :subscribe)
      ]
    end

    defp encode_payload(payload) do
      Enum.map(payload, fn {topic, retain_handling, retain_as_published, no_local, qos} ->
        [
          Property.write_binary(topic),
          <<0::2, retain_handling::2, retain_as_published::1, no_local::1, qos::2>>
        ]
      end)
    end
  end
end
