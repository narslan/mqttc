defmodule Mqttc.IntegrationTest do
  use ExUnit.Case, async: false

  @tag :integration
  test "[integration] simple publish/subscribe" do
    assert :ok = Mqttc.TestConnection.connect()
    {:ok, pid} = Mqttc.start_link_sync(name: :broker1)

    parent = self()
    test_topic = "sensors/temp"

    handler = fn msg -> send(parent, {:mqtt, msg}) end
    :ok = Mqttc.subscribe(pid, [{test_topic, handler}])

    :ok = Mqttc.publish(pid, test_topic, "42°C", qos: 1)

    assert_receive {:mqtt, %{payload: "42°C"}}, 1000
    :ok = Mqttc.disconnect(pid)
  end

  @tag :integration
  test "[integration] qos1 delivery with ack" do
    assert :ok = Mqttc.TestConnection.connect()
    {:ok, pid} = Mqttc.start_link_sync(name: :broker2)

    parent = self()
    topic = "qos/test"

    handler = fn msg -> send(parent, {:mqtt, msg}) end
    :ok = Mqttc.subscribe(pid, [{topic, handler}])

    :ok = Mqttc.publish(pid, topic, "payload-qos1", qos: 1)

    assert_receive {:mqtt, %{payload: "payload-qos1"}}, 1000
    :ok = Mqttc.disconnect(pid)
  end

  @tag :integration
  test "[integration] wildcard subscription" do
    :ok = Mqttc.TestConnection.connect()
    {:ok, pid} = Mqttc.start_link_sync(name: :broker2)

    topic_filter = "sensors/+/humidity"

    parent = self()

    handler = fn msg ->
      send(parent, {:mqtt, msg})
    end

    :ok = Mqttc.subscribe(pid, [{topic_filter, handler}])

    :ok = Mqttc.publish(pid, "sensors/livingroom/humidity", "55%", qos: 0)
    assert_receive {:mqtt, %{payload: "55%"}}, 500

    :ok = Mqttc.disconnect(pid)
  end

  @tag :integration
  test "[integration] unsubscribe works" do
    assert :ok = Mqttc.TestConnection.connect()
    {:ok, pid} = Mqttc.start_link_sync(name: :broker4)

    parent = self()
    topic = "unsubscribe/demo"

    handler = fn msg -> send(parent, {:mqtt, msg}) end
    :ok = Mqttc.subscribe(pid, [{topic, handler}])

    :ok = Mqttc.publish(pid, topic, "before-unsub", qos: 0)

    :ok = Mqttc.unsubscribe(pid, [topic])

    :ok = Mqttc.publish(pid, topic, "after-unsub", qos: 0)
    refute_receive {:mqtt, %{payload: "after-unsub"}}, 500

    :ok = Mqttc.disconnect(pid)
  end
end
