defmodule Mqttc.Packet.Connack do
  @moduledoc false

  alias Mqttc.Packet
  require Logger
  @opcode 2
  @flags 0b0000

  @type status :: :accepted | {:refused, refusal_reasons()}
  @type refusal_reasons ::
          :unacceptable_protocol_version
          | :identifier_rejected
          | :server_unavailable
          | :bad_user_name_or_password
          | :not_authorized

  @opaque t :: %__MODULE__{
            __META__: Packet.Meta.t(),
            session_present: boolean(),
            reason_code: status() | nil,
            properties: keyword()
          }

  defstruct __META__: %Packet.Meta{opcode: @opcode, flags: @flags},
            session_present: false,
            reason_code: :accepted,
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
        :accepted

      0x80 ->
        {:refused, :unspecified_error}

      0x81 ->
        {:refused, :malformed_packet}

      0x82 ->
        {:refused, :protocol_error}

      0x83 ->
        {:refused, :implementation_specific_error}

      0x84 ->
        {:refused, :unsupported_protocol_version}

      0x87 ->
        {:refused, :not_authorized}

      0x8C ->
        {:refused, :bad_authentication_method}

      0x95 ->
        {:refused, :packet_too_large}

      0x9F ->
        {:refused, :connection_rate_exceeded}

      other ->
        {:refused, {:unknown_reason_code, other}}
    end
  end

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
    defp to_reason_code(:accepted), do: 0x00

    defp to_reason_code({:refused, reason}) do
      case reason do
        :unsupported_protocol_version -> 0x84
        :identifier_rejected -> 0x02
        :server_unavailable -> 0x03
        :bad_user_name_or_password -> 0x04
        :not_authorized -> 0x05
      end
    end

    defp flag(f) when f in [0, nil, false], do: 0
    defp flag(_), do: 1
  end
end
