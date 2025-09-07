defmodule Mqttc.AuthIntegrationTest do
  use ExUnit.Case, async: false

  @host "test.mosquitto.org"
  @port 1884

  @valid_username "rw"
  @valid_password "readwrite"

  @tag :integration
  test "[integration] connect with valid credentials works" do
    {:ok, pid} =
      Mqttc.start_link_sync(
        host: @host,
        port: @port,
        username: @valid_username,
        password: @valid_password
      )

    test_topic = "auth/demo/#{System.unique_integer([:positive])}"
    parent = self()
    handler = fn msg -> send(parent, {:mqtt, msg}) end
    :ok = Mqttc.subscribe(pid, [{test_topic, handler}])

    :ok = Mqttc.publish(pid, test_topic, "42°C", qos: 1)

    assert_receive {:mqtt, %{payload: "42°C"}}, 3000
    :ok = Mqttc.disconnect(pid)
  end
end
