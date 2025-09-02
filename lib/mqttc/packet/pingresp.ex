defmodule Mqttc.Packet.Pingresp do
  @moduledoc false

  @opcode 13
  @flags 0b0000
  alias Mqttc.Packet

  @opaque t :: %__MODULE__{
            __META__: Packet.Meta.t()
          }
  defstruct __META__: %Packet.Meta{opcode: @opcode, flags: @flags}

  @spec decode(binary()) :: t
  def decode(<<>>) do
    %__MODULE__{}
  end

  # Protocols ----------------------------------------------------------
  defimpl Mqttc.Encodable do
    def encode(%Packet.Pingresp{} = t) do
      [Packet.Meta.encode(t.__META__), 0]
    end
  end
end
