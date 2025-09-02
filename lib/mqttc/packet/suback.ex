defmodule Mqttc.Packet.Suback do
  @moduledoc false
  alias Mqttc.Packet

  @opcode 9
  @flags 0b0000
  @type t :: %__MODULE__{
          __META__: Packet.Meta.t(),
          identifier: Mqttc.packet_identifier(),
          reason_codes: [non_neg_integer()],
          properties: keyword()
        }

  defstruct __META__: %Packet.Meta{opcode: @opcode, flags: @flags},
            identifier: 0,
            reason_codes: [],
            properties: []

  @spec decode(binary()) :: t()
  def decode(body) do
    <<identifier::16, rest::binary>> = body
    {properties, payload} = Packet.parse_properties(rest, :suback)

    %__MODULE__{
      identifier: identifier,
      properties: properties,
      reason_codes: parse_payload(payload)
    }
  end

  defp parse_payload(payload), do: :binary.bin_to_list(payload)

  # The Payload contains a list of Reason Codes.
  # Each Reason Code corresponds to a Topic Filter in the SUBSCRIBE packet being acknowledged.
  defimpl Mqttc.Encodable do
    def encode(%Packet.Suback{identifier: identifier} = t)
        when identifier in 0x0001..0xFFFF do
      [
        Packet.Meta.encode(t.__META__),
        Packet.variable_length_encode([
          <<identifier::16>>,
          Packet.encode_properties(t.properties, :suback),
          encode_payload(t.reason_codes)
        ])
      ]
    end

    defp encode_payload(reason_codes), do: :binary.list_to_bin(reason_codes)
  end
end
