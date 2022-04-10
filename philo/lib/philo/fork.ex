defmodule Philo.Fork do
  use GenServer, restart: :transient

  @timeout_waiting 500

  defstruct state: :free, waiting: nil, waiting_timer: nil

  def start_link(init_args) do
    # you may want to register your server with `name: __MODULE__`
    # as a third argument to `start_link`
    id = Keyword.get(init_args, :id)
    GenServer.start_link(__MODULE__, init_args, name: via(id))
  end

  def request(fork_id) do
    GenServer.call(via(fork_id), :take_fork)
  end

  def release(fork_id) do
    GenServer.call(via(fork_id), :release_fork)
  end

  @impl true
  def init(id: _id) do
    state = %__MODULE__{}
    Philo.Waiter.ready()
    {:ok, state}
  end

  @impl true
  def handle_call(
        :take_fork,
        _from,
        %__MODULE__{state: :free, waiting: nil, waiting_timer: nil} = state
      ) do
    {:reply, :ok, %{state | state: :taken}}
  end

  def handle_call(
        :take_fork,
        from,
        %__MODULE__{state: :taken, waiting: nil, waiting_timer: nil} = state
      ) do
    # Block call until the fork is released
    # IO.puts("fork #{id} waited by by #{inspect(from)}")
    waiting_timer = Process.send_after(self(), :timeout_waiting, @timeout_waiting)
    {:noreply, %{state | waiting: from, waiting_timer: waiting_timer}}
  end

  def handle_call(
        :release_fork,
        _from,
        %__MODULE__{state: :taken, waiting: nil, waiting_timer: nil} = state
      ) do
    {:reply, :ok, %{state | state: :free}}
  end

  def handle_call(
        :release_fork,
        _from,
        %__MODULE__{state: :taken, waiting: waiting, waiting_timer: waiting_timer} = state
      ) do
    # Unblock waiting philo
    Process.cancel_timer(waiting_timer)
    GenServer.reply(waiting, :ok)
    {:reply, :ok, %{state | waiting: nil, waiting_timer: nil}}
  end

  @impl true
  def handle_info(
        :timeout_waiting,
        %__MODULE__{state: :taken, waiting: nil, waiting_timer: nil} = state
      ) do
    {:noreply, state}
  end

  def handle_info(
        :timeout_waiting,
        %__MODULE__{state: :taken, waiting: waiting} = state
      ) do
    GenServer.reply(waiting, :error)
    {:noreply, %{state | waiting: nil, waiting_timer: nil}}
  end

  defp via(fork_id) do
    {:via, Registry, {Registry.Philo, "fork_#{fork_id}"}}
  end
end
