defmodule RSS.MixProject do
  use Mix.Project

  def project do
    [
      app: :rss,
      version: "0.1.0",
      elixir: "~> 1.13-dev",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, github: "wojtekmach/req"},
      {:easyxml, github: "wojtekmach/easyxml"},
      {:kino, github: "elixir-nx/kino"}
    ]
  end
end
