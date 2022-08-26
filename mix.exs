defmodule RecordList.MixProject do
  use Mix.Project

  def project do
    [
      app: :record_list,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "RecordList",
      source: "https://github.com/Ivor/record_list/",
      # The main page in the docs
      docs: [
        main: "README",
        extras: ["README.md"]
      ]
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
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end
end
