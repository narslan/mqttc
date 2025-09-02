defmodule Mqttc.Packet.Auth do
  @moduledoc false

  @opcode 15
  @flags 0b0000
  alias Mqttc.Packet

  @opaque t :: %__MODULE__{
            __META__: Packet.Meta.t(),
            reason_code: non_neg_integer(),
            properties: keyword()
          }
  defstruct __META__: %Packet.Meta{opcode: @opcode, flags: @flags},
            reason_code: 0,
            properties: []

  @spec decode(binary()) :: t
  def decode(body) when is_binary(body) do
    <<reason_code::8, properties::binary>> = body

    {properties, _leftover} = Packet.parse_properties(properties, :auth)

    %__MODULE__{
      reason_code: reason_code,
      properties: properties
    }
  end

  # Protocols ----------------------------------------------------------
  defimpl Mqttc.Encodable do
    def encode(%Packet.Auth{reason_code: reason_code, properties: properties} = t) do
      [
        Packet.Meta.encode(t.__META__),
        Packet.variable_length_encode([
          reason_code,
          Packet.encode_properties(properties, :auth)
        ])
      ]
    end
  end
end
