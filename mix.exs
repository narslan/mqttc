defmodule Mqttc.MixProject do
  use Mix.Project

  @description "MQTT v5 Client for Elixir."

  @repo_url "https://github.com/narslan/mqttc"

  @version "0.1.4"

  def project do
    [
      app: :mqttc,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),

      # Hex
      package: package(),
      description: @description,
      name: "Mqttc",
      docs: [
        main: "Mqttc",
        source_ref: "v#{@version}",
        source_url: @repo_url,
        extras: [
          "README.md",
          "LICENSE.txt": [title: "License"]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:ssl, :logger]
    ]
  end

  defp package do
    [
      maintainers: ["Nevroz Arslan"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
