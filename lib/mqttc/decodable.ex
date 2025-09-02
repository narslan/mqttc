defprotocol Mqttc.Decodable do
  @moduledoc false
  @spec decode({integer(), integer(), binary()}) ::
          {:ok, struct()} | {:error, term()}
  def decode(data)
end

defimpl Mqttc.Decodable, for: Tuple do
  alias Mqttc.Packet.{
    Connack,
    Publish,
    Puback,
    Pubrec,
    Pubrel,
    Pubcomp,
    Subscribe,
    Suback,
    Unsubscribe,
    Unsuback,
    Pingreq,
    Pingresp,
    Disconnect,
    Auth
  }

  def decode({2, 0, body}), do: {:ok, Connack.decode(body)}
  def decode({3, f, body}), do: {:ok, Publish.decode(f, body)}
  def decode({4, 0, body}), do: {:ok, Puback.decode(body)}
  def decode({5, 0, body}), do: {:ok, Pubrec.decode(body)}
  def decode({6, 2, body}), do: {:ok, Pubrel.decode(body)}
  def decode({7, 0, body}), do: {:ok, Pubcomp.decode(body)}
  def decode({8, 2, body}), do: {:ok, Subscribe.decode(body)}
  def decode({9, 0, body}), do: {:ok, Suback.decode(body)}
  def decode({10, 2, body}), do: {:ok, Unsubscribe.decode(body)}
  def decode({11, 0, body}), do: {:ok, Unsuback.decode(body)}
  def decode({12, 0, body}), do: {:ok, Pingreq.decode(body)}
  def decode({13, 0, body}), do: {:ok, Pingresp.decode(body)}
  def decode({14, 0, body}), do: {:ok, Disconnect.decode(body)}
  def decode({15, 0, body}), do: {:ok, Auth.decode(body)}

  def decode({opcode, flags, body}),
    do: {:error, {:unknown, opcode, flags, byte_size(body)}}
end
