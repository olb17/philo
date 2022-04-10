defmodule Philo.Philosopher do
  use GenServer, restart: :transient

  alias Philo.{Fork, Waiter}

  defstruct id: nil,
            eat_time: nil,
            sleep_time: nil,
            starve_time: nil,
            philo_nb: nil,
            state: :init,
            starve_timer: nil

  def start_link(init_args) do
    id = Keyword.get(init_args, :id)
    GenServer.start_link(__MODULE__, init_args, name: via(id))
  end

  def start_meal(philo_id) do
    GenServer.cast(via(philo_id), :start_meal)
  end

  @impl true
  def init(
        eat_time: eat_time,
        sleep_time: sleep_time,
        starve_time: starve_time,
        id: id,
        philo_nb: philo_nb
      ) do
    starve_timer = Process.send_after(self(), :starve, starve_time)

    state = %__MODULE__{
      id: id,
      eat_time: eat_time,
      sleep_time: sleep_time,
      starve_time: starve_time,
      philo_nb: philo_nb,
      starve_timer: starve_timer
    }

    Waiter.ready()
    Waiter.philo_publish_state(id, :init)
    {:ok, state}
  end

  @impl true
  def handle_cast(
        :start_meal,
        %{
          id: id,
          philo_nb: philo_nb,
          eat_time: eat_time,
          state: :init,
          starve_timer: starve_timer
        } = state
      ) do
    trying_to_eat(id, philo_nb, eat_time, starve_timer)
    {:noreply, %{state | state: :eating}}
  end

  defp trying_to_eat(id, philo_nb, eat_time, starve_timer) do
    # Demande la fourchette gauche puis droite (appel bloquant)
    with Waiter.philo_publish_state(id, :thinking),
         {:left, :ok} <- {:left, Fork.request(rem(id + philo_nb - 1, philo_nb))},
         Waiter.philo_publish_state(id, :thinking_with_left),
         {:right, :ok} <- {:right, Fork.request(rem(id, philo_nb))} do
      Waiter.philo_publish_state(id, :eating)
      Process.cancel_timer(starve_timer)
      Process.send_after(self(), :finished_eating, eat_time)
    else
      {:left, _} ->
        trying_to_eat(id, philo_nb, eat_time, starve_timer)

      {:right, _} ->
        :ok = Fork.release(rem(id + philo_nb - 1, philo_nb))
        trying_to_eat(id, philo_nb, eat_time, starve_timer)
    end
  end

  @impl true
  def handle_info(
        :finished_eating,
        %__MODULE__{
          id: id,
          philo_nb: philo_nb,
          state: :eating,
          starve_time: starve_time,
          sleep_time: sleep_time
        } = state
      ) do
    Waiter.philo_publish_state(id, :sleeping)
    :ok = Fork.release(rem(id + philo_nb - 1, philo_nb))
    :ok = Fork.release(rem(id, philo_nb))
    Process.send_after(self(), :finished_sleeping, sleep_time)
    starve_timer = Process.send_after(self(), :starve, starve_time)

    state = %{
      state
      | state: :sleeping,
        starve_timer: starve_timer
    }

    {:noreply, state}
  end

  @impl true
  def handle_info(
        :finished_sleeping,
        %__MODULE__{
          id: id,
          philo_nb: philo_nb,
          eat_time: eat_time,
          state: :sleeping,
          starve_timer: starve_timer
        } = state
      ) do
    trying_to_eat(id, philo_nb, eat_time, starve_timer)
    {:noreply, %{state | state: :eating}}
  end

  @impl true
  def handle_info(:starve, %{id: id} = state) do
    Waiter.philo_publish_state(id, :dead)
    {:stop, :normal, state}
  end

  defp via(philo_id) do
    {:via, Registry, {Registry.Philo, "philo_#{philo_id}"}}
  end
end
