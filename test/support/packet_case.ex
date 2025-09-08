defmodule Mqttc.PacketCase do
  @moduledoc """
  Shared helpers for packet tests.
  """

  import ExUnit.Assertions
  alias Mqttc.Packet

  # -----------------------------
  # Roundtrip assertion for arbitrary packets
  # -----------------------------
  def assert_roundtrip(packet) do
    packet = expected_struct(packet)
    encoded = Packet.encode(packet)

    case Packet.decode(encoded) do
      {:ok, decoded, ""} ->
        assert packet == decoded,
               """
               Roundtrip failed!
               ────────────────
               Expected (original):
               #{inspect(packet, pretty: true)}

               Got (decoded):
               #{inspect(decoded, pretty: true)}
               """

      other ->
        flunk("""
        Packet.decode/1 did not return {:ok, decoded, ""}

        Input:
        #{inspect(encoded, base: :hex, binaries: :as_binaries)}

        Got:
        #{inspect(other, pretty: true)}
        """)
    end
  end

  # -----------------------------
  # Reconstruct the struct with __META__ and defaults
  # -----------------------------
  defp expected_struct(packet) do
    module = packet.__struct__

    # opcode from module attribute, fallback to __META__
    opcode =
      case module.__info__(:attributes)[:opcode] do
        [value] -> value
        _ -> Map.get(packet.__META__, :opcode)
      end

    # flags from module attribute, fallback to __META__ or 0
    flags =
      case module.__info__(:attributes)[:flags] do
        [value] -> value
        _ -> Map.get(packet.__META__, :flags, 0)
      end

    %{
      packet
      | __META__: %Packet.Meta{opcode: opcode, flags: flags}
    }
    |> normalize(module)
  end

  # -----------------------------
  # Spezifische Normalisierungen pro Modul
  # -----------------------------
  defp normalize(%Packet.Connack{} = pkt, _module) do
    %{pkt | session_present: normalize_session_present(pkt.session_present)}
  end

  defp normalize(pkt, _module), do: pkt

  defp normalize_session_present(1), do: true
  defp normalize_session_present(0), do: false
  defp normalize_session_present(x), do: x
end
