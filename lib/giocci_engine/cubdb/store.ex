defmodule GiocciEngine.Cubdb.Store do
  @moduledoc false

  use GenServer
  require Logger

  alias GiocciEngine.Database

  #
  # Client API
  #
  def start_link([pname, state]) do
    GenServer.start_link(__MODULE__, state, name: pname)
  end

  def stop(pname) do
    GenServer.stop(pname)
  end

  #
  # Callback
  #
  @impl true
  def handle_call({:get, vcontact_id}, _from, state) do
    vcontact = get(vcontact_id)

    {:reply, vcontact, state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    current_list = list()

    {:reply, current_list, state}
  end

  @impl true
  def handle_call({:module_save, encode_module}, _from, state) do
    module_save_reply = module_load_and_save({:module_save, encode_module})

    {:reply, module_save_reply, state}
  end

  @impl true
  def handle_cast({:delete, vcontact_id}, state) do
    delete(vcontact_id)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:put, vcontact_id, vcontact_element}, state) do
    put(vcontact_id, vcontact_element)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:update, vcontact_id, update_vcontact_key, update_vcontact_value}, state) do
    Logger.info(
      "=> #{inspect(vcontact_id)}, #{inspect(update_vcontact_key)}, #{inspect(update_vcontact_value)}"
    )

    update_vcontact_element = %{get(vcontact_id) | update_vcontact_key => update_vcontact_value}

    Logger.info("v #{inspect(vcontact_id)}, #{inspect(update_vcontact_element)}")

    put(vcontact_id, update_vcontact_element)

    Logger.info(
      "<= #{inspect(update_vcontact_element.node_name)} #{inspect(update_vcontact_element.contact_name)}, #{inspect(update_vcontact_element.contact_value)}"
    )

    GenServer.cast(
      {:global, :relay},
      {:update_contact, update_vcontact_element.node_name, update_vcontact_element.contact_name,
       update_vcontact_element.contact_value}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:reg_contact, vcontact_element}, state) do
    vcontact_id = gen_uuid()

    put(vcontact_id, vcontact_element)

    {:noreply, state}
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def terminate(reason, _) do
    reason
  end

  #
  # Function
  #
  def delete(vcontact_id) do
    CubDB.delete(Database, vcontact_id)
  end

  def gen_uuid() do
    reg_is_digit = ~r/[[:alpha:]]/
    uuid = Uniq.UUID.uuid4(:hex)

    case Regex.match?(reg_is_digit, uuid |> String.first()) do
      true -> uuid |> String.to_atom()
      false -> gen_uuid()
    end
  end

  def get(vcontact_id) do
    CubDB.get(Database, vcontact_id)
  end

  def init_db() do
    GiocciEngine.InitDb.start()
  end

  def list() do
    CubDB.select(Database) |> Enum.to_list()
  end

  def module_load_and_save({:module_save, encode_module}) do
    {name, binary, path} =
      Giocci.CLI.ModuleConverter.decode(encode_module)

    Logger.info("v module: #{inspect(name)} is loaded.")

    Giocci.CLI.ModuleConverter.load({name, binary, path})
  end

  def put(vcontact_id, vcontact_element) do
    CubDB.put(Database, vcontact_id, vcontact_element)
  end
end
