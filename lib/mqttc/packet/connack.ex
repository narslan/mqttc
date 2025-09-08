defmodule Mqttc.Packet.Connack do
  @moduledoc false

  alias Mqttc.Packet
  alias Mqttc.Packet.Connack.ReasonCodes
  require Logger
  @opcode 2
  @flags 0b0000

  defstruct __META__: %Packet.Meta{opcode: @opcode, flags: @flags},
            session_present: false,
            reason_code: :success,
            properties: []

  def decode(<<0::7, session_present::1, reason_code::8, rest::binary>>) do
    {props, _} = Packet.parse_properties(rest, :connack)

    %__MODULE__{
      session_present: session_present == 1,
      reason_code: coerce_return_code(reason_code),
      properties: props
    }
  end

  defp coerce_return_code(reason_code) do
    case reason_code do
      0x00 ->
        :success

      _ ->
        {:refused, ReasonCodes.name(reason_code)}
    end
  end

  # This is just for testing.
  defimpl Mqttc.Encodable do
    def encode(
          %Packet.Connack{
            session_present: session_present,
            reason_code: reason_code,
            properties: props
          } = t
        ) do
      variable_header = [
        <<0::7, flag(session_present)::1, to_reason_code(reason_code)::8>>,
        Packet.encode_properties(props, :connack)
      ]

      [
        Packet.Meta.encode(t.__META__),
        Packet.variable_length_encode(variable_header)
      ]
    end

    defp to_reason_code(nil), do: 0x00
    defp to_reason_code(:success), do: 0x00

    defp to_reason_code({:refused, reason}) do
      case reason do
        :unsupported_protocol_version -> 0x84
        :malformed_packet -> 0x81
      end
    end

    defp flag(f) when f in [0, nil, false], do: 0
    defp flag(_), do: 1
  end
end
