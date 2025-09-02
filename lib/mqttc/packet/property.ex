defmodule Mqttc.Packet.Property do
  @moduledoc """
  MQTT v5 Properties and helper functions for Encode/Decode.
  """
  import Bitwise
  # Mapping: identifier => {name_atom, decode_fun, write_fun}
  @property_definitions %{
    0x01 => {:payload_format_indicator, :read_bool, :write_bool},
    0x02 => {:message_expiry_interval, :read_four_bytes, :write_four_bytes},
    0x03 => {:content_type, :read_utf8, :write_utf8},
    0x08 => {:response_topic, :read_utf8, :write_utf8},
    0x09 => {:correlation_data, :read_binary, :write_binary},
    0x0B => {:subscription_identifier, :decode_remaining_length, :write_varint},
    0x11 => {:session_expiry_interval, :read_four_bytes, :write_four_bytes},
    0x12 => {:assigned_client_identifier, :read_utf8, :write_utf8},
    0x13 => {:server_keep_alive, :read_two_bytes, :write_two_bytes},
    0x15 => {:authentication_method, :read_utf8, :write_utf8},
    0x16 => {:authentication_data, :read_binary, :write_binary},
    0x17 => {:request_problem_information, :read_bool, :write_bool},
    0x18 => {:will_delay_interval, :read_four_bytes, :write_four_bytes},
    0x19 => {:request_response_information, :read_bool, :write_bool},
    0x1A => {:response_information, :read_utf8, :write_utf8},
    0x1C => {:server_reference, :read_utf8, :write_utf8},
    0x1F => {:reason_string, :read_utf8, :write_utf8},
    0x21 => {:receive_maximum, :read_two_bytes, :write_two_bytes},
    0x22 => {:topic_alias_maximum, :read_two_bytes, :write_two_bytes},
    0x23 => {:topic_alias, :read_two_bytes, :write_two_bytes},
    0x24 => {:maximum_qos, :read_one_byte, :write_byte},
    0x25 => {:retain_available, :read_bool, :write_bool},
    0x26 => {:user_property, :read_utf8_pair, :write_utf8_pair},
    0x27 => {:maximum_packet_size, :read_four_bytes, :write_four_bytes},
    0x28 => {:wildcard_subscription_available, :read_bool, :write_bool},
    0x29 => {:subscription_identifier_available, :read_bool, :write_bool},
    0x2A => {:shared_subscription_available, :read_bool, :write_bool}
  }
  @packet_properties %{
    connect: [
      :session_expiry_interval,
      :receive_maximum,
      :maximum_packet_size,
      :topic_alias_maximum,
      :request_response_information,
      :request_problem_information,
      :user_property,
      :authentication_method,
      :authentication_data
    ],
    will: [
      :will_delay_interval,
      :payload_format_indicator,
      :message_expiry_interval,
      :content_type,
      :response_topic,
      :correlation_data,
      :user_property
    ],
    connack: [
      :session_expiry_interval,
      :receive_maximum,
      :maximum_qos,
      :retain_available,
      :maximum_packet_size,
      :assigned_client_identifier,
      :topic_alias_maximum,
      :reason_string,
      :user_property,
      :wildcard_subscription_available,
      :subscription_identifier_available,
      :shared_subscription_available,
      :server_keep_alive,
      :response_information,
      :server_reference,
      :authentication_method,
      :authentication_data
    ],
    publish: [
      :payload_format_indicator,
      :message_expiry_interval,
      :topic_alias,
      :response_topic,
      :correlation_data,
      :user_property,
      :subscription_identifier,
      :content_type
    ],
    puback: [:reason_string, :user_property],
    pubrec: [:reason_string, :user_property],
    pubrel: [:reason_string, :user_property],
    pubcomp: [:reason_string, :user_property],
    subscribe: [:subscription_identifier, :user_property],
    suback: [:reason_string, :user_property],
    unsubscribe: [:user_property],
    unsuback: [:reason_string, :user_property],
    disconnect: [:session_expiry_interval, :reason_string, :user_property, :server_reference],
    auth: [:authentication_method, :authentication_data, :reason_string, :user_property]
  }

  def definitions, do: @property_definitions
  def definition(id), do: Map.get(@property_definitions, id)
  def allowed(packet_type), do: Map.get(@packet_properties, packet_type, [])

  # Utility functions to pack and unpack property data
  def read_binary(data) do
    <<len::16, rest::binary>> = data
    <<bin::binary-size(len), rest2::binary>> = rest
    {bin, rest2}
  end

  def read_one_byte(data) do
    <<one_byte::integer-size(8), rest::binary>> = data
    {one_byte, rest}
  end

  def read_two_bytes(data) do
    <<two_bytes::integer-size(16), rest::binary>> = data
    {two_bytes, rest}
  end

  def read_four_bytes(data) do
    <<four_bytes::integer-size(32), rest::binary>> = data
    {four_bytes, rest}
  end

  def read_bool(data) do
    <<one_byte::integer-size(8), rest::binary>> = data

    case one_byte do
      0 -> {false, rest}
      1 -> {true, rest}
    end
  end

  def read_utf8(data) when is_binary(data) do
    case data do
      <<length::16, rest::binary>> when byte_size(rest) >= length ->
        <<utf_string::binary-size(length), remaining::binary>> = rest
        {utf_string, remaining}

      _ ->
        {:error, :invalid_utf8, data}
    end
  end

  def read_utf8_pair(data) do
    {k, r1} = read_utf8(data)
    {v, r2} = read_utf8(r1)
    {{k, v}, r2}
  end

  def read_variable_bytes(data) do
    decode_remaining_length(data)
  end

  def write_byte(identifier, data), do: [<<identifier>>, <<data>>]

  def write_two_bytes(identifier, data) do
    [<<identifier>>, <<data::size(16)>>]
  end

  def write_four_bytes(identifier, data) do
    [<<identifier>>, <<data::size(32)>>]
  end

  def write_bool(identifier, 0), do: [<<identifier>>, <<0>>]
  def write_bool(identifier, 1), do: [<<identifier>>, <<1>>]

  def write_varint(id, n), do: [<<id>>, write_varint(n)]
  def write_varint(n) when n < 0, do: raise(ArgumentError, "varint must be >= 0")
  def write_varint(n), do: do_write_varint(n, [])

  defp do_write_varint(n, acc) when n < 128 do
    Enum.reverse([<<n>> | acc])
  end

  defp do_write_varint(n, acc) do
    this = Bitwise.band(n, 0x7F) ||| 0x80
    do_write_varint(n >>> 7, [<<this>> | acc])
  end

  def write_utf8(identifier, data) do
    [<<identifier>>, <<byte_size(data)::size(16)>>, data]
  end

  def write_utf8(data) when is_binary(data) do
    [<<byte_size(data)::size(16)>>, data]
  end

  def write_utf8(_data) do
    []
  end

  def write_binary(data) when is_bitstring(data) do
    [<<byte_size(data)::size(16)>>, data]
  end

  def write_binary(_data) do
    []
  end

  def write_binary(identifier, bin) do
    bin = :erlang.iolist_to_binary(bin)
    [<<identifier>>, <<byte_size(bin)::16>>, bin]
  end

  def write_utf8_pair(identifier, {k, v}) do
    kb = :erlang.iolist_to_binary(k)
    vb = :erlang.iolist_to_binary(v)
    [<<identifier>>, <<byte_size(kb)::16>>, kb, <<byte_size(vb)::16>>, vb]
  end

  def decode_remaining_length(bin) do
    do_decode_remaining_length(bin, 1, 0)
  end

  # MQTT Remaining Length decoding
  def do_decode_remaining_length(<<>>, _multiplier, _value) do
    {:error, :incomplete}
  end

  def do_decode_remaining_length(<<byte, rest::binary>>, multiplier, value) do
    digit = band(byte, 127)
    new_value = value + digit * multiplier

    if band(byte, 128) == 128 do
      do_decode_remaining_length(rest, multiplier * 128, new_value)
    else
      {new_value, rest}
    end
  end
end
