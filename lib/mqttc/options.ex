defmodule Mqttc.Options do
  @moduledoc """
  Schemas for validating options using NimbleOptions.
  """

  @subscribe_schema [
    topics: [
      type: {:list, {:tuple, [:string, {:fun, 1}]}},
      required: true,
      doc: """
      List of `{topic, handler}` tuples:

        * `topic` – a string (e.g. `"sensors/temp"`)
        * `handler` – a function with arity 1 (`fn msg -> ... end`)
      """
    ],
    qos: [
      type: {:in, 0..2},
      default: 0,
      doc: "Quality of Service level (0, 1, or 2) applied to all topics."
    ],
    no_local: [
      type: {:in, 0..1},
      default: 0,
      doc:
        "MQTT v5 flag that prevents messages published by this client from being sent back to it."
    ],
    retain_as_published: [
      type: {:in, 0..1},
      default: 0,
      doc: "MQTT v5 flag controlling whether the retain flag is kept as published."
    ],
    retain_handling: [
      type: {:in, 0..2},
      default: 0,
      doc: """
      MQTT v5 retain handling option:

        * 0 – send retained messages at subscribe time (default)
        * 1 – send retained messages only if subscription is new
        * 2 – do not send retained messages
      """
    ],
    subscription_id: [
      type: {:in, 1..268_435_455},
      default: 1,
      doc: """
      Subscripton identifier associates the subscription with a number. 

      The client/gateway can find out later which subscription the publish message originated.
      """
    ],
    user_property: [
      type: {:map, :string, :string},
      default: %{},
      doc: """
      User property represents multiple name, value pairs.
      """
    ],
    timeout: [
      type: :pos_integer,
      default: 5_000,
      doc: "Timeout in milliseconds for the GenServer.call that sends the PUBLISH packet."
    ]
  ]

  def subscribe_schema, do: @subscribe_schema

  @publish_schema [
    topic: [
      type: :string,
      required: true,
      doc: "Topic string to which the message will be published."
    ],
    payload: [
      type: :string,
      required: true,
      doc: "Message payload (string or binary)."
    ],
    qos: [
      type: {:in, 0..2},
      default: 0,
      doc: "Quality of Service level (0, 1, or 2). Defaults to 0."
    ],
    retain: [
      type: :boolean,
      default: false,
      doc: "Whether the broker should retain the last message on this topic. Defaults to `false`."
    ],
    timeout: [
      type: :pos_integer,
      default: 5_000,
      doc: "Timeout in milliseconds for the GenServer.call that sends the PUBLISH packet."
    ]
  ]

  def publish_schema, do: @publish_schema

  @connect_opts_schema [
    client_id: [
      type: :string,
      default: "",
      doc: "Client identifier, must be unique per broker connection."
    ],
    clean_start: [
      type: :boolean,
      default: true,
      doc: "Start a new session (true) or resume existing (false)."
    ],
    keep_alive: [
      type: :non_neg_integer,
      default: 60,
      doc: "Keep Alive interval in seconds (0 = disabled)."
    ],
    session_expiry_interval: [
      type: :non_neg_integer,
      default: 0,
      doc: "How long (in seconds) the session persists after disconnect (0 = expire immediately)."
    ],
    username: [
      type: :string,
      doc: "Optional username for authentication."
    ],
    password: [
      type: :string,
      doc: "Optional password for authentication."
    ],
    will: [
      type: :boolean,
      default: false,
      doc: "Optional if connect carries a will message"
    ],
    will_topic: [
      type: :string,
      doc: "Topic for the Will Message (if provided)."
    ],
    will_payload: [
      type: :string,
      doc: "Payload for the Will Message."
    ],
    will_qos: [
      type: {:in, [0, 1, 2]},
      default: 0,
      doc: "QoS level for the Will Message (0, 1, or 2)."
    ],
    will_retain: [
      type: :boolean,
      default: false,
      doc: "Whether the Will Message should be retained."
    ]
  ]
  def connect_opts_schema, do: @connect_opts_schema
end
