defmodule GiocciEngineTest do
  use ExUnit.Case
  doctest GiocciEngine

  test "greets the world" do
    assert GiocciEngine.hello() == :world
  end
end
