defmodule Mqttc.Packet do
  @moduledoc false

  alias Mqttc.Packet

  alias Mqttc.Packet.{
    Connect,
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
    Auth,
    Property
  }

  require Logger

  @opaque message ::
            Packet.Connect.t()
            | Packet.Connack.t()
            | Packet.Publish.t()
            | Packet.Puback.t()
            | Packet.Pubrec.t()
            | Packet.Pubrel.t()
            | Packet.Pubcomp.t()
            | Packet.Subscribe.t()
            | Packet.Suback.t()
            | Packet.Unsubscribe.t()
            | Packet.Unsuback.t()
            | Packet.Pingreq.t()
            | Packet.Pingresp.t()
            | Packet.Disconnect.t()

  defdelegate encode(data), to: Mqttc.Encodable

  @spec decode(binary()) :: {list(any()), binary()}

  def decode(buffer) when is_list(buffer) do
    IO.iodata_to_binary(buffer) |> decode
  end

  def decode(<<>> = buffer) when is_binary(buffer), do: {:error, :incomplete, <<>>}

  def decode(<<type::4, flags::4, rest::binary>> = full) when is_binary(full) do
    case Property.decode_remaining_length(rest) do
      # For cases PINGREQ, PINGRESP, DISCONNECT, AUTH there might only a 0 remains after bitstring matching. 
      {0, leftover} ->
        case decode_dispatch(type, flags, <<>>) do
          :unknown -> {:error, :unknown, leftover}
          packet -> {:ok, packet, leftover}
        end

      # We signal here the Connection that we need more data.
      {:error, :incomplete} ->
        {:error, :incomplete, full}

      # We found a length information in the packet. Read that amount of data.  
      {len, remaining} ->
        if byte_size(remaining) < len do
          # If we don't have enough data, we return full packet to the Connection as we can process further.  
          {:error, :incomplete, full}
        else
          <<body::binary-size(len), leftover::binary>> = remaining

          # We deliver the full body of the packet to the correct packet remaining length stripped off.
          packet =
            case decode_dispatch(type, flags, body) do
              :incomplete -> {:error, :incomplete, full}
              other -> {:ok, other, leftover}
            end

          packet
        end
    end
  end

  # Dispatch table for decoders
  defp decode_dispatch(type, flags, body) do
    case type do
      1 -> Connect.decode(body)
      2 -> Connack.decode(body)
      3 -> Publish.decode(flags, body)
      4 -> Puback.decode(body)
      5 -> Pubrec.decode(body)
      6 -> Pubrel.decode(body)
      7 -> Pubcomp.decode(body)
      8 -> Subscribe.decode(body)
      9 -> Suback.decode(body)
      10 -> Unsubscribe.decode(body)
      11 -> Unsuback.decode(body)
      12 -> Pingreq.decode(body)
      13 -> Pingresp.decode(body)
      14 -> Disconnect.decode(body)
      15 -> Auth.decode(body)
    end
  end

  @doc false
  def variable_length_encode(data) when is_list(data) do
    [Property.write_varint(IO.iodata_length(data)) | data]
  end

  def encode_properties(props, _packet_type) when is_nil(props), do: [0]

  def encode_properties(props, packet_type) do
    allowed = Property.allowed(packet_type)

    encoded =
      props
      |> Enum.flat_map(fn {key, value} ->
        if key in allowed do
          case find_property_encoder(key) do
            {id, fun} ->
              apply(Mqttc.Packet.Property, fun, [id, value])

            nil ->
              raise "Unknown property key #{inspect(key)}"
          end
        else
          raise "Property #{inspect(key)} not allowed for packet type #{packet_type}"
        end
      end)

    [Property.write_varint(IO.iodata_length(encoded)) | encoded]
  end

  defp find_property_encoder(key) do
    Property.definitions()
    |> Enum.find_value(fn {id, {name, _decode, encode}} ->
      if name == key, do: {id, encode}, else: nil
    end)
  end

  def parse_properties(bin, packet_type) do
    {prop_len, rest} = Property.decode_remaining_length(bin)
    <<props_bin::binary-size(prop_len), leftover::binary>> = rest

    props = parse_properties_acc(props_bin, Property.allowed(packet_type), [])

    {Enum.reverse(props), leftover}
  end

  defp parse_properties_acc(<<>>, _allowed, acc), do: acc

  defp parse_properties_acc(<<id, rest::binary>>, allowed, acc) do
    case Property.definition(id) do
      {name, decode_fun, _encode_fun} ->
        if name in allowed do
          {value, rest2} = apply(Mqttc.Packet.Property, decode_fun, [rest])
          parse_properties_acc(rest2, allowed, [{name, value} | acc])
        else
          raise "Property #{inspect(name)} (id=#{id}) not allowed for this packet"
        end

      nil ->
        raise "Unknown property identifier #{id} in props"
    end
  end
end
