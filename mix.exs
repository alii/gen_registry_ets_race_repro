defmodule GenRegistryEtsRaceRepro.MixProject do
  use Mix.Project

  def project do
    [
      app: :gen_registry_ets_race_repro,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_registry, "~> 1.3"}
    ]
  end
end
