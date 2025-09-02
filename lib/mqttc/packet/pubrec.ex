defmodule Mqttc.Packet.Pubrec do
  @moduledoc false
  alias Mqttc.Packet
  @opcode 5
  @flags 0b0000

  @type t :: %__MODULE__{
          __META__: Packet.Meta.t(),
          identifier: Mqttc.package_identifier(),
          reason_code: non_neg_integer(),
          properties: keyword()
        }
  @enforce_keys [:identifier]
  defstruct __META__: %Packet.Meta{opcode: @opcode, flags: @flags},
            identifier: nil,
            reason_code: 0,
            properties: []

  @spec decode(binary()) :: t
  def decode(body) when is_binary(body) do
    case body do
      <<identifier::16>> ->
        %__MODULE__{identifier: identifier}

      <<identifier::16, reason_code::8>> ->
        %__MODULE__{identifier: identifier, reason_code: reason_code}

      <<identifier::16, reason_code::8, properties::binary>> ->
        {props, _leftover} = Packet.parse_properties(properties, :pubrec)

        %__MODULE__{
          identifier: identifier,
          reason_code: reason_code,
          properties: props
        }
    end
  end

  defimpl Mqttc.Encodable do
    def encode(%Packet.Pubrec{identifier: identifier} = t)
        when identifier in 0x0001..0xFFFF do
      [
        Packet.Meta.encode(t.__META__),
        Packet.variable_length_encode([
          <<identifier::16>>,
          <<t.reason_code>>,
          Packet.encode_properties(t.properties, :pubrec)
        ])
      ]
    end
  end
end
