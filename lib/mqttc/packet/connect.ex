defmodule Mqttc.Packet.Connect do
  @moduledoc """
  Provides functions to build a CONNECT packet with validated options.
  """

  @opcode 1

  alias Mqttc.Packet
  alias Mqttc.Packet.Property

  defstruct __META__: %Packet.Meta{opcode: @opcode},
            protocol: "MQTT",
            protocol_version: 0b00000101,
            keep_alive: 60,
            client_id: "",
            username: nil,
            password: nil,
            clean_start: true,
            will: false,
            will_retain: false,
            will_qos: 0,
            will_topic: nil,
            will_payload: nil,
            properties: [],
            will_properties: []

  @doc """
  Builds a CONNECT packet with validated options.

  ## Examples

      iex> Mqttc.Connect.build(client_id: "sensor-123")
      {:ok, %Mqttc.Packet.Connect{...}}

      iex> Mqttc.Connect.build(client_id: "bad", will_qos: 5)
      ** (NimbleOptions.ValidationError) invalid will_qos 5, must be 0, 1, or 2
  """
  def build(opts) do
    struct(__MODULE__, opts)
  end

  def decode(binary) do
    with {protocol, rest1} <- Property.read_utf8(binary),
         <<version, rest2::binary>> <- rest1,
         <<flags, rest3::binary>> <- rest2,
         <<keep_alive::16, rest4::binary>> <- rest3,
         {properties, rest5} <- Packet.parse_properties(rest4, :connect),
         {client_id, rest6} <- Property.read_utf8(rest5) do
      <<username_flag::1, password_flag::1, will_retain::1, will_qos::2, will_flag::1,
        clean_start::1, _reserved::1>> = <<flags>>

      {will_topic, will_payload, will_properties, rest7} =
        if will_flag == 1 do
          {properties, resta} = Packet.parse_properties(rest6, :will)

          {topic, restb} = Property.read_utf8(resta)
          {payload, restc} = Property.read_binary(restb)
          {topic, payload, properties, restc}
        else
          {nil, nil, [], rest6}
        end

      {username, rest8} =
        if username_flag == 1 do
          Property.read_utf8(rest7)
        else
          {nil, rest7}
        end

      {password, _rest9} =
        if password_flag == 1 do
          Property.read_utf8(rest8)
        else
          {nil, rest8}
        end

      %__MODULE__{
        protocol: protocol,
        protocol_version: version,
        keep_alive: keep_alive,
        client_id: client_id,
        username: username,
        password: password,
        clean_start: clean_start == 1,
        will: will_flag == 1,
        will_qos: will_qos,
        will_retain: will_retain == 1,
        will_topic: will_topic,
        will_payload: will_payload,
        properties: properties,
        will_properties: will_properties
      }
    else
      {:error, :invalid_utf8, _} -> {:error, :invalid_connect, binary}
      _ -> {:error, :invalid_connect, binary}
    end
  end

  defimpl Mqttc.Encodable do
    def encode(%Packet.Connect{} = t) do
      [
        Packet.Meta.encode(t.__META__),
        Packet.variable_length_encode([
          protocol_header(t),
          connection_flags(t),
          keep_alive(t.keep_alive),
          Packet.encode_properties(t.properties, :connect),
          payload(t)
        ])
      ]
    end

    defp protocol_header(%{protocol: protocol, protocol_version: version}) do
      [Property.write_binary(protocol), version]
    end

    defp connection_flags(f) do
      <<
        flag(f.username)::integer-size(1),
        flag(f.password)::integer-size(1),
        flag(f.will_retain)::integer-size(1),
        f.will_qos::integer-size(2),
        flag(f.will)::integer-size(1),
        flag(f.clean_start)::integer-size(1),
        # reserved bit
        0::1
      >>
    end

    defp keep_alive(amount) do
      <<amount::big-integer-size(16)>>
    end

    defp payload(%{will: false} = f) do
      [f.client_id, f.username, f.password]
      |> Enum.filter(&is_binary/1)
      |> Enum.map(&Property.write_binary/1)
    end

    defp payload(%{will: true, will_topic: will_topic} = f)
         when will_topic != "" and not is_nil(will_topic) do
      [
        Property.write_utf8(f.client_id),
        Packet.encode_properties(f.will_properties, :connect),
        Property.write_utf8(f.will_topic),
        Property.write_binary(f.will_payload),
        Property.write_utf8(f.username),
        Property.write_binary(f.password)
      ]
    end

    defp flag(f) when f in [0, nil, false], do: 0
    defp flag(_), do: 1
  end
end
