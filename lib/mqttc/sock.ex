defmodule Mqttc.Sock do
  @moduledoc false
  @default_timeout 5_000

  def connect(host, port, socket_opts, ssl? \\ false, ssl_opts \\ []) do
    host = to_charlist(host)
    timeout = Keyword.get(socket_opts, :timeout, @default_timeout)

    if ssl? do
      case :ssl.connect(host, port, ssl_opts, timeout) do
        {:ok, sock} -> {:ok, {:ssl, sock}}
        {:error, reason} -> {:error, reason}
      end
    else
      case :gen_tcp.connect(host, port, socket_opts, timeout) do
        {:ok, sock} -> {:ok, {:tcp, sock}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def send({:ssl, sock}, data), do: :ssl.send(sock, :erlang.iolist_to_binary(data))
  def send({:tcp, sock}, data), do: :gen_tcp.send(sock, :erlang.iolist_to_binary(data))

  def send(sock, data) when is_port(sock),
    do: :gen_tcp.send(sock, :erlang.iolist_to_binary(data))

  def send(other, _data),
    do: raise("Unknown socket type: #{inspect(other)}")

  def close({:ssl, sock}), do: :ssl.close(sock)
  def close({:tcp, sock}), do: :gen_tcp.close(sock)
  def close(sock) when is_port(sock), do: :gen_tcp.close(sock)
end
