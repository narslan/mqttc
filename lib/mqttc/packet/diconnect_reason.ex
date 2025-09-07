defmodule Mqttc.Disconnect.ReasonCodes do
  @moduledoc """
  Helper für MQTT v5 DISCONNECT Reason Codes.

  Dient zur Übersetzung von numerischen Codes (z. B. 0x8E) in
  menschenlesbare Namen und optionale Erläuterungen.
  """

  @codes %{
    0x00 => {:normal_disconnection, "Normal disconnection"},
    0x04 => {:disconnect_with_will, "Disconnect with will message"},
    0x80 => {:unspecified_error, "Unspecified error"},
    0x81 => {:malformed_packet, "Malformed packet"},
    0x82 => {:protocol_error, "Protocol error"},
    0x83 => {:implementation_specific_error, "Implementation specific error"},
    0x87 => {:not_authorized, "Not authorized"},
    0x89 => {:server_busy, "Server busy"},
    0x8B => {:server_shutdown, "Server shutting down"},
    0x8D => {:keep_alive_timeout, "Keep alive timeout"},
    0x8E => {:session_taken_over, "Session taken over"},
    0x8F => {:topic_filter_invalid, "Topic filter invalid"},
    0x90 => {:topic_name_invalid, "Topic name invalid"},
    0x95 => {:packet_too_large, "Packet too large"},
    0x97 => {:quota_exceeded, "Quota exceeded"},
    0x99 => {:administrative_action, "Administrative action"},
    0x9A => {:payload_format_invalid, "Payload format invalid"},
    0x9B => {:retain_not_supported, "Retain not supported"},
    0x9C => {:qos_not_supported, "QoS not supported"},
    0x9D => {:use_another_server, "Use another server"},
    0x9E => {:server_moved, "Server moved"},
    0x9F => {:shared_subs_not_supported, "Shared subscriptions not supported"},
    0xA0 => {:connection_rate_exceeded, "Connection rate exceeded"}
  }

  @doc """
  Gibt `{atom_name, description}` für den Code zurück.
  """
  @spec lookup(non_neg_integer()) ::
          {atom(), String.t()} | {:unknown, String.t()}
  def lookup(code) do
    Map.get(@codes, code, {:unknown, "Unknown reason code"})
  end

  @doc """
  Gibt nur den atomischen Namen zurück (`:normal_disconnection` etc.).
  """
  def name(code) do
    case lookup(code) do
      {name, _} -> name
      other -> other
    end
  end

  @doc """
  Gibt nur die Beschreibung als String zurück.
  """
  def description(code) do
    case lookup(code) do
      {_, desc} -> desc
      {_, other} -> other
    end
  end
end
