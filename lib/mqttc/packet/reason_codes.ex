defmodule Mqttc.Packet.Connack.ReasonCodes do
  @codes %{
    0x00 => {:success, "Connection accepted"},
    0x80 => {:unspecified_error, "Unspecified error"},
    0x81 => {:malformed_packet, "Malformed packet"},
    0x82 => {:protocol_error, "Protocol error"},
    0x83 => {:implementation_specific_error, "Implementation specific error"},
    0x84 => {:unsupported_protocol_version, "Unsupported protocol version"},
    0x85 => {:client_identifier_not_valid, "Client identifier not valid"},
    0x86 => {:bad_user_name_or_password, "Bad user name or password"},
    0x87 => {:not_authorized, "Not authorized"},
    0x88 => {:server_unavailable, "Server unavailable"},
    0x89 => {:server_busy, "Server busy"},
    0x8A => {:banned, "Banned"},
    0x8C => {:bad_authentication_method, "Bad authentication method"},
    0x90 => {:topic_name_invalid, "Invalid topic name"},
    0x95 => {:packet_too_large, "Packet too large"},
    0x97 => {:quota_exceeded, "Quota exceeded"},
    0x99 => {:payload_format_invalid, "Payload format invalid"},
    0x9A => {:retain_not_supported, "Retain not supported"},
    0x9B => {:qos_not_supported, "QoS not supported"},
    0x9C => {:use_another_server, "Use another server"},
    0x9D => {:server_moved, "Server moved"},
    0x9F => {:connection_rate_exceeded, "Connection rate exceeded"}
  }

  @spec lookup(non_neg_integer()) :: {atom(), String.t()}
  def lookup(code) do
    Map.get(@codes, code, {:unknown, "Unknown reason code"})
  end

  @spec name(non_neg_integer()) :: atom()
  def name(code) do
    {name, _} = lookup(code)
    name
  end

  @spec description(non_neg_integer()) :: String.t()
  def description(code) do
    {_, desc} = lookup(code)
    desc
  end
end

defmodule Mqttc.Packet.Disconnect.ReasonCodes do
  @codes %{
    0x00 => {:normal_disconnection, "Normal disconnection"},
    0x04 => {:disconnect_with_will, "Disconnect with will message"},
    0x80 => {:unspecified_error, "Unspecified error"},
    0x81 => {:malformed_packet, "Malformed packet"},
    0x82 => {:protocol_error, "Protocol error"},
    0x83 => {:implementation_specific_error, "Implementation specific error"},
    0x87 => {:not_authorized, "Not authorized"},
    0x89 => {:server_busy, "Server busy"},
    0x8B => {:server_shutting_down, "Server shutting down"},
    0x93 => {:keep_alive_timeout, "Keep alive timeout"},
    0x94 => {:session_taken_over, "Session taken over"},
    0x95 => {:topic_filter_invalid, "Invalid topic filter"},
    0x96 => {:topic_name_invalid, "Invalid topic name"},
    0x97 => {:receive_maximum_exceeded, "Receive maximum exceeded"},
    0x98 => {:topic_alias_invalid, "Invalid topic alias"},
    0x99 => {:packet_too_large, "Packet too large"},
    0x9A => {:message_rate_too_high, "Message rate too high"},
    0x9B => {:quota_exceeded, "Quota exceeded"},
    0x9C => {:administrative_action, "Administrative action"},
    0x9D => {:payload_format_invalid, "Payload format invalid"},
    0x9E => {:retain_not_supported, "Retain not supported"},
    0x9F => {:qos_not_supported, "QoS not supported"},
    0xA0 => {:use_another_server, "Use another server"},
    0xA1 => {:server_moved, "Server moved"},
    0xA2 => {:shared_subscriptions_not_supported, "Shared subscriptions not supported"},
    0xA3 => {:connection_rate_exceeded, "Connection rate exceeded"},
    0xA4 => {:maximum_connect_time, "Maximum connect time"},
    0xA5 => {:subscription_identifiers_not_supported, "Subscription identifiers not supported"},
    0xA6 => {:wildcard_subscriptions_not_supported, "Wildcard subscriptions not supported"}
  }

  @spec lookup(non_neg_integer()) :: {atom(), String.t()}
  def lookup(code) do
    Map.get(@codes, code, {:unknown, "Unknown reason code"})
  end

  @spec name(non_neg_integer()) :: atom()
  def name(code) do
    {name, _} = lookup(code)
    name
  end

  @spec description(non_neg_integer()) :: String.t()
  def description(code) do
    {_, desc} = lookup(code)
    desc
  end
end

defmodule Mqttc.Packet.Suback.ReasonCodes do
  @codes %{
    0x00 => {:granted_qos_0, "Granted QoS 0"},
    0x01 => {:granted_qos_1, "Granted QoS 1"},
    0x02 => {:granted_qos_2, "Granted QoS 2"},
    0x80 => {:unspecified_error, "Unspecified error"},
    0x83 => {:implementation_specific_error, "Implementation specific error"},
    0x87 => {:not_authorized, "Not authorized"},
    0x8F => {:topic_filter_invalid, "Topic filter invalid"},
    0x91 => {:packet_identifier_in_use, "Packet Identifier in use"},
    0x97 => {:quota_exceeded, "Quota exceeded"},
    0x9E => {:shared_subscriptions_not_supported, "Shared subscriptions not supported"},
    0xA1 => {:subscription_ids_not_supported, "Subscription Identifiers not supported"},
    0xA2 => {:wildcard_subscriptions_not_supported, "Wildcard Subscriptions not supported"}
  }

  @spec lookup(non_neg_integer()) :: {atom(), String.t()}
  def lookup(code) do
    Map.get(@codes, code, {:unknown, "Unknown reason code"})
  end

  @spec name(non_neg_integer()) :: atom()
  def name(code) do
    {name, _} = lookup(code)
    name
  end

  @spec description(non_neg_integer()) :: String.t()
  def description(code) do
    {_, desc} = lookup(code)
    desc
  end
end

defmodule Mqttc.Packet.Puback.ReasonCodes do
  @codes %{
    0x00 => {:success, "Success"},
    0x10 => {:no_matching_subscribers, "No matching subscribers"},
    0x80 => {:unspecified_error, "Unspecified error"},
    0x83 => {:implementation_specific_error, "Implementation specific error"},
    0x87 => {:not_authorized, "Not authorized"},
    0x90 => {:topic_name_invalid, "Topic name invalid"},
    0x91 => {:packet_identifier_in_use, "Packet Identifier in use"},
    0x97 => {:quota_exceeded, "Quota exceeded"},
    0x99 => {:payload_format_invalid, "Payload format invalid"}
  }

  @spec lookup(non_neg_integer()) :: {atom(), String.t()}
  def lookup(code) do
    Map.get(@codes, code, {:unknown, "Unknown reason code"})
  end

  @spec name(non_neg_integer()) :: atom()
  def name(code) do
    {name, _} = lookup(code)
    name
  end

  @spec description(non_neg_integer()) :: String.t()
  def description(code) do
    {_, desc} = lookup(code)
    desc
  end
end
