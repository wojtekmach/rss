defmodule RSS do
  use GenServer, restart: :temporary

  defstruct [:pid]

  def start(url) do
    parent = self()
    opts = [url: url, parent: parent]

    {:ok, pid} = DynamicSupervisor.start_child(Kino.WidgetSupervisor, {__MODULE__, opts})

    %__MODULE__{pid: pid}
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    url = Keyword.fetch!(opts, :url)
    parent = Keyword.fetch!(opts, :parent)

    parent_monitor_ref = Process.monitor(parent)

    {:ok, %{parent_monitor_ref: parent_monitor_ref, url: url}}
  end

  @impl true
  def handle_info({:connect, pid}, state) do
    doc = Req.get!(state.url).body |> EasyXML.parse!()

    case EasyXML.xpath(doc, "//feed") do
      [_] -> :ok
      _ -> raise "only Atom feeds are currently supported"
    end

    name = "RSS: #{doc["//feed/title"]}"

    columns = [
      %{key: :title, label: "Title"},
      %{key: :date, label: "Date"}
    ]

    send(
      pid,
      {:connect_reply, %{name: name, columns: columns, features: [:sorting]}}
    )

    {:noreply, state}
  end

  def handle_info({:get_rows, pid, rows_spec}, state) do
    # TODO: on connect we already made a request, so this is unnecessary on the first run
    doc = Req.get!(state.url).body |> EasyXML.parse!()

    entries =
      for entry <- EasyXML.xpath(doc, "//entry") do
        %{
          title: entry["title"],
          url: entry["link/@href"],
          date: entry["updated"] |> NaiveDateTime.from_iso8601!() |> Date.to_string()
        }
      end

    entries =
      if order_by = rows_spec[:order_by] do
        Enum.sort_by(entries, &Map.fetch!(&1, order_by), rows_spec[:order])
      else
        entries
      end

    rows =
      for entry <- entries do
        title = ~s|<a href="#{entry.url}" target="_blank">#{entry.title}</a>|

        %{
          fields: %{
            title: {:safe, title},
            date: entry.date
          }
        }
      end

    total_rows = length(rows)

    columns = [
      %{key: :title, label: "Title"},
      %{key: :date, label: "Date"}
    ]

    send(pid, {:rows, %{rows: rows, total_rows: total_rows, columns: columns}})

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _object, _reason}, %{parent_monitor_ref: ref} = state) do
    {:stop, :shutdown, state}
  end

  defimpl Kino.Render do
    def to_livebook(widget) do
      Kino.Output.table_dynamic(widget.pid)
    end
  end
end
