defmodule Philo.Waiter do
  use GenServer

  alias Philo.Philosopher

  @philo_nb 20
  @philo_param eat_time: 2_000, sleep_time: 3_000, starve_time: 10_000

  defstruct philo_nb: nil, nb_events: nil, philo_states: nil

  def start_link([]) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def ready() do
    GenServer.cast(__MODULE__, :ready)
  end

  def philo_publish_state(philo_id, philo_state) do
    GenServer.cast(__MODULE__, {:philo_state, philo_id, philo_state})
  end

  def start_meal_task(philo_nb) do
    for i <- 0..(philo_nb - 1) do
      Philosopher.start_meal(i)
    end
  end

  def init(nil) do
    nb_events = @philo_nb * 2

    philo_states =
      for _i <- 0..(@philo_nb - 1) do
        :none
      end

    state = %__MODULE__{philo_nb: @philo_nb, nb_events: nb_events, philo_states: philo_states}
    {:ok, state, {:continue, nil}}
  end

  def handle_continue(nil, %__MODULE__{philo_nb: philo_nb} = state) do
    for i <- 0..(philo_nb - 1) do
      args = Keyword.merge(@philo_param, id: i, philo_nb: philo_nb)

      DynamicSupervisor.start_child(
        Philo.DynamicSupervisor,
        {Philo.Philosopher, args}
      )
    end

    for i <- 0..(philo_nb - 1) do
      DynamicSupervisor.start_child(Philo.DynamicSupervisor, {Philo.Fork, id: i})
    end

    {:noreply, state}
  end

  def handle_cast(:ready, %__MODULE__{philo_nb: philo_nb, nb_events: nb_events} = state) do
    if nb_events - 1 == 0 do
      start_meal_task(philo_nb)
    end

    {:noreply, %{state | nb_events: nb_events - 1}}
  end

  def handle_cast(
        {:philo_state, philo_id, philo_state},
        %__MODULE__{philo_states: philo_states} = state
      ) do
    philo_states = List.update_at(philo_states, philo_id, fn _ -> philo_state end)
    display_states(philo_states)
    {:noreply, %{state | philo_states: philo_states}}
  end

  defp display_states(philo_states) do
    str =
      (philo_states
       |> Enum.map(fn
         :none -> [' N ']
         :init -> [' I ']
         :thinking -> [:blue_background, ' T ']
         :thinking_with_left -> [:blue_background, ' L ']
         :eating -> [:green_background, ' E ']
         :sleeping -> [:yellow_background, ' S ']
         :dead -> [:white_background, ' D ']
         _ -> [' U ']
       end)
       |> Enum.intersperse([:black_background, ' '])) ++
        [:black_background]

    IO.ANSI.format_fragment(str, true)
    |> IO.write()

    IO.ANSI.cursor_left(length(philo_states) * 4 - 1) |> IO.write()
  end
end
