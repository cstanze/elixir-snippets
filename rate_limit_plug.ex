defmodule Adelaide.Plugs.RateLimit do
  @moduledoc """
  A plug that rate-limits requests, using only ExRated.
  """

  import Plug.Conn

  def init(), do: init([])

  def init(opts) do
    interval = Keyword.get(opts, :interval_seconds)
    max_reqs = Keyword.get(opts, :max_requests)

    if interval == nil do
      raise Adelaide.Plugs.NoIntervalError
    end

    if max_reqs == nil do
      raise Adelaide.Plugs.NoMaxRequestsError
    end

    opts
  end

  @doc """
  Deny Handler for Rate Limit

  TODO: Allow deny handler configuration.
  """
  def deny_handler(conn) do
    calm = String.length(System.get_env("ADELAIDE_CALM", "")) > 0
    status = if calm, do: 420, else: 429
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, Poison.encode!(%{
        message: "You are being rate limited." <> (if calm, do: " Don't worry about it dogg.", else: ""),
        code: 0
    }))
    |> halt
  end

  @doc """
  Main call function for rate_limit logic.
  """
  def call(conn, opts \\ []) do
    case check_rate(conn, opts) do
      {:ok, _count} -> conn # Allow exec
      {:error, _count} -> Adelaide.Plugs.RateLimit.deny_handler(conn)
    end
  end

  # Private Helper Functions

  defp check_rate(conn, opts) do
    interval_ms = opts[:interval_seconds] * 1000
    max_reqs = opts[:max_requests]
    bucket_name = opts[:bucket] || bucket_name(conn)
    ExRated.check_rate(bucket_name, interval_ms, max_reqs)
  end

  defp bucket_name(conn) do
    path = Enum.join(conn.path_info, "/")
    ip = conn.remote_ip |> Tuple.to_list |> Enum.join(".")
    "#{ip}:#{path}"
  end
end

defmodule Adelaide.Plugs.NoIntervalError do
  defexception message: "Must specify a :interval_seconds"
end

defmodule Adelaide.Plugs.NoMaxRequestsError do
  defexception message: "Must specify a :max_requests"
end
