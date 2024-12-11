defmodule GiocciEngine.Cubdb.Store do
  @moduledoc false

  use GenServer
  require Logger

  alias GiocciEngine.Database
  alias GiocciEngine.ModuleDB

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

  def get_datetime() do
    {{year, month, day}, {time, min, sec}} = :calendar.local_time()

    datetime =
      "#{year}" <>
        "/" <>
        String.pad_leading("#{month}", 2, "0") <>
        "/" <>
        String.pad_leading("#{day}", 2, "0") <>
        " " <>
        String.pad_leading("#{time}", 2, "0") <>
        ":" <>
        String.pad_leading("#{min}", 2, "0") <>
        ":" <>
        String.pad_leading("#{sec}", 2, "0")

    datetime
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
    GiocciEngine.InitDb.all()
  end

  def list() do
    CubDB.select(Database) |> Enum.to_list()
  end

  def module_load_and_save({:module_save, encode_module}) do
    {name, binary, path} =
      Giocci.CLI.ModuleConverter.decode(encode_module)

    Logger.info("v module: #{inspect(name)} is loaded.")

    name_snake =
      name
      |> Module.split()
      |> Enum.join("_")
      |> String.to_atom()

    CubDB.put(ModuleDB, name_snake, %{encode_module: encode_module, register_at: get_datetime()})

    Giocci.CLI.ModuleConverter.load({name, binary, path})
  end

  def put(vcontact_id, vcontact_element) do
    CubDB.put(Database, vcontact_id, vcontact_element)
  end

  defp callback(state, m) do
    ## Clientから送られたデータを解析して、実行する
    %{
      key_expr: erkey,
      value: msgint,
      kind: kind,
      reference: reference
    } = m

    ## msgをバイナリからlistにもどす
    msg =
      msgint
      |> String.trim()
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    case msg do
      ## module_execの場合
      [module, function, arity, :module_exec] = msg ->
        #  module_execする
        module_result_reply = apply(module, function, arity)

        ## 実行結果を(Relayを通して)Clientに返す
        Zenohex.Publisher.put(
          state.publisher,
          (module_result_reply <> " from engine") |> :erlang.term_to_binary() |> Base.encode64()
        )

      ## module_saveの場合
      [encode_module, :module_save] = msg ->
        ## Module_Saveを保存しロードする
        module_save_reply = module_load_and_save({:module_save, encode_module})
        ## ロード結果を(Relayを通して)Clientに返す
        Zenohex.Publisher.put(
          state.publisher,
          module_save_reply |> :erlang.term_to_binary() |> Base.encode64()
        )

      _ = msg ->
        IO.inspect("no match")
    end
  end

  @spec start_link_session_rer() ::
          {:ok, %{callback: (any() -> any()), id: RERsession, subscriber: Zenohex.Subscriber.t()}}
  def start_link_session_rer() do
    ## EngineのZenohセッションを起動
    {:ok, session} = Zenohex.open()
    ## pub,subそれぞれのキーをたてる

    {:ok, subscriber} = Zenohex.Session.declare_subscriber(session, "from/relay/to/engine")
    {:ok, publisher} = Zenohex.Session.declare_publisher(session, "from/engine/to/relay")
    ## 状態として次の状態をもつ
    state = %{
      publisher: publisher,
      subscriber: subscriber,
      callback: &callback/2,
      id: RERsession,
      session: session
    }

    ## 上記の状態を保存する用のGenServerの起動
    GenServer.start_link(__MODULE__, state, name: RERsession)
    ## subの開始
    recv_timeout(state)
    {:ok, state}
  end

  def handle_info(:loop, state) do
    # subをループするhandle_info
    recv_timeout(state)
    {:noreply, state}
  end

  def setup_engine do
    ## Relayからの要請の結果をRelayに返送するsubとpubをセットアップする
    {:ok, statee} = start_link_session_rer()
  end

  defp recv_timeout(state) do
    ## subを永続化する関数

    case Zenohex.Subscriber.recv_timeout(state.subscriber, 10_000) do
      {:ok, sample} ->
        state.callback.(state, sample)
        send(state.id, :loop)

      {:error, :timeout} ->
        send(state.id, :loop)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end
end
