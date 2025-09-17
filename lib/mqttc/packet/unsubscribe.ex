defmodule Mqttc.Packet.Unsubscribe do
  @moduledoc false
  require Logger
  alias Mqttc.Packet
  alias Mqttc.Packet.Property

  @opcode 10
  @flags 0b0010
  @type t :: %__MODULE__{
          __META__: Packet.Meta.t(),
          identifier: Mqttc.packet_identifier() | nil,
          properties: keyword(),
          properties: keyword()
        }

  @enforce_keys [:identifier]
  defstruct __META__: %Packet.Meta{opcode: @opcode, flags: @flags},
            identifier: nil,
            properties: [],
            payload: []

  def new(attributes) when is_list(attributes) do
    struct(__MODULE__, attributes)
  end

  @spec decode(binary()) :: t
  def decode(body) when is_binary(body) do
    <<identifier::16, properties_payload::binary>> = body

    {properties, payload} = Packet.parse_properties(properties_payload, :unsubscribe)

    %__MODULE__{
      identifier: identifier,
      properties: properties,
      payload: parse_payload(payload)
    }
  end

  defp parse_payload(<<>>), do: []

  defp parse_payload(<<topic_length::size(16), rest::binary>>) do
    <<topic::binary-size(^topic_length), rest::binary>> = rest

    [topic] ++ parse_payload(rest)
  end

  defimpl Mqttc.Encodable do
    def encode(%Packet.Unsubscribe{} = t) do
      [
        Packet.Meta.encode(t.__META__),
        Packet.variable_length_encode([
          encode_variable_header(t),
          encode_payload(t.payload)
        ])
      ]
    end

    defp encode_variable_header(%Packet.Unsubscribe{identifier: identifier} = t)
         when identifier in 0x0001..0xFFFF do
      [
        <<identifier::size(16)>>,
        Packet.encode_properties(t.properties, :unsubscribe)
      ]
    end

    defp encode_payload(payload) do
      Enum.map(payload, fn topic ->
        Property.write_binary(topic)
      end)
    end
  end
end
