defmodule Mqttc.Packet.Disconnect do
  @moduledoc false
  alias Mqttc.Packet

  @opcode 14
  @flags 0b0000
  @type t :: %__MODULE__{
          __META__: Packet.Meta.t(),
          reason_code: integer(),
          properties: keyword()
        }

  defstruct __META__: %Packet.Meta{opcode: @opcode, flags: @flags},
            reason_code: 0x00,
            properties: []

  # --- Public API ---
  def new(attributes) do
    struct(__MODULE__, attributes)
  end

  @spec decode(binary()) :: t()
  # Remaining Length == 0 (no reason code, no properties)
  def decode(<<>>) do
    %__MODULE__{reason_code: 0x00, properties: []}
  end

  # Reason code present, no properties
  def decode(<<reason_code::8>>) do
    %__MODULE__{reason_code: reason_code, properties: []}
  end

  # Reason code + properties (properties start with VBI length)
  def decode(<<reason_code::8, rest::binary>>) do
    {properties, _leftover} = Packet.parse_properties(rest, :disconnect)
    %__MODULE__{reason_code: reason_code, properties: properties}
  end

  # --- Protocol ---

  defimpl Mqttc.Encodable do
    def encode(%Packet.Disconnect{reason_code: rc, properties: props} = t) do
      [
        Packet.Meta.encode(t.__META__),
        Packet.variable_length_encode([
          rc,
          Packet.encode_properties(props, :disconnect)
        ])
      ]
    end
  end
end
