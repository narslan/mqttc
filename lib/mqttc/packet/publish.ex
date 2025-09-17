defmodule Mqttc.Packet.Publish do
  @moduledoc false
  require Logger
  alias Mqttc.Packet
  alias Mqttc.Packet.Property

  @opcode 3

  @type t :: %__MODULE__{
          __META__: Packet.Meta.t(),
          dup: boolean(),
          qos: 0 | 1 | 2,
          retain: boolean(),
          topic: String.t(),
          identifier: non_neg_integer() | nil | {:error, term()},
          properties: [key: term()],
          payload: binary()
        }

  defstruct __META__: %Packet.Meta{opcode: @opcode},
            dup: false,
            qos: 0,
            retain: false,
            topic: "",
            identifier: nil,
            properties: [],
            payload: <<>>

  def build(opts) do
    qos = Keyword.fetch!(opts, :qos)

    cond do
      qos == 0 ->
        struct(__MODULE__, opts)

      true ->
        opts = Keyword.put_new(opts, :identifier, :rand.uniform(65_535))
        struct(__MODULE__, opts)
    end
  end

  @spec decode(byte(), binary()) :: t() | {:error, String.t()}
  def decode(flags, body) do
    <<dup::1, qos::2, retain::1>> = <<flags::4>>

    case safe_extract_topic_and_id(body, qos) do
      {:error, reason} ->
        {:error, reason}

      {topic, identifier, rest} ->
        {properties, payload} = Packet.parse_properties(rest, :publish)

        %__MODULE__{
          dup: int_to_bool(dup),
          qos: qos,
          retain: int_to_bool(retain),
          topic: topic,
          identifier: identifier,
          properties: properties,
          payload: payload
        }
    end
  end

  # Safely extract topic and packet ID
  defp safe_extract_topic_and_id(<<topic_len::16, rest::binary>>, qos)
       when byte_size(rest) >= topic_len do
    <<topic::binary-size(^topic_len), rest2::binary>> = rest

    {identifier, rest3} =
      case qos do
        0 ->
          {nil, rest2}

        _ ->
          if byte_size(rest2) < 2 do
            {:error, "Incomplete packet ID"}
          else
            <<id::16, r::binary>> = rest2
            {id, r}
          end
      end

    {topic, identifier, rest3}
  end

  defp safe_extract_topic_and_id(_, _), do: {:error, "Incomplete topic data"}

  defp int_to_bool(0), do: false
  defp int_to_bool(1), do: true

  # Protocols ----------------------------------------------------------
  defimpl Mqttc.Encodable do
    def encode(%Packet.Publish{} = t) do
      [
        Packet.Meta.encode(%{t.__META__ | flags: encode_flags(t)}),
        Packet.variable_length_encode([
          encode_variable_header(t),
          t.payload
        ])
      ]
    end

    defp encode_variable_header(%Packet.Publish{qos: 0, identifier: nil} = t) do
      [
        Property.write_binary(t.topic),
        Packet.encode_properties(t.properties, :publish)
      ]
    end

    defp encode_variable_header(%Packet.Publish{} = t)
         when t.qos > 0 and not is_nil(t.identifier) do
      [
        Property.write_binary(t.topic),
        <<t.identifier::size(16)>>,
        Packet.encode_properties(t.properties, :publish)
      ]
    end

    defp encode_flags(%{dup: dup, qos: qos, retain: retain}) do
      <<flags::4>> = <<flag(dup)::1, qos::size(2), flag(retain)::1>>
      flags
    end

    defp flag(f) when f in [0, nil, false], do: 0
    defp flag(_), do: 1
  end
end
