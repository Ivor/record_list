defmodule RecordList.MixProject do
  use Mix.Project

  def project do
    [
      app: :record_list,
      version: version(),
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  defp version do
    String.trim(File.read!("VERSION"))
  end

  defp docs do
    [
      name: "RecordList",
      main: "readme",
      extras: ["README.md"],
      source_ref: version(),
      source_url: "https://github.com/ivor/record_list/"
    ]
  end

  defp package() do
    [
      description: "Stepwise construction of lists with meta data.",
      maintainers: ["Ivor Paul"],
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/ivor/record_list",
        "Changelog" =>
          "https://github.com/ivor/record_list/blob/#{version()}/CHANGELOG.md##{String.replace(version(), ".", "")}"
      },
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        ".formatter.exs",
        "VERSION",
        "LICENSE"
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
      {:eliver, "~> 2.0.0", only: :dev},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end
end
