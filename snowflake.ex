defmodule Snowflake do
  @moduledoc """
  # Snowflake

  A simple Snowflake generator module
  capable of generating 10.000 ids in 49ms

  *These statements are based off benchmarks performed on a Macbook Air 2011*

  ## Starting the GenServer
  Starting the GenServer is as simple as using a Supervisor with the child:
  `{Snowflake, [name: Snowflake]}`
  or by starting it manually:
  `{:ok, pid} = Snowflake.start_link([name: Snowflake])`
  """

  use Bitwise
  use GenServer

  defmacro defEpoch, do: 1577854800000
  defmacro nodeBits, do: 10
  defmacro stepBits, do: 12
  defmacro nodeMax, do: 1023
  defmacro stepMask, do: 4095
  defmacro timeShift, do: 22
  defmacro nodeShift, do: 12
  defmacro epoch, do: defEpoch()

  # Client

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{ time: 0, step: 0 }, opts)
  end

  @spec next_id() :: integer
  @doc """
  Generate an id with the default node of 1.
  """
  def next_id() do
    GenServer.call(__MODULE__, {:next, 1, System.os_time(:millisecond)})
  end

  @spec next_id(integer) :: integer
  @doc """
  Generate an id with a node between 1-1022
  """
  def next_id(n) when is_integer(n) and n < nodeMax() and n > 0 do
    GenServer.call(__MODULE__, {:next, n, System.os_time(:millisecond)})
  end

  # Server (callbacks)

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:next, n, now}, _from, state) do
    {step, now} = (if state[:time] == now do
      step = (state[:step] + 1) &&& stepMask()
      if step == 0 do
        {step, while(now, state[:time])}
      else
        {step, now}
      end
    else
      {0, now}
    end)

    {:reply, (
      ((now - epoch()) <<< timeShift()) |||
      (n <<< nodeShift()) |||
      (step)
    ), %{%{state | step: step} | time: now}}
  end

  defp while(n, t) do
    if n <= t do
      while(System.os_time(:millisecond), t)
    else
      n
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
