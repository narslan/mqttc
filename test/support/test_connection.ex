defmodule Mqttc.TestConnection do
  defp spawn_mosquitto(port) do
    port_handle =
      Port.open({:spawn_executable, System.find_executable("mosquitto")}, [
        :binary,
        args: ["-p", Integer.to_string(port)]
      ])

    {:os_pid, os_pid} = Port.info(port_handle, :os_pid)
    {os_pid, port_handle}
  end

  def connect() do
    mqtt_port = 1883

    with {os_pid, port_handle} <- spawn_mosquitto(mqtt_port),
         :ok <- wait_until_ready(mqtt_port) do
      ExUnit.Callbacks.on_exit(fn ->
        System.cmd("kill", ["-9", Integer.to_string(os_pid)])
        # Port schließen, falls noch offen
        if Port.info(port_handle) != nil, do: Port.close(port_handle)
      end)

      :ok
    else
      {error, exit_code} ->
        {:error, {exit_code, error}}
    end
  end

  defp wait_until_ready(port, retries \\ 20)

  defp wait_until_ready(_port, 0), do: {:error, :timeout}

  defp wait_until_ready(port, retries) do
    case :gen_tcp.connect(~c"localhost", port, []) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :ok

      {:error, _} ->
        Process.sleep(50)
        wait_until_ready(port, retries - 1)
    end
  end
end
