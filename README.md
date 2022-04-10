# Philo

Philosopher problem implementation in Elixir with philosophers & forks as independant processes with timeouts on fork requests to manage concurrency.

## Running

With elixir 1.12+ installed.

```bash
cd philo
mix run --no-halt
```

The state of the philosphers is displayed in ANSI string with :
* Blue : Thinking time (T) or thinking while holding a left fork (L)
* Green : Eating (E)
* Yellow : Sleeping (S)

The number of philosophers and params (sleep_time, eating_time, starving_time) can be configured in `Waiter.ex`. By default :

```elixir
  @philo_nb 20
  @philo_param eat_time: 2_000, sleep_time: 3_000, starve_time: 10_000
```