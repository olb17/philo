defmodule PhiloTest do
  use ExUnit.Case
  doctest Philo

  test "greets the world" do
    assert Philo.hello() == :world
  end
end
