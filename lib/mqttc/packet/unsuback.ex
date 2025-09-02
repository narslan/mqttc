defmodule Mqttc.Packet.Unsuback do
  @moduledoc false
  alias Mqttc.Packet
  @opcode 11
  @flags 0b0000

  @type t :: %__MODULE__{
          __META__: Packet.Meta.t(),
          identifier: Mqttc.packet_identifier() | nil,
          reason_codes: [non_neg_integer()],
          properties: keyword()
        }

  @enforce_keys [:identifier]
  defstruct __META__: %Packet.Meta{opcode: @opcode, flags: @flags},
            identifier: nil,
            reason_codes: [],
            properties: []

  @spec decode(binary()) :: t
  def decode(body) when is_binary(body) do
    <<identifier::16, properties_payload::binary>> = body

    {properties, payload} = Packet.parse_properties(properties_payload, :unsuback)

    %__MODULE__{
      identifier: identifier,
      properties: properties,
      reason_codes: parse_payload(payload)
    }
  end

  defp parse_payload(payload) do
    :binary.bin_to_list(payload)
  end

  defimpl Mqttc.Encodable do
    def encode(%Packet.Unsuback{identifier: identifier} = t)
        when identifier in 0x0001..0xFFFF do
      [
        Packet.Meta.encode(t.__META__),
        Packet.variable_length_encode([
          <<identifier::16>>,
          Packet.encode_properties(t.properties, :unsuback),
          encode_payload(t.reason_codes)
        ])
      ]
    end

    defp encode_payload(payload) do
      :binary.list_to_bin(payload)
    end
  end
end
